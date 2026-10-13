#!/usr/bin/env bash
# doctor.sh - the health check: one row per check for the vault and each project, and the hook check.

# Print one row: result | check | scope | count | offenders | fix. Offenders come one per line.
sb_doc_row() {
  local result="$1" check="$2" scope="$3" list="$4" fix="${5:--}"
  scope="${scope//|//}"
  fix="${fix//|//}"
  if [ -z "$list" ]; then
    printf '%s | %s | %s | 0 | - | %s\n' "$result" "$check" "$scope" "$fix"
    return 0
  fi
  printf '%s\n' "$list" | LC_ALL=C SB_HEAD="$result | $check | $scope" SB_FIX="$fix" awk "$(sb_awk_lib)"'
    function tidy(s) { gsub(/[\t\r]/, " ", s); gsub(/[|]/, "/", s); gsub(/,/, ";", s); return cut(trim(s), 48) }
    $0 != "" { n++; if (n <= 5) out = out (n > 1 ? ", " : "") tidy($0) }
    END { print ENVIRON["SB_HEAD"] " | " (n + 0) " | " (n ? out : "-") " | " ENVIRON["SB_FIX"] }'
}

# Print an ok row when the offender list is empty, else a row at the given level with its fix.
sb_doc_report() {
  if [ -z "$4" ]; then
    sb_doc_row ok "$2" "$3" "" "-"
  else
    sb_doc_row "$1" "$2" "$3" "$4" "$5"
  fi
}

# Check that the pointer resolves to a vault.
sb_doc_check_pointer() {
  local bad=""
  if [ -z "${SB_ROOT:-}" ]; then
    bad="second-brain-vault"
    [ -z "${SECOND_BRAIN_VAULT:-}" ] || bad="SECOND_BRAIN_VAULT"
  fi
  sb_doc_report fail pointer vault "$bad" "run /obsidian-dev-second-brain:vault-setup init"
}

