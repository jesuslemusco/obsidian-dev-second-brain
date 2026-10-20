#!/usr/bin/env bash
# doctor.sh - the health check: one row per check for the vault and each project, and the hook check.

# Print one row: result | check | scope | count | offenders | fix. Offenders come one per line.
# An offender is cut at 48 bytes, or at the width given last. A short tag after its last colon
# is kept whole, so the cut falls in the value before it.
sb_doc_row() {
  local result="$1" check="$2" scope="$3" list="$4" fix="${5:--}" width="${6:-48}"
  scope="${scope//|//}"
  fix="${fix//|//}"
  if [ -z "$list" ]; then
    printf '%s | %s | %s | 0 | - | %s\n' "$result" "$check" "$scope" "$fix"
    return 0
  fi
  printf '%s\n' "$list" | LC_ALL=C SB_HEAD="$result | $check | $scope" SB_FIX="$fix" SB_W="$width" awk "$(sb_awk_lib)"'
    function tidy(s,   i, tag) {
      gsub(/[\t\r]/, " ", s); gsub(/[|]/, "/", s); gsub(/,/, ";", s); s = trim(s)
      if (length(s) <= w) return s
      for (i = length(s); i > 1 && substr(s, i, 1) != ":"; i--) continue
      tag = substr(s, i)
      if (i > 1 && length(tag) > 1 && length(tag) <= 21 && tag !~ / /) return cut(substr(s, 1, i - 1), w - length(tag)) tag
      return cut(s, w)
    }
    BEGIN { w = ENVIRON["SB_W"] + 0 }
    $0 != "" { n++; if (n <= 5) out = out (n > 1 ? ", " : "") tidy($0) }
    END { print ENVIRON["SB_HEAD"] " | " (n + 0) " | " (n ? out : "-") " | " ENVIRON["SB_FIX"] }'
}

# Print an ok row when the offender list is empty, else a row at the given level with its fix.
# A sixth argument is the width offenders are cut at.
sb_doc_report() {
  if [ -z "$4" ]; then
    sb_doc_row ok "$2" "$3" "" "-"
  else
    sb_doc_row "$1" "$2" "$3" "$4" "$5" "${6:-}"
  fi
}

# Set SB_DOC_FOLD to a relative path with its empty and "." parts folded out. Return 1 when the
# path leaves the folder it starts in: a ".." part or a backslash.
sb_doc_fold() {
  local rest="$1" seg
  SB_DOC_FOLD=""
  case "$rest" in *\\*) return 1 ;; esac
  while [ -n "$rest" ]; do
    seg="${rest%%/*}"
    case "$rest" in */*) rest="${rest#*/}" ;; *) rest="" ;; esac
    case "$seg" in
      '' | .) ;;
      ..) return 1 ;;
      *) SB_DOC_FOLD="${SB_DOC_FOLD:+$SB_DOC_FOLD/}$seg" ;;
    esac
  done
  return 0
}

# Return 0 when an index path, as it is written, names a folder inside the vault; sets SB_DOC_FOLD.
sb_doc_folder() {
  sb_doc_fold "$1" && [ -n "$SB_DOC_FOLD" ]
}

# Return 0 when a version, all digits, is lower than another. One too long to compare is newer.
sb_doc_older() {
  [ "${#1}" -le 9 ] && [ "${#2}" -le 9 ] && [ "$1" -lt "$2" ]
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
    if sb_doc_folder "$path" && [ -d "$SB_ROOT/$SB_DOC_FOLD" ]; then continue; fi
    bad="$bad$name:no-folder$nl"
  done <<EOF
$rows
EOF
  # Names and paths are compared without letter case and keys in upper case, as the lookups
  # compare them; "//" and "/./" in a path are folded first. A key holds a letter or a digit.
  bad="$bad$(printf '%s\n' "$rows" | LC_ALL=C awk -F'\t' '
    function see(kind, k, v) {
      k = kind SUBSEP k
      if (!(k in at)) { at[k] = NR; spell[k] = v; ord[kind, ++n[kind]] = k }
      else if (at[k] != NR) twice[k] = 1
    }
    function fold(p) { p = "/" p "/"; while (sub(/\/\.?\//, "/", p)) continue; return tolower(p) }
    $1 == "" { next }
    {
      see(1, tolower($1), $1)
      m = split($3, key, ",")
      for (i = 1; i <= m; i++) if (key[i] ~ /[A-Za-z0-9]/) see(2, toupper(key[i]), key[i])
      see(3, fold($2), $2)
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
  if [ -n "$want" ] && { [ -z "$have" ] || sb_doc_older "$have" "$want"; }; then
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
  if [ -n "$want" ] && { [ -z "$have" ] || sb_doc_older "$have" "$want"; }; then
    sb_doc_row warn conventions vault "obsidian-conventions.md:${have:-none}" \
      "the note is older than the plugin's template, version $want: delete it and run second-brain scaffold vault, or edit it by hand"
    return 0
  fi
  sb_doc_row ok conventions vault "" "-"
}

# Check that the vault's pull request format note exists.
sb_doc_check_pull_request() {
  local list=""
  [ -f "$SB_ROOT/claude/pull-request.md" ] || list="claude/pull-request.md"
  sb_doc_report warn pull-request vault "$list" "run second-brain scaffold vault to create it"
}

# Return 0 when a line of the link directory's CLAUDE.md is an import of the index.
sb_doc_imports_index() {
  local line="$1" home="$2" p
  case "$line" in @*) ;; *) return 1 ;; esac
  p="${line#@}"
  p="${p%"${p##*[![:space:]]}"}"
  p="$(sb_path_in "$p")"
  case "$p" in
    '~/'*) p="${HOME:-}/${p#??}" ;;
    /*) ;;
    *) p="$home/$p" ;;
  esac
  [ "$p" -ef "$SB_ROOT/CLAUDE.md" ]
}

# Check that the link directory's CLAUDE.md imports the index.
sb_doc_check_import() {
  local home f line bad="CLAUDE.md"
  home="$(sb_link_home)"
  f="$home/CLAUDE.md"
  if [ -f "$f" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      if sb_doc_imports_index "$line" "$home"; then
        bad=""
        break
      fi
    done <"$f"
  fi
  sb_doc_report warn import vault "$bad" "add the line @~/.claude/second-brain-vault/CLAUDE.md to CLAUDE.md in the link directory"
}

# Check that the link directory's CLAUDE.md holds no line that names a project of the index: its
# name as a whole word, as written, or its path in any letter case. The import of the index and
# the rows of a Projects table are not read, nor the files it imports. An offender is
# <project>:<line number>, or <project>:@<line number> for an import line.
sb_doc_check_global_rules() {
  local home f line n=0 skip="" rows bad="" fix nl=$'\n'
  home="$(sb_link_home)"
  f="$home/CLAUDE.md"
  rows="$(sb_projects_tsv 2>/dev/null)"
  if [ -f "$f" ] && [ -n "$rows" ] && ! [ "$f" -ef "$SB_ROOT/CLAUDE.md" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      if sb_doc_imports_index "$line" "$home"; then skip="$skip$n$nl"; fi
    done <"$f"
    bad="$(SB_ROWS="$rows" SB_SKIP="$skip" LC_ALL=C awk '
      BEGIN {
        np = split(ENVIRON["SB_ROWS"], r, "\n")
        for (i = 1; i <= np; i++) { split(r[i], c, "\t"); name[i] = c[1]; path[i] = tolower(c[2]) }
        ns = split(ENVIRON["SB_SKIP"], s, "\n")
        for (i = 1; i <= ns; i++) if (s[i] != "") skip[s[i]] = 1
      }
      # Return 1 when w is in t with no letter, digit, "_" or "-" on either side.
      function word(t, w,   i, off, rest, pre, post) {
        rest = t; off = 0
        while ((i = index(rest, w)) > 0) {
          pre = (off + i > 1) ? substr(t, off + i - 1, 1) : ""; post = substr(t, off + i + length(w), 1)
          if (pre !~ /[A-Za-z0-9_-]/ && post !~ /[A-Za-z0-9_-]/) return 1
          off += i; rest = substr(rest, i + 1)
        }
        return 0
      }
      { sub(/\r$/, "") }
      /^#[#]? / { insec = (tolower($0) ~ /^##[ \t]+projects[ \t]*$/) }
      FNR in skip { next }
      insec && /^[ \t]*\|/ { next }
      {
        for (i = 1; i <= np; i++) {
          if (name[i] == "") continue
          if (word($0, name[i]) || (path[i] !~ /^[.\/]*$/ && word(tolower($0), path[i]))) { print name[i] ":" (/^@/ ? "@" : "") FNR; next }
        }
      }' "$f")"
  fi
  fix="move the line to the project's claude/README.md under ## Rules, or to its subproject's note"
  case "$bad" in
    *:@*) fix="$fix; remove an @ import of a project's file: the index already leads to the project's rules" ;;
  esac
  sb_doc_report warn global-rules vault "$bad" "$fix"
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
    dir="$SB_ROOT/claude"
    if [ "$path" != "." ]; then
      sb_doc_folder "$path" || continue
      dir="$SB_ROOT/$SB_DOC_FOLD/claude"
    fi
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

# Check that every scanned skill or agent has a description, and none over 200 characters.
sb_doc_check_descriptions() {
  local bad
  bad="$(printf '%s\n' "$SB_DOC_PIECES" | awk -F'\t' '
    NF < 4 { next }
    $3 == 0 { print $1 ":none" }
    $3 > 200 { print $1 ":" $3 }')"
  sb_doc_report warn descriptions vault "$bad" "give each one a description of one sentence under 200 characters"
}

# Check that no scanned SKILL.md is over 150 lines.
sb_doc_check_skill_size() {
  local bad
  bad="$(printf '%s\n' "$SB_DOC_PIECES" | awk -F'\t' '$2 == "skill" && $4 > 150 { print $1 ":" $4 }')"
  sb_doc_report warn skill-size vault "$bad" "move the detail of one mode into a sibling file read only in that mode"
}

# Set SB_DOC_ROOT to a root of the profile, folded, or to its default when the key is absent.
# The value is read as every command reads it, with a slash in front or behind dropped. One
# that leaves the project gives the default too, and is kept for the profile check.
sb_doc_root() {
  local raw
  SB_DOC_ROOT="$2"
  raw="$(sb_setting "$SB_P_PATH" "$1" "")"
  [ -n "$raw" ] || return 0
  if sb_doc_fold "$raw"; then
    SB_DOC_ROOT="${SB_DOC_FOLD:-.}"
  else
    SB_DOC_LEAVES="$SB_DOC_LEAVES$1:leaves-project"$'\n'
  fi
}

# Set the project globals for one index row, without exiting on a bad row.
sb_doc_project() {
  SB_P_NAME="$1"
  SB_P_PATH="$2"
  SB_P_KEYS="${3:-}"
  SB_P_DIR="$SB_ROOT/$SB_P_PATH"
  SB_P_PROFILE="$SB_P_DIR/claude/profile.md"
  SB_DOC_LEAVES=""
  sb_doc_root tasks_root tasks
  SB_TASKS_ROOT="$SB_DOC_ROOT"
  sb_doc_root topics_root docs
  SB_TOPICS_ROOT="$SB_DOC_ROOT"
  sb_doc_root sprints_root sprints
  SB_SPRINTS_ROOT="$SB_DOC_ROOT"
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

# Check that the profile exists, has every contract key and the seven sections, and that no
# root leaves the project.
sb_doc_check_profile() {
  local bad fix="add them to claude/profile.md, as in the profile template"
  if [ ! -f "$SB_P_PROFILE" ]; then
    sb_doc_row fail profile "$SB_P_NAME" "profile.md" "run /obsidian-dev-second-brain:vault-setup adopt $SB_P_PATH"
    return 0
  fi
  [ -z "$SB_DOC_LEAVES" ] ||
    fix="write each root as a folder inside the project, with no .. part and no backslash; add a missing key or section as in the profile template"
  bad="$SB_DOC_LEAVES$(LC_ALL=C awk '
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
  sb_doc_report fail profile "$SB_P_NAME" "$bad" "$fix"
}

# Check that the board file exists, and that its Current sprint view filters on the sprint in progress.
sb_doc_check_board() {
  local base="$SB_P_DIR/$SB_TASKS_ROOT/tasks.base" cur="" lit
  if [ ! -f "$base" ]; then
    sb_doc_row fail board "$SB_P_NAME" "tasks.base" "run second-brain scaffold project again with the same name and path to write it"
    return 0
  fi
  # The helper's own Current sprint board goes by the sprint in progress, so the view should too.
  # It is read under the checked sprints root: sb_sprint_current_id takes the profile's own value.
  [ "$SB_DOC_SPRINTS" -eq 0 ] || cur="$(sb_sprint_files "$SB_P_DIR/$SB_SPRINTS_ROOT" | sb_sprint_scan |
    awk -F'\t' '$3 == "in-progress" { print $2 }' | LC_ALL=C sort | tail -1)"
  if [ -n "$cur" ]; then
    lit="$(sb_board_sprint_literal "$base")"
    if [ -z "$lit" ]; then
      # No id was read: the view is there with a filter in another form, or it is not there.
      if LC_ALL=C awk '
        { sub(/\r$/, "") }
        /^[ \t]*(-[ \t]+)?name:[ \t]*["\047]?Current sprint["\047]?[ \t]*$/ { found = 1; exit }
        END { exit(found ? 0 : 1) }' "$base"; then
        sb_doc_row warn board "$SB_P_NAME" "tasks.base:filter" \
          "write the filter of the board's Current sprint view as sprint == \"$cur\", the form sprint open rewrites"
      else
        sb_doc_row warn board "$SB_P_NAME" "tasks.base:no-view" \
          "add the Current sprint view and the sprint columns from templates/tasks.base.tmpl, with the filter on the sprint in progress, $cur"
      fi
      return 0
    fi
    if [ "$lit" != "$cur" ]; then
      sb_doc_row warn board "$SB_P_NAME" "tasks.base:$lit" "set the filter of the board's Current sprint view to the sprint in progress, $cur"
      return 0
    fi
  fi
  sb_doc_row ok board "$SB_P_NAME" "" "-"
}

# Check that each hub scaffold project writes is there, with something in it. A hub that two
# roots share, such as the project hub when a root is ".", is looked at once.
sb_doc_check_hubs() {
  local roots r h seen bad="" nl=$'\n'
  roots=("." "claude" "$SB_TASKS_ROOT" "$SB_TOPICS_ROOT")
  [ "$SB_DOC_SPRINTS" -eq 0 ] || roots[${#roots[@]}]="$SB_SPRINTS_ROOT"
  seen="$nl"
  for r in "${roots[@]}"; do
    h="$r/README.md"
    h="${h#./}"
    case "$seen" in *"$nl$h$nl"*) continue ;; esac
    seen="$seen$h$nl"
    [ -s "$SB_P_DIR/$h" ] || bad="$bad$h$nl"
  done
  sb_doc_report warn hubs "$SB_P_NAME" "$bad" \
    "run second-brain scaffold project again with the same name and path: it writes what is missing and overwrites nothing, so delete an empty hub first" 120
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

# Check that no note under the project is a task outside its own folder in the tasks root.
sb_doc_check_task_location() {
  local bad to="$SB_P_PATH/$SB_TASKS_ROOT"
  # Three parts on stdin: the index paths, the task READMEs, the notes. A project folder inside
  # this one holds its own tasks. Paths are matched without letter case, as some file systems do.
  # A note has a type when its frontmatter closes and holds the key, a colon and a blank.
  bad="$({
    sb_projects_tsv 2>/dev/null | cut -f2
    printf '\034\n%s\n\034\n' "$SB_DOC_FILES"
    sb_md_files "$SB_P_DIR"
  } | LC_ALL=C SB_R="$SB_ROOT/" SB_P="$SB_P_PATH" awk "$(sb_awk_lib)"'
    function norm(p) { while (sub(/\/\.?\//, "/", p)) continue; return p }
    BEGIN { part = 1; root = ENVIRON["SB_R"]; dir = norm(root ENVIRON["SB_P"] "/"); me = tolower(dir) }
    $0 == "\034" { part++; next }
    $0 == "" { next }
    part == 1 { q = tolower(norm(root $0 "/")); if (q != me && substr(q, 1, length(me)) == me) inner[++ni] = q; next }
    part == 2 { task[tolower(norm($0))] = 1; next }
    {
      file = $0; path = norm(file); low = tolower(path)
      if (low in task) next
      for (i = 1; i <= ni; i++) if (substr(low, 1, length(inner[i])) == inner[i]) next
      n = 0; type = ""; closed = 0
      while ((getline line < file) > 0) {
        n++
        sub(/\r$/, "", line)
        if (n == 1) { sub(/^\357\273\277/, "", line); if (line != "---") break; continue }
        if (line == "---") { closed = 1; break }
        if (line ~ /^type:([ \t]|$)/) type = unq(substr(line, 6))
      }
      close(file)
      if (closed && type == "task") print substr(path, length(dir) + 1)
    }' | LC_ALL=C sort)"
  sb_doc_report warn task-location "$SB_P_NAME" "$bad" \
    "move it with second-brain move to ${to%/.}/<ID>/README.md, and tie it to its topic with a tag" 120
}

# Print the profile's topic exceptions, lines "- <tag> -> <folder>" under ## Topics, as tag, folder.
sb_doc_topic_exceptions() {
  sb_section "$SB_P_PROFILE" Topics 2>/dev/null | LC_ALL=C awk "$(sb_awk_lib)"'
    /^[ \t]*[-*][ \t]+/ && match($0, /[ \t]+->[ \t]+/) {
      tag = substr($0, 1, RSTART - 1); folder = trim(substr($0, RSTART + RLENGTH))
      sub(/^[ \t]*[-*][ \t]+/, "", tag); gsub(/`/, "", tag); gsub(/`/, "", folder)
      tag = trim(tag); sub(/^#/, "", tag); sub(/^(\.\/|\/)+/, "", folder); sub(/\/+$/, "", folder)
      if (tag != "" && folder != "" && ("/" folder "/") !~ /\/\.\.\// && index(folder, "\\") == 0) print tag "\t" folder
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

# Print the repositories in the frontmatter of a note, the profile or a subproject note, that have
# no row in the Code to doc map of the profile's Docs section.
sb_doc_unmapped() {
  [ -f "$1" ] && [ -f "$SB_P_PROFILE" ] || return 0
  LC_ALL=C awk "$(sb_awk_lib)"'
    function add(v) { if (v != "") repo[++nr] = v }
    { sub(/\r$/, "") }
    # fileno is the place of the file among the arguments, so an empty first file still counts.
    FNR == 1 { do fileno++; while (fileno < ARGC && ARGV[fileno] != FILENAME); key = ""; sub(/^\357\273\277/, ""); st = ($0 == "---" ? 1 : 2); if (st == 1) next }
    fileno == 1 {
      if (st != 1) next
      if ($0 == "---") st = 2
      else if ($0 ~ /^[A-Za-z0-9_][A-Za-z0-9_-]*:/) {
        i = index($0, ":"); key = substr($0, 1, i - 1); v = trim(substr($0, i + 1))
        if (key != "repos") next
        if (substr(v, 1, 1) == "[") { n = split_inline(v, it); for (k = 1; k <= n; k++) add(it[k]) }
        else add(unq(v))
      } else if (key == "repos" && $0 ~ /^[ \t]*-([ \t]|$)/) { v = $0; sub(/^[ \t]*-[ \t]*/, "", v); add(unq(v)) }
      next
    }
    st == 1 { if ($0 == "---") st = 2; next }
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
    END { for (r = 1; r <= nr; r++) if (!(tolower(repo[r]) in has)) print repo[r] }' "$1" "$SB_P_PROFILE"
}