# Check that the index exists and holds the Projects table, that each row leads to a folder and
# shares no name, key or path with another, and that the index is not older than the template.
sb_doc_check_index() {
  local f="$SB_ROOT/CLAUDE.md" rows name path keys have want bad="" nl=$'\n'
  if [ ! -f "$f" ]; then
    sb_doc_row fail index vault "CLAUDE.md" "run /obsidian-dev-second-brain:vault-setup init"
    return 0
  fi
  LC_ALL=C awk '
    { sub(/\r$/, "") }
    /^#[#]? / { insec = (tolower($0) ~ /^##[ \t]+projects[ \t]*$/); next }
    insec && tolower($0) ~ /^[ \t]*\|[ \t]*project[ \t]*\|/ { found = 1; exit }
    END { exit(found ? 0 : 1) }' "$f" || bad="## Projects"
  if [ -n "$bad" ]; then
    sb_doc_row fail index vault "$bad" "add the Projects table to the index (scaffold project adds it)"
    return 0
  fi
  rows="$(sb_projects_tsv 2>/dev/null)"
  # A path that leaves the vault is no folder of it, and is never looked for on disk.
  while IFS=$'\t' read -r name path keys; do
    [ -n "$path" ] || continue
    case "/$path/" in
      */../*) ;;
      *) [ ! -d "$SB_ROOT/$path" ] || continue ;;
    esac
    bad="$bad$name:no-folder$nl"
  done <<EOF
$rows
EOF
  # Names are compared without letter case and keys in upper case, as the lookups compare them.
  bad="$bad$(printf '%s\n' "$rows" | LC_ALL=C awk -F'\t' '
    function see(kind, k, v) {
      k = kind SUBSEP k
      if (!(k in at)) { at[k] = NR; spell[k] = v; ord[kind, ++n[kind]] = k }
      else if (at[k] != NR) twice[k] = 1
    }
    $1 == "" { next }
    {
      see(1, tolower($1), $1)
      m = split($3, key, ",")
      for (i = 1; i <= m; i++) if (key[i] != "") see(2, toupper(key[i]), key[i])
      see(3, $2, $2)
    }
    END {
      for (c = 1; c <= 3; c++)
        for (i = 1; i <= n[c]; i++) if (ord[c, i] in twice) print spell[ord[c, i]] ":twice"
    }')"
  if [ -n "$bad" ]; then
    sb_doc_row fail index vault "$bad" "give each row its own name, keys and path, and a path that is a folder in the vault"
    return 0
  fi
  have="$(sb_fm_get "$f" index_version 2>/dev/null)"
  want="$(sb_fm_get "$(sb_plugin_root)/templates/vault-index.md.tmpl" index_version 2>/dev/null)"
  case "$have" in *[!0-9]*) have="" ;; esac
  case "$want" in *[!0-9]*) want="" ;; esac
  if [ -n "$want" ] && { [ -z "$have" ] || [ "$have" -lt "$want" ]; }; then
    sb_doc_row warn index vault "CLAUDE.md:${have:-none}" \
      "the index is older than the plugin's template, version $want: bring the text above ## Projects in line with the template, keep the table, and set index_version"
    return 0
  fi
  sb_doc_row ok index vault "" "-"
}

# Check that the conventions note exists, and that it is not older than the plugin's template.
# An older note names its conventions_version after the file name, or "none" when it has none.
sb_doc_check_conventions() {
  local f="$SB_ROOT/obsidian-conventions.md" have want
  if [ ! -f "$f" ]; then
    sb_doc_row fail conventions vault "obsidian-conventions.md" "run second-brain scaffold vault to create it"
    return 0
  fi
  have="$(sb_fm_get "$f" conventions_version 2>/dev/null)"
  want="$(sb_fm_get "$(sb_plugin_root)/templates/obsidian-conventions.md.tmpl" conventions_version 2>/dev/null)"
  case "$have" in *[!0-9]*) have="" ;; esac
  case "$want" in *[!0-9]*) want="" ;; esac
  if [ -n "$want" ] && { [ -z "$have" ] || [ "$have" -lt "$want" ]; }; then
    sb_doc_row warn conventions vault "obsidian-conventions.md:${have:-none}" \
      "the note is older than the plugin's template, version $want: delete it and run second-brain scaffold vault, or edit it by hand"
    return 0
  fi
  sb_doc_row ok conventions vault "" "-"
}

# Check that the link directory's CLAUDE.md imports the index.
sb_doc_check_import() {
  local home f line p bad="CLAUDE.md"
  home="$(sb_link_home)"
  f="$home/CLAUDE.md"
  if [ -f "$f" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in @*) ;; *) continue ;; esac
      p="${line#@}"
      p="${p%"${p##*[![:space:]]}"}"
      p="$(sb_path_in "$p")"
      case "$p" in
        '~/'*) p="${HOME:-}/${p#??}" ;;
        /*) ;;
        *) p="$home/$p" ;;
      esac
      if [ "$p" -ef "$SB_ROOT/CLAUDE.md" ]; then
        bad=""
        break
      fi
    done <"$f"
  fi
  sb_doc_report warn import vault "$bad" "add the line @~/.claude/second-brain-vault/CLAUDE.md to CLAUDE.md in the link directory"
}

# Check the links of the vault's own skills and agents.
sb_doc_check_links() {
  local bad
  bad="$(sb_link_scan 2>/dev/null | awk -F' [|] ' '
    $3 == "missing" || $3 == "wrong-target" || $3 == "dangling" || $3 == "name-mismatch" || $3 == "duplicate" { print $1 ":" $3 }')"
  sb_doc_report fail links vault "$bad" "run second-brain link --apply, then repair by hand what it leaves"
}

# Check that no link in the link directory points inside the plugin.
sb_doc_check_double_registration() {
  local home root slot t bad="" nl=$'\n'
  home="$(sb_link_home)"
  root="$(cd -P "$(sb_plugin_root)" 2>/dev/null && pwd -P)" || root=""
  for slot in "$home"/skills/* "$home"/agents/*; do
    [ -L "$slot" ] && [ -n "$root" ] || continue
    t="$(readlink "$slot")" || continue
    case "$t" in /*) ;; *) t="${slot%/*}/$t" ;; esac
    if [ -d "$t" ]; then
      t="$(cd -P "$t" 2>/dev/null && pwd -P)" || continue
    elif [ -d "${t%/*}" ]; then
      t="$(cd -P "${t%/*}" 2>/dev/null && pwd -P)/${t##*/}"
    fi
    case "$t/" in "$root"/*) bad="$bad${slot#"$home"/}$nl" ;; esac
  done
  sb_doc_report warn double-registration vault "$bad" "remove the link: the enabled plugin registers it already"
}

# Check the line counts of the two files that are always loaded.
sb_doc_check_always_loaded_size() {
  local idx="$SB_ROOT/CLAUDE.md" mine n bad="" nl=$'\n'
  mine="$(sb_link_home)/CLAUDE.md"
  if [ -f "$idx" ]; then
    n="$(awk 'END { print NR }' "$idx")"
    [ "$n" -le 60 ] || bad="index:$n$nl"
  fi
  if [ -f "$mine" ]; then
    n="$(awk 'END { print NR }' "$mine")"
    [ "$n" -le 40 ] || bad="${bad}CLAUDE.md:$n$nl"
  fi
  sb_doc_report warn always-loaded-size vault "$bad" "trim them: 60 lines at most for the index, 40 for CLAUDE.md in the link directory"
}

# Print the skill and agent files of the vault's claude folder and of each project's, one per line.
sb_doc_piece_files() {
  local name path keys dir f seen nl=$'\n'
  seen="$nl"
  while IFS=$'\t' read -r name path keys <&3; do
    [ -n "$path" ] || continue
    case "/$path/" in */../*) continue ;; esac
    dir="$SB_ROOT/$path/claude"
    [ "$path" != "." ] || dir="$SB_ROOT/claude"
    case "$seen" in *"$nl$dir$nl"*) continue ;; esac
    seen="$seen$dir$nl"
    for f in "$dir"/skills/*/SKILL.md "$dir"/agents/*.md; do
      [ -f "$f" ] || continue
      case "${f##*/}" in [Rr][Ee][Aa][Dd][Mm][Ee].md) continue ;; esac
      printf '%s\n' "$f"
    done
  done 3<<EOF
vault$(printf '\t').
$(sb_projects_tsv 2>/dev/null)
EOF
}