# Check that each repository in the profile has a row in the Code to doc map of its Docs section.
sb_doc_check_code_doc_map() {
  local bad
  bad="$(sb_doc_unmapped "$SB_P_PROFILE")"
  sb_doc_report warn code-doc-map "$SB_P_NAME" "$bad" "add a row for the repository under \"Code to doc map\" in the profile's Docs section"
}

# Check that each repository with a recorded location has its folder; nothing recorded is fine.
sb_doc_check_repos() {
  local bad
  bad="$(sb_repo_rows "$SB_P_NAME" 2>/dev/null | awk -F'\t' '$3 == "missing" { print $1 }')"
  sb_doc_report warn repos "$SB_P_NAME" "$bad" "correct repos_root or the repo_paths entry in the profile, then run second-brain repo <project>"
}

# Check each subproject note: its type, its repositories (listed, found, in one subproject only,
# each with a map row) and its docs folder. A project with no subproject gets no row.
sb_doc_check_subprojects() {
  local files f n r lr rows unmapped rn rp rs state seen bad="" nl=$'\n'
  files="$(sb_sub_files "$SB_P_PATH")"
  [ -n "$files" ] || return 0
  rows="$(sb_repo_rows_at "$SB_P_PATH")"
  seen="$nl"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n="$(sb_sub_name "$f")"
    [ "$(sb_fm_get "$f" type 2>/dev/null)" = "subproject" ] || bad="$bad$n:type$nl"
    [ -n "$(sb_fm_list "$f" repos 2>/dev/null)" ] || bad="$bad$n:no-repos$nl"
    [ -d "$SB_ROOT/$(sb_sub_docs "$n")" ] || bad="$bad$n:no-docs$nl"
    unmapped="$nl$(sb_doc_unmapped "$f")$nl"
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      lr="$(printf '%s' "$r" | tr '[:upper:]' '[:lower:]')"
      case "$seen" in *"$nl$lr$nl"*) bad="$bad$r:twice$nl" ;; esac
      seen="$seen$lr$nl"
      case "$unmapped" in *"$nl$r$nl"*) bad="$bad$n/$r:no-map-row$nl" ;; esac
      state="unknown"
      while IFS=$'\t' read -r rn rp rs; do
        if [ "$rn" = "$r" ]; then
          state="$rs"
          break
        fi
      done <<EOF2