# Read file paths on stdin; print name, kind, description length in characters and line count.
sb_doc_piece_scan() {
  LC_ALL=C awk "$(sb_awk_lib)"'
    {
      path = $0
      if (path == "") next
      n = 0; st = 0; desc = ""; indesc = 0
      while ((getline line < path) > 0) {
        n++
        sub(/\r$/, "", line)
        if (n == 1) { sub(/^\357\273\277/, "", line); st = (line == "---" ? 1 : 2); continue }
        if (st != 1) continue
        if (line == "---") { st = 2; continue }
        if (line ~ /^description:/) {
          v = trim(substr(line, 13)); indesc = 1
          desc = (v ~ /^[>|][+-]?$/ ? "" : unq(v))
          continue
        }
        if (!indesc || line ~ /^[ \t]*$/) continue
        if (line ~ /^[ \t]/) desc = desc (desc == "" ? "" : " ") trim(line)
        else indesc = 0
      }
      close(path)
      m = split(path, part, "/")
      kind = (part[m] == "SKILL.md" ? "skill" : "agent")
      name = (kind == "skill" ? part[m - 1] : part[m]); sub(/\.md$/, "", name)
      gsub(/[\200-\277]/, "", desc)
      print name "\t" kind "\t" length(desc) "\t" n
    }'
}

# Check that no scanned skill or agent description is over 200 characters.
sb_doc_check_descriptions() {
  local bad
  bad="$(printf '%s\n' "$SB_DOC_PIECES" | awk -F'\t' '$3 > 200 { print $1 ":" $3 }')"
  sb_doc_report warn descriptions vault "$bad" "shorten the description to one sentence under 200 characters"
}

# Check that no scanned SKILL.md is over 150 lines.
sb_doc_check_skill_size() {
  local bad
  bad="$(printf '%s\n' "$SB_DOC_PIECES" | awk -F'\t' '$2 == "skill" && $4 > 150 { print $1 ":" $4 }')"
  sb_doc_report warn skill-size vault "$bad" "move the detail of one mode into a sibling file read only in that mode"
}

# Set the project globals for one index row, without exiting on a bad row.
sb_doc_project() {
  SB_P_NAME="$1"
  SB_P_PATH="$2"
  SB_P_KEYS="${3:-}"
  SB_P_DIR="$SB_ROOT/$SB_P_PATH"
  SB_P_PROFILE="$SB_P_DIR/claude/profile.md"
  SB_TASKS_ROOT="$(sb_setting "$SB_P_PATH" tasks_root tasks)"
  SB_TOPICS_ROOT="$(sb_setting "$SB_P_PATH" topics_root docs)"
  SB_SPRINTS_ROOT="$(sb_setting "$SB_P_PATH" sprints_root sprints)"
  SB_DOC_SPRINTS=1
  sb_uses_sprints "$SB_P_PATH" || SB_DOC_SPRINTS=0
  SB_DOC_FILES="$(sb_task_files "$SB_P_DIR/$SB_TASKS_ROOT")"
  SB_DOC_SCAN="$(printf '%s\n' "$SB_DOC_FILES" | sb_task_scan)"
  SB_DOC_FACTS="$(printf '%s\n' "$SB_DOC_FILES" | sb_doc_facts)"
}