$rows
EOF2
      case "$state" in
        ok) ;;
        missing) bad="$bad$n/$r:missing$nl" ;;
        *) bad="$bad$n/$r:no-location$nl" ;;
      esac
    done <<EOF2
$(sb_fm_list "$f" repos 2>/dev/null)
EOF2
  done <<EOF
$files
EOF
  sb_doc_report warn subprojects "$SB_P_NAME" "$bad" \
    "set type: subproject and the repos in the note, record where each repo is, create the docs folder <topics root>/<name>/, add a Code to doc map row per repo, and keep each repo in one subproject"
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

# Check that each depends_on link leads to a note, and that no tasks of the project wait on each other in a ring.
# A ring is a strongly connected group of two tasks or more, or a task that waits on itself. Tarjan's
# algorithm finds them with a stack of its own, since a deep recursion overflows some awks.
sb_doc_check_depends_on() {
  local bad
  if ! bad="$(printf '%s\n' "$SB_DOC_SCAN" | LC_ALL=C SB_R="$SB_ROOT/" awk -F'\t' '
    function rel(p) { if (substr(p, 1, length(root)) == root) p = substr(p, length(root) + 1); sub(/\.md$/, "", p); return tolower(p) }
    function found(t,   f, l, r) {
      if (tolower(t) in node) return 1
      if (("/" t "/") ~ /\/\.\.\// || index(t, "\\") || substr(t, 1, 1) == "/" || t == "") return 0
      f = root t ".md"; r = (getline l < f); close(f)
      return r >= 0
    }
    BEGIN { root = ENVIRON["SB_R"] }
    NF >= 13 { n++; node[rel($1)] = n; id[n] = $2; dep[n] = $13 }
    END {
      for (u = 1; u <= n; u++) {
        if (dep[u] == "-") continue
        m = split(dep[u], d, ","); miss = 0
        for (k = 1; k <= m; k++) {
          if (!found(d[k])) miss = 1
          t = tolower(d[k])
          if (t in node) { v = node[t]; edge[u, ++ne[u]] = v; if (v == u) ring[u] = 1 }
        }
        if (miss) print id[u] ":missing"
      }
      cnt = 0; sp = 0
      for (s = 1; s <= n; s++) {
        if (s in num) continue
        top = 1; cs[1] = s; ci[1] = 0; num[s] = low[s] = ++cnt; st[++sp] = s; on[s] = 1
        while (top > 0) {
          u = cs[top]
          if (ci[top] < ne[u]) {
            v = edge[u, ++ci[top]]
            if (!(v in num)) { num[v] = low[v] = ++cnt; st[++sp] = v; on[v] = 1; cs[++top] = v; ci[top] = 0 }
            else if (on[v] && num[v] < low[u]) low[u] = num[v]
            continue
          }
          if (low[u] == num[u]) {
            for (j = sp; st[j] != u; j--) continue
            for (k = sp; k >= j; k--) { on[st[k]] = 0; if (sp > j) ring[st[k]] = 1 }
            sp = j - 1
          }
          top--
          if (top > 0 && low[u] < low[cs[top]]) low[cs[top]] = low[u]
        }
      }
      for (u = 1; u <= n; u++) if (u in ring) print id[u] ":cycle"
    }')"; then
    sb_doc_row fail depends-on "$SB_P_NAME" "awk:error" "the check could not run; run second-brain doctor again, and report the error if it stays"
    return 0
  fi
  sb_doc_report warn depends-on "$SB_P_NAME" "$bad" "link each depends_on item to a task README that exists; break a cycle with second-brain task dep <ID> remove <ID>"
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
  for c in pointer index conventions pull_request import global_rules links double_registration \
    always_loaded_size descriptions skill_size; do
    "sb_doc_check_$c"
  done
  while IFS=$'\t' read -r name path keys <&3; do
    # A row whose path leaves the vault gets no rows, and nothing under it is opened.
    sb_doc_folder "$path" || continue
    sb_doc_project "$name" "$SB_DOC_FOLD" "$keys"
    for c in profile board hubs task_frontmatter needs_a_status status_tag yaml_traps \
      alias_unique no_readme task_location topic_tags code_doc_map repos subprojects sprints unresolved_links bare_links \
      line_endings depends_on; do
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
    sb_doc_folder "$path" || continue
    sb_doc_project "$name" "$SB_DOC_FOLD" "$keys"
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

# Print the branch checked out in the repository that holds a directory, read from its files:
# its name, or "detached". Nothing outside a repository.
sb_doc_branch() {
  local d="$1" g="" head=""
  while [ -n "$d" ]; do
    if [ -d "$d/.git" ]; then
      g="$d/.git"
      break
    fi
    if [ -f "$d/.git" ]; then
      # A linked worktree: the file names its own git folder.
      IFS= read -r g <"$d/.git"
      g="${g%$'\r'}"
      g="$(sb_path_in "${g#gitdir: }")"
      case "$g" in /*) ;; *) g="$d/$g" ;; esac
      break
    fi
    case "$d" in */*) d="${d%/*}" ;; *) d="" ;; esac
  done
  [ -n "$g" ] && [ -f "$g/HEAD" ] || return 0
  IFS= read -r head <"$g/HEAD"
  head="${head%$'\r'}"
  case "$head" in
    'ref: refs/heads/'?*) printf '%s\n' "${head#ref: refs/heads/}" ;;
    ?*) printf 'detached\n' ;;
  esac
}

# Print the first ticket id a branch names: a key of the project, a hyphen and a number, compared
# without letter case and printed with the key as the index spells it.
sb_doc_ticket() {
  SB_B="$1" SB_K="$2" awk 'BEGIN {
    lb = tolower(ENVIRON["SB_B"]); n = split(ENVIRON["SB_K"], k, ",")
    for (i = 1; i <= n; i++) {
      if (k[i] !~ /[A-Za-z0-9]/) continue
      lk = tolower(k[i]) "-"; from = 1
      while ((j = index(substr(lb, from), lk)) > 0) {
        p = from + j - 1
        if ((p == 1 || substr(lb, p - 1, 1) !~ /[a-z0-9]/) && match(substr(lb, p + length(lk)), /^[0-9]+/)) {
          if (!best || p < best || (p == best && length(k[i]) > length(key))) {
            best = p; key = k[i]; num = substr(lb, p + length(lk), RLENGTH)
          }
          break
        }
        from = p + 1
      }
    }
    if (best) print key "-" num
  }'
}

# Print the session block for a directory, or nothing when no project of the index holds it.
sb_doc_session() {
  local cwd rows sub sprint branch ticket f status nxt
  cwd="$(cd "$1" 2>/dev/null && pwd -P)" || return 0
  SB_ROOT="$(sb_root 2>/dev/null)" || return 0
  rows="$(sb_project_rows_by_cwd "$cwd" 2>/dev/null)"
  case "$rows" in '' | *$'\n'*) return 0 ;; esac
  IFS=$'\t' read -r SB_P_NAME SB_P_PATH SB_P_KEYS <<EOF