# Read task README paths on stdin; print kind, id, value for alias1, alias, tag, trap, bare and eol.
sb_doc_facts() {
  LC_ALL=C awk "$(sb_awk_lib)"'
    function fact(kind, v) { gsub(/[\t\r]/, " ", v); print kind "\t" id "\t" v }
    function item(k, v) {
      if (v == "") return
      if (k == "aliases") { if (!na++) fact("alias1", v); fact("alias", v); return }
      sub(/^#/, "", v)
      if (substr(v, 1, 5) == "type/" || substr(v, 1, 7) == "status/") fact("tag", v)
    }
    function plain(v) { v = trim(v); sub(/[ \t]+#.*$/, "", v); return v }
    function alias_trap(v) {
      v = plain(v)
      return (index("\"\047", substr(v, 1, 1)) == 0 && v ~ /:([ \t]|$)/)
    }
    function front(line,   i, v, m, k) {
      if (line == "---") { st = 2; return }
      if (line ~ /^[A-Za-z0-9_][A-Za-z0-9_-]*:/) {
        i = index(line, ":"); key = substr(line, 1, i - 1); v = trim(substr(line, i + 1))
        if (plain(v) == "-") fact("trap", key)
        if (key == "sprint" && plain(v) ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) fact("trap", key)
        if (key != "aliases" && key != "tags") return
        if (substr(v, 1, 1) == "[") {
          m = split_inline(v, it)
          for (k = 1; k <= m; k++) item(key, it[k])
          gsub(/"[^"]*"/, "", v); gsub(/\047[^\047]*\047/, "", v)
          if (key == "aliases" && v ~ /:[ \t]/) fact("trap", key)
        } else if (v != "" && substr(v, 1, 1) != "#") {
          if (key == "aliases" && alias_trap(v)) fact("trap", key)
          item(key, unq(v))
        }
        return
      }
      if (line ~ /^[ \t]+[A-Za-z0-9_][A-Za-z0-9_-]*:[ \t]+-[ \t]*(#.*)?$/) { fact("trap", key); return }
      if ((key == "aliases" || key == "tags") && line ~ /^[ \t]*-([ \t]|$)/) {
        v = line; sub(/^[ \t]*-[ \t]*/, "", v)
        if (key == "aliases" && alias_trap(v)) fact("trap", key)
        item(key, unq(v))
      }
    }
    function body(line,   s, i, j, t) {
      if (line ~ /^[ \t]*(```|~~~)/) { fence = !fence; return }
      if (fence || index(line, "[[") == 0) return
      s = line; gsub(/`[^`]*`/, "", s)
      while ((i = index(s, "[[")) > 0) {
        s = substr(s, i + 2); j = index(s, "]]")
        if (j == 0) break
        t = substr(s, 1, j - 1); s = substr(s, j + 2)
        sub(/[|#].*$/, "", t); sub(/\\$/, "", t); t = tolower(trim(t)); sub(/\.md$/, "", t)
        if (t == "readme" || t == "profile" || t == "tasks.base" || t == "_conventions") nbare++
      }
    }
    {
      path = $0
      if (path == "") next
      n = split(path, part, "/"); id = (n >= 2 ? part[n - 1] : path)
      lineno = 0; st = 0; key = ""; na = 0; crlf = 0; lf = 0; lastlf = 0; fence = 0; nbare = 0
      while ((getline line < path) > 0) {
        lineno++
        if (sub(/\r$/, "", line)) { crlf++; lastlf = 0 } else { lf++; lastlf = 1 }
        if (lineno == 1) {
          sub(/^\357\273\277/, "", line)
          if (line == "---") { st = 1; continue }
          st = 2
        }
        if (st == 1) front(line); else body(line)
      }
      close(path)
      if (!lineno) next
      if (!na) fact("alias1", "-")
      if (nbare) fact("bare", nbare)
      if (crlf && lf) fact("eol", (lf == 1 && lastlf ? "last" : "mixed"))
    }'
}

# Check that the profile exists and has every contract key and the seven sections.
sb_doc_check_profile() {
  local bad
  if [ ! -f "$SB_P_PROFILE" ]; then
    sb_doc_row fail profile "$SB_P_NAME" "profile.md" "run /obsidian-dev-second-brain:vault-setup adopt $SB_P_PATH"
    return 0
  fi
  bad="$(LC_ALL=C awk '
    BEGIN {
      nk = split("aliases type project ticket_keys tracker persona tasks_root topics_root sprints_root " \
        "sprint_length_days sprint_anchor_end base_branch branch_pattern environments repos achievements_skill tags", keys, " ")
      ns = split("Stories|Topics|Repos|Environments|Sprints|Docs|Live systems", secs, "|")
    }
    { sub(/\r$/, "") }
    NR == 1 { sub(/^\357\273\277/, ""); st = ($0 == "---" ? 1 : 2); next }
    st == 1 {
      if ($0 == "---") st = 2
      else if ($0 ~ /^[A-Za-z0-9_][A-Za-z0-9_-]*:/) { k = $0; sub(/:.*$/, "", k); has[k] = 1 }
      next
    }
    /^(```|~~~)/ { fence = !fence }
    !fence && /^## / { h = $0; sub(/^##[ \t]+/, "", h); sub(/[ \t#]+$/, "", h); sec[tolower(h)] = 1 }
    END {
      for (i = 1; i <= nk; i++) if (!(keys[i] in has)) print keys[i]
      for (i = 1; i <= ns; i++) if (!(tolower(secs[i]) in sec)) print "## " secs[i]
    }' "$SB_P_PROFILE")"
  sb_doc_report fail profile "$SB_P_NAME" "$bad" "add them to claude/profile.md, as in the profile template"
}

# Check that the board file exists.
sb_doc_check_board() {
  local bad=""
  [ -f "$SB_P_DIR/$SB_TASKS_ROOT/tasks.base" ] || bad="tasks.base"
  sb_doc_report fail board "$SB_P_NAME" "$bad" "run second-brain scaffold project again with the same name and path to write it"
}

# Check that each hub scaffold project writes is there, with something in it.
sb_doc_check_hubs() {
  local hubs h bad="" nl=$'\n'
  hubs=("README.md" "claude/README.md" "$SB_TASKS_ROOT/README.md")
  [ "$SB_TOPICS_ROOT" = "." ] || hubs[${#hubs[@]}]="$SB_TOPICS_ROOT/README.md"
  [ "$SB_DOC_SPRINTS" -eq 0 ] || hubs[${#hubs[@]}]="$SB_SPRINTS_ROOT/README.md"
  for h in "${hubs[@]}"; do
    [ -s "$SB_P_DIR/$h" ] || bad="$bad$h$nl"
  done
  sb_doc_report warn hubs "$SB_P_NAME" "$bad" \
    "run second-brain scaffold project again with the same name and path: it writes what is missing and overwrites nothing, so delete an empty hub first"
}

# Print the facts, then the core scan rows, of the current project, for one awk to join.
sb_doc_feed() {
  printf '%s\n%s\n' "$SB_DOC_FACTS" "$SB_DOC_SCAN"
}

# Check each task: the first alias is the folder name, type is set and its tag is present.
sb_doc_check_task_frontmatter() {
  local bad
  bad="$(sb_doc_feed | awk -F'\t' '
    NF == 3 { if ($1 == "alias1") first[$2] = $3; else if ($1 == "tag") tag[$2 "\t" $3] = 1; next }
    NF >= 12 {
      if (first[$2] != $2) print $2 ":alias"
      if ($10 == "-") print $2 ":type"
      else if (!(($2 "\ttype/" $10) in tag)) print $2 ":type-tag"
    }')"
  sb_doc_report fail task-frontmatter "$SB_P_NAME" "$bad" "make the first alias the folder name; set type and its type/ tag"
}

# Check that every task has one of the five statuses; nothing here is ever changed.
sb_doc_check_needs_a_status() {
  local bad
  bad="$(printf '%s\n' "$SB_DOC_SCAN" | awk -F'\t' '
    NF < 12 || $3 == "planned" || $3 == "in-progress" || $3 == "in-review" || $3 == "done" || $3 == "abandoned" { next }
    { print $2 ($3 == "-" ? "" : ":" $3) }')"
  sb_doc_report warn needs-a-status "$SB_P_NAME" "$bad" "ask for the status, then run second-brain task set <ID> status=<status>"
}

# Print id, file and status of each task whose status/ tag does not follow a valid status.
sb_doc_status_drift() {
  sb_doc_feed | awk -F'\t' '
    NF == 3 { if ($1 == "tag" && substr($3, 1, 7) == "status/") { cnt[$2]++; got[$2] = $3 } next }
    NF >= 12 {
      if ($3 == "done" || $3 == "abandoned") want = "status/done"
      else if ($3 == "planned" || $3 == "in-progress" || $3 == "in-review") want = "status/active"
      else next
      if (cnt[$2] != 1 || got[$2] != want) print $2 "\t" $1 "\t" $3
    }'
}

# Check that the status/ tag follows the status property.
sb_doc_check_status_tag() {
  local bad
  bad="$(sb_doc_status_drift | cut -f1)"
  sb_doc_report warn status-tag "$SB_P_NAME" "$bad" "run second-brain doctor --fix"
}

# Check the raw frontmatter for values YAML reads as something else.
sb_doc_check_yaml_traps() {
  local bad
  bad="$(printf '%s\n' "$SB_DOC_FACTS" | awk -F'\t' '$1 == "trap" && !seen[$2 ":" $3]++ { print $2 ":" $3 }')"
  sb_doc_report fail yaml-traps "$SB_P_NAME" "$bad" "put the value in double quotes"
}

# Check that no alias sits on two notes among the task READMEs and the project's hubs.
sb_doc_check_alias_unique() {
  local bad f a hubs="" seen tab=$'\t' nl=$'\n'
  seen="$nl"
  for f in "$SB_P_DIR/README.md" "$SB_P_DIR/$SB_TASKS_ROOT/README.md" \
    "$SB_P_DIR/$SB_TOPICS_ROOT/README.md" "$SB_P_DIR/$SB_SPRINTS_ROOT/README.md"; do
    f="${f/\/.\///}"
    [ -f "$f" ] || continue
    case "$seen" in *"$nl$f$nl"*) continue ;; esac
    seen="$seen$f$nl"
    while IFS= read -r a; do
      [ -z "$a" ] || hubs="${hubs}alias${tab}${f}${tab}${a}${nl}"
    done <<EOF
$(sb_fm_list "$f" aliases 2>/dev/null)
EOF
  done
  bad="$(printf '%s%s\n' "$hubs" "$SB_DOC_FACTS" | awk -F'\t' '
    $1 == "alias" {
      k = tolower($3)
      if ((k "\t" $2) in seen) next
      seen[k "\t" $2] = 1
      if (++n[k] == 2) print $3
    }')"
  sb_doc_report fail alias-unique "$SB_P_NAME" "$bad" "rename the alias on one of the notes that carry it"
}

# Check that every folder directly under the tasks root holds a README with something in it.
sb_doc_check_no_readme() {
  local d bad="" nl=$'\n'
  for d in "$SB_P_DIR/$SB_TASKS_ROOT"/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"
    [ -s "$d/README.md" ] || bad="$bad${d##*/}$nl"
  done
  sb_doc_report warn no-readme "$SB_P_NAME" "$bad" "write its README from the task template, or move the folder out of the tasks root"
}

# Print the profile's topic exceptions, lines "- <tag> -> <folder>" under ## Topics, as tag, folder.
sb_doc_topic_exceptions() {
  sb_section "$SB_P_PROFILE" Topics 2>/dev/null | LC_ALL=C awk "$(sb_awk_lib)"'
    /^[ \t]*[-*][ \t]+/ && match($0, /[ \t]+->[ \t]+/) {
      tag = substr($0, 1, RSTART - 1); folder = trim(substr($0, RSTART + RLENGTH))
      sub(/^[ \t]*[-*][ \t]+/, "", tag); gsub(/`/, "", tag); gsub(/`/, "", folder)
      tag = trim(tag); sub(/^#/, "", tag); sub(/^(\.\/|\/)+/, "", folder); sub(/\/+$/, "", folder)
      if (tag != "" && folder != "" && ("/" folder "/") !~ /\/\.\.\//) print tag "\t" folder
    }'
}

# Check that each topic tag on a task maps to a folder under the topics root, or to an exception.
sb_doc_check_topic_tags() {
  local tags depth exc dirs bad t f root="$SB_P_DIR"
  local roots
  tags="$(printf '%s\n' "$SB_DOC_SCAN" | awk -F'\t' '
    NF >= 12 && $5 != "-" { n = split($5, t, ","); for (i = 1; i <= n; i++) if (!seen[t[i]]++) print t[i] }')"
  if [ -z "$tags" ]; then
    sb_doc_row ok topic-tags "$SB_P_NAME" "" "-"
    return 0
  fi
  [ "$SB_TOPICS_ROOT" = "." ] || root="$SB_P_DIR/$SB_TOPICS_ROOT"
  depth="$(printf '%s\n' "$tags" | awk -F/ 'NF > m { m = NF } END { print m + 0 }')"
  exc="$(sb_doc_topic_exceptions)"
  roots=("$root")
  while IFS=$'\t' read -r t f; do
    [ -z "$f" ] || roots[${#roots[@]}]="$SB_P_DIR/$f"
  done <<EOF
$exc
EOF
  dirs="$(find "${roots[@]}" -maxdepth "$depth" -name '.*' -prune -o -path "$SB_P_DIR/$SB_TASKS_ROOT" -prune -o -type d -print 2>/dev/null)"
  bad="$(printf '%s\n\034\n%s\n\034\n%s\n' "$exc" "$dirs" "$tags" | LC_ALL=C SB_DIR="$SB_P_DIR" SB_TROOT="$SB_TOPICS_ROOT" awk -F'\t' '
    function norm(s) { s = tolower(s); gsub(/[ _]/, "-", s); return s }
    BEGIN { part = 1; dir = ENVIRON["SB_DIR"] "/"; pre = ENVIRON["SB_TROOT"]; pre = (pre == "." ? "" : norm(pre) "/") }
    $0 == "\034" { part++; next }
    $0 == "" { next }
    part == 1 { ne++; etag[ne] = norm($1); efold[ne] = norm($2); next }
    part == 2 { if (substr($0, 1, length(dir)) == dir) has[norm(substr($0, length(dir) + 1))] = 1; next }
    {
      t = norm($0); ok = ((pre t) in has)
      for (i = 1; i <= ne && !ok; i++) {
        if (t == etag[i]) ok = (efold[i] in has)
        else if (substr(t, 1, length(etag[i]) + 1) == etag[i] "/") ok = ((efold[i] "/" substr(t, length(etag[i]) + 2)) in has)
      }
      if (!ok) print $0
    }')"
  sb_doc_report warn topic-tags "$SB_P_NAME" "$bad" "create the folder, fix the tag, or add \"- <tag> -> <folder>\" under ## Topics in the profile"
}

# Check that each repository in the profile has a row in the Code to doc map of its Docs section.
sb_doc_check_code_doc_map() {
  local bad=""
  [ ! -f "$SB_P_PROFILE" ] || bad="$(LC_ALL=C awk "$(sb_awk_lib)"'
    function add(v) { if (v != "") repo[++nr] = v }
    { sub(/\r$/, "") }
    NR == 1 { sub(/^\357\273\277/, ""); st = ($0 == "---" ? 1 : 2); if (st == 1) next }
    st == 1 {
      if ($0 == "---") st = 2
      else if ($0 ~ /^[A-Za-z0-9_][A-Za-z0-9_-]*:/) {
        i = index($0, ":"); key = substr($0, 1, i - 1); v = trim(substr($0, i + 1))
        if (key != "repos") next
        if (substr(v, 1, 1) == "[") { n = split_inline(v, it); for (k = 1; k <= n; k++) add(it[k]) }
        else add(unq(v))
      } else if (key == "repos" && $0 ~ /^[ \t]*-([ \t]|$)/) { v = $0; sub(/^[ \t]*-[ \t]*/, "", v); add(unq(v)) }
      next
    }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^#+[ \t]/ {
      h = tolower($0); sub(/[ \t#]+$/, "", h); match(h, /^#+/); hdr = 0
      if (RLENGTH == 1) { indocs = 0; inmap = 0 }
      else if (RLENGTH == 2) { indocs = (h ~ /^##[ \t]+docs$/); inmap = 0 }
      else if (RLENGTH == 3) inmap = (indocs && h ~ /^###[ \t]+code to doc map$/)
      next
    }
    !inmap { next }
    !/^[ \t]*\|/ { hdr = 0; next }
    {
      c = $0; sub(/^[ \t]*\|/, "", c); i = index(c, "|")
      if (i) c = substr(c, 1, i - 1)
      gsub(/`/, "", c); c = tolower(trim(c))
      if (c == "repo") hdr = 1
      else if (hdr && c != "" && c != "<repo>" && c !~ /^:?-+:?$/) has[c] = 1
    }
    END { for (r = 1; r <= nr; r++) if (!(tolower(repo[r]) in has)) print repo[r] }' "$SB_P_PROFILE")"
  sb_doc_report warn code-doc-map "$SB_P_NAME" "$bad" "add a row for the repository under \"Code to doc map\" in the profile's Docs section"
}

# Check that each repository with a recorded location has its folder; nothing recorded is fine.
sb_doc_check_repos() {
  local bad
  bad="$(sb_repo_rows "$SB_P_NAME" 2>/dev/null | awk -F'\t' '$3 == "missing" { print $1 }')"
  sb_doc_report warn repos "$SB_P_NAME" "$bad" "correct repos_root or the repo_paths entry in the profile, then run second-brain repo <project>"
}

# Check the sprints: one in progress at most, none past its end, a note for every sprint id on a task.
sb_doc_check_sprints() {
  local dir="$SB_P_DIR/$SB_SPRINTS_ROOT" notes="" upcoming raw bad nl=$'\n' tab=$'\t'
  local fix="open the next sprint through the sprint skill; do not re-point carried tasks by hand"
  if [ "$SB_DOC_SPRINTS" -eq 0 ]; then
    # Sprints are off: the one thing left to say is a sprint note nobody can close any more.
    bad=""
    [ ! -d "$dir" ] || bad="$(sb_sprint_files "$dir" | sb_sprint_scan | awk -F'\t' '$3 == "in-progress" { print $2 ":in-progress" }')"
    if [ -n "$bad" ]; then
      sb_doc_row warn sprints "$SB_P_NAME" "$bad" "set uses_sprints to true, close the sprint through the sprint skill, then set it to false again"
    else
      sb_doc_row ok sprints "$SB_P_NAME" "" "sprints are off"
    fi
    return 0
  fi
  [ ! -d "$dir" ] || notes="$(sb_sprint_files "$dir" | sb_sprint_scan)"
  # A close leaves carried tasks on the id sprint next gives; that id is exempt while no sprint runs.
  upcoming="$(sb_sprint_next_row 2>/dev/null | cut -f1)"
  raw="$(printf '%s\n\034\n%s\n' "$notes" "$SB_DOC_SCAN" | SB_NOW="$(sb_today)" SB_UP="$upcoming" awk -F'\t' '
    BEGIN { part = 1; today = ENVIRON["SB_NOW"]; up = ENVIRON["SB_UP"] }
    $0 == "\034" { part = 2; next }
    $0 == "" { next }
    part == 1 {
      b = $1; sub(/^.*\//, "", b); sub(/\.md$/, "", b); has[b] = 1; has[$2] = 1
      if ($3 == "in-progress") { n++; id[n] = $2; late[n] = (($5 == "-" ? $2 : $5) "" < today "") }
      next
    }
    NF >= 12 && $4 != "-" && !($4 in has) { no++; oid[no] = $2; osp[no] = $4; isopen[no] = ($3 != "done" && $3 != "abandoned") }
    END {
      for (i = 1; i <= n; i++) if (late[i]) print "sprint\t" id[i] ":past-end"; else if (n > 1) print "sprint\t" id[i] ":in-progress"
      for (i = 1; i <= no; i++) if (!(n == 0 && up != "" && osp[i] == up && isopen[i])) print "task\t" oid[i] ":" osp[i]
    }')"
  case "$nl$raw" in
    *"${nl}sprint$tab"*) fix="close the extra or ended sprint with second-brain sprint close; point each task at a sprint that has a note" ;;
  esac
  bad="$(printf '%s\n' "$raw" | cut -f2-)"
  sb_doc_report fail sprints "$SB_P_NAME" "$bad" "$fix"
}

# Check that no note under the project holds a link that resolves to no file; the vault is read once per run.
sb_doc_check_unresolved_links() {
  local bad
  if [ -z "$SB_DOC_UNRES_DONE" ]; then
    SB_DOC_UNRES="$(sb_graph_unresolved)"
    SB_DOC_UNRES_DONE=1
  fi
  # An offender is a place: the note's path under the project, and the line that holds the link.
  bad="$(printf '%s\n' "$SB_DOC_UNRES" | LC_ALL=C SB_P="$SB_P_PATH/" awk '
    BEGIN { p = tolower(ENVIRON["SB_P"]); n = length(p) }
    tolower(substr($0, 1, n)) == p && match($0, /\.[Mm][Dd]:[0-9]+: /) {
      place = substr($0, n + 1, RSTART + RLENGTH - 3 - n)
      if (!seen[place]++) print place
    }')"
  sb_doc_report warn unresolved-links "$SB_P_NAME" "$bad" "give each link a path that exists; second-brain unresolved <project> lists them"
}

# Check that no task README links a repeated file name without a path.
sb_doc_check_bare_links() {
  local bad
  bad="$(printf '%s\n' "$SB_DOC_FACTS" | awk -F'\t' '$1 == "bare" { print $2 }')"
  sb_doc_report warn bare-links "$SB_P_NAME" "$bad" "write the link with its vault path and the alias as display text"
}

# Check that no task README mixes CRLF and bare LF line endings.
sb_doc_check_line_endings() {
  local id kind bad="" nl=$'\n'
  while IFS=$'\t' read -r id kind; do
    [ -n "$id" ] || continue
    # A single bare last line counts only when a newline ends it.
    if [ "$kind" = "last" ] && [ -n "$(tail -c 1 "$SB_P_DIR/$SB_TASKS_ROOT/$id/README.md")" ]; then continue; fi
    bad="$bad$id$nl"
  done <<EOF
$(printf '%s\n' "$SB_DOC_FACTS" | awk -F'\t' '$1 == "eol" { print $2 "\t" $3 }')
EOF
  sb_doc_report warn line-endings "$SB_P_NAME" "$bad" "rewrite the file with one kind of line ending"
}

# Print every row in the contract's order: the vault checks, then the checks of each index row given.
sb_doc_rows() {
  local c name path keys
  SB_DOC_UNRES=""
  SB_DOC_UNRES_DONE=""
  SB_DOC_PIECES="$(sb_doc_piece_files | sb_doc_piece_scan)"
  for c in pointer index conventions import links double_registration \
    always_loaded_size descriptions skill_size; do
    "sb_doc_check_$c"
  done
  while IFS=$'\t' read -r name path keys <&3; do
    [ -n "$path" ] || continue
    sb_doc_project "$name" "$path" "$keys"
    for c in profile board hubs task_frontmatter needs_a_status status_tag yaml_traps \
      alias_unique no_readme topic_tags code_doc_map repos sprints unresolved_links bare_links line_endings; do
      "sb_doc_check_$c"
    done
  done 3<<EOF
$1
EOF
  return 0
}

# Read doctor rows on stdin; print them as a JSON array of objects.
sb_doc_json() {
  LC_ALL=C awk '
    function esc(s,   i, c, out, n) {
      out = ""; n = length(s)
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (c == "\\" || c == "\"") out = out "\\" c
        else if (c in ctl) out = out ctl[c]
        else out = out c
      }
      return "\"" out "\""
    }
    BEGIN { for (i = 1; i < 32; i++) ctl[sprintf("%c", i)] = sprintf("\\u%04x", i); printf "[" }
    {
      n = split($0, f, / [|] /)
      if (n < 6) next
      for (i = 7; i <= n; i++) f[6] = f[6] " | " f[i]
      list = ""
      if (f[5] != "-") { m = split(f[5], o, /, /); for (i = 1; i <= m; i++) list = list (i > 1 ? ", " : "") esc(o[i]) }
      printf "%s\n  {\"result\": %s, \"check\": %s, \"scope\": %s, \"count\": %d, \"offenders\": [%s], \"fix\": %s}", \
        (rows++ ? "," : ""), esc(f[1]), esc(f[2]), esc(f[3]), f[4], list, esc(f[6])
    }
    END { print (rows ? "\n]" : "]") }'
}

# Make the status/ tag follow the status on each task where they disagree; print each change.
sb_doc_fix() {
  local name path keys id file status tag n=0
  while IFS=$'\t' read -r name path keys <&3; do
    [ -n "$path" ] || continue
    sb_doc_project "$name" "$path" "$keys"
    while IFS=$'\t' read -r id file status <&4; do
      [ -n "$file" ] || continue
      sb_fm_status_tag "$file" "$status" || continue
      [ "$SB_FM_CHANGED" -eq 1 ] || continue
      tag="status/active"
      case "$status" in done | abandoned) tag="status/done" ;; esac
      n=$((n + 1))
      printf 'fixed: %s -> %s (%s)\n' "$id" "$tag" "$name"
    done 4<<EOF
$(sb_doc_status_drift)
EOF
  done 3<<EOF
$1
EOF
  [ "$n" -gt 0 ] || printf 'fixed: nothing\n'
}

# Run the health check; exit 0 when no row fails, 1 when one does, 2 with no vault.
cmd_doctor() {
  local project="" json=0 fix=0 rows="" prows="" rc=0
  local usage="usage: second-brain doctor [project] [--json] [--fix]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json=1 ;;
      --fix) fix=1 ;;
      -*) sb_die 5 "$usage" ;;
      *)
        [ -z "$project" ] || sb_die 5 "$usage"
        project="$1"
        ;;
    esac
    shift
  done
  SB_ROOT="$(sb_root 2>/dev/null)" || SB_ROOT=""
  if [ -z "$SB_ROOT" ]; then
    if [ "$json" -eq 1 ]; then sb_doc_check_pointer | sb_doc_json; else sb_doc_check_pointer; fi
    return 2
  fi
  if [ -n "$project" ]; then
    sb_project_resolve "$project" || rc=$?
    if [ "$rc" -eq 4 ]; then
      printf '%s\n' "$SB_P_ROWS"
      sb_die 4 "several projects match: $project"
    fi
    [ "$rc" -eq 0 ] || sb_die 1 "no project matches: $project (list them with: second-brain projects)"
    prows="$SB_P_NAME"$'\t'"$SB_P_PATH"$'\t'"$SB_P_KEYS"
  else
    prows="$(sb_projects_tsv 2>/dev/null)"
  fi
  if [ "$fix" -eq 1 ]; then
    # With --json the changes go to stderr, so stdout stays one JSON document.
    if [ "$json" -eq 1 ]; then sb_doc_fix "$prows" >&2; else sb_doc_fix "$prows"; fi
  fi
  rows="$(sb_doc_rows "$prows")"
  if [ "$json" -eq 1 ]; then printf '%s\n' "$rows" | sb_doc_json; else printf '%s\n' "$rows"; fi
  case $'\n'"$rows" in *$'\n''fail | '*) return 1 ;; esac
  return 0
}

# Print one line when no vault is set up, for the SessionStart hook; always exit 0.
cmd_session_check() {
  local v="${SECOND_BRAIN_VAULT:-}"
  [ -n "$v" ] || v="$(sb_link_home)/second-brain-vault"
  if [ -d "$v/.obsidian" ] && [ -f "$v/CLAUDE.md" ]; then return 0; fi
  printf 'second-brain: no vault is set up - run /obsidian-dev-second-brain:vault-setup init\n'
  return 0
}