$rows
EOF
  printf 'second-brain context for this session:\nproject: %s\n' "$SB_P_NAME"
  sub="$(sb_sub_by_cwd "$SB_P_PATH" "$cwd" 2>/dev/null)"
  case "$sub" in '' | *$'\n'*) ;; *) printf 'subproject: %s\n' "$sub" ;; esac
  if sb_uses_sprints "$SB_P_PATH"; then
    sprint="$(sb_sprint_current_id "$SB_P_PATH" 2>/dev/null)"
    printf 'sprint: %s\n' "${sprint:-none}"
  fi
  branch="$(sb_doc_branch "$cwd")"
  ticket=""
  [ -z "$branch" ] || ticket="$(sb_doc_ticket "$branch" "$SB_P_KEYS")"
  printf 'branch: %s\nticket: %s\n' "${branch:-none}" "${ticket:-none}"
  if [ -n "$ticket" ]; then
    f="$(sb_task_by_path "$ticket" "$rows" | cut -f2-)"
    [ -n "$f" ] || f="$(sb_task_by_alias "$ticket" "$rows" | cut -f2- | head -1)"
    if [ -n "$f" ]; then
      status="$(sb_fm_get "$f" status 2>/dev/null)"
      nxt="$(sb_fm_get "$f" next 2>/dev/null)"
      printf 'story: %s - %s, next: %s\n' "$(sb_rel "$f")" "${status:--}" "${nxt:--}"
    else
      printf 'story: none - run story-tracker start\n'
    fi
  fi
  printf 'rule: find and read notes with `second-brain find`, `search`, `task head` and `outline`, then a ranged read; never grep, cat or sed on vault files.\n'
}

# For the SessionStart hook; always exit 0. With no vault, one line that says so. In a directory
# of a project of the index, the session block. Anywhere else, nothing.
cmd_session_check() {
  local v="${SECOND_BRAIN_VAULT:-}" cwd="$PWD" block
  if [ "${1:-}" = "--cwd" ] && [ $# -ge 2 ]; then cwd="$(sb_path_in "$2")"; fi
  [ -n "$v" ] || v="$(sb_link_home)/second-brain-vault"
  if [ ! -d "$v/.obsidian" ] || [ ! -f "$v/CLAUDE.md" ]; then
    printf 'second-brain: no vault is set up - run /obsidian-dev-second-brain:vault-setup init\n'
    return 0
  fi
  # Built in a subshell: a command that exits on an odd vault leaves no half block and no failure.
  block="$(sb_doc_session "$cwd" 2>/dev/null)" || block=""
  [ -z "$block" ] || printf '%s\n' "$block"
  return 0
}
