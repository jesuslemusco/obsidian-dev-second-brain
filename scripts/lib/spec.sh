#!/usr/bin/env bash
# spec.sh - spec-driven delivery: where a story's spec lives, and each repo's validation.md.

# Print a value in lower case when it is one of the allowed ones, else the default.
# Usage: sb_spec_pick <value> <default> <allowed>...
sb_spec_pick() {
  local v d="$2" a
  v="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  shift 2
  for a in "$@"; do
    if [ "$v" = "$a" ]; then
      printf '%s\n' "$v"
      return 0
    fi
  done
  printf '%s\n' "$d"
}

# Print the value of a key that holds: the first file given that has a value for it decides, and
# a value that is not allowed means the default. Files that are not there are skipped.
# Usage: sb_spec_value <delivery | spec_home | validation_home> <file>...
sb_spec_value() {
  local key="$1" f v def=vault other=repo
  shift
  if [ "$key" = "delivery" ]; then
    def=direct
    other=spec
  fi
  for f in "$@"; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    v="$(sb_fm_get "$f" "$key" 2>/dev/null)"
    if [ -n "$v" ]; then
      sb_spec_pick "$v" "$def" "$def" "$other"
      return 0
    fi
  done
  printf '%s\n' "$def"
}

# Print the row of one repo of the current project, matched exact first, then without letter case:
# name, path, state, as sb_repo_rows_at prints it. Returns 1 when it is not a repo of the project.
sb_spec_repo_row() {
  local row
  row="$(sb_repo_rows_at "$SB_P_PATH" | SB_W="$1" awk -F'\t' '
    BEGIN { w = ENVIRON["SB_W"] }
    $1 == w { exact = $0 }
    tolower($1) == tolower(w) && loose == "" { loose = $0 }
    END { print (exact != "" ? exact : loose) }')"
  [ -n "$row" ] || return 1
  printf '%s\n' "$row"
}

# Exit 1 unless a repo row has a folder that exists; the message says which case it is.
sb_spec_need_folder() {
  case "$3" in
    ok) ;;
    missing) sb_die 1 "the folder of $1 is missing: $(sb_path_out "$2")" ;;
    *) sb_die 1 "no location is recorded for $1: set repos_root or repo_paths in $SB_P_PATH/claude/profile.md" ;;
  esac
}

# Resolve the spec of the task in SB_T_FILE. Sets SB_SP_DELIVERY, SB_SP_HOME, SB_SP_REPO (or "-"),
# SB_SP_DIR (absolute), SB_SP_SHOW (the folder as it is printed) and SB_SP_BJ (the story's
# build.json, in its task folder whatever its spec_home). Exits 1, with the reason, when the spec
# lives in a repo that cannot be reached.
sb_spec_resolve() {
  local sub="" subfile="" row name path state
  SB_SP_BJ="$(dirname "$SB_T_FILE")/build.json"
  sub="$(sb_fm_get "$SB_T_FILE" subproject 2>/dev/null)"
  if [ -n "$sub" ] && sb_sub_resolve "$sub"; then subfile="$SB_S_FILE"; fi
  SB_SP_DELIVERY="$(sb_spec_value delivery "$SB_T_FILE" "$subfile" "$SB_P_PROFILE")"
  SB_SP_HOME="$(sb_spec_value spec_home "$subfile" "$SB_P_PROFILE")"
  # The story's repo: its subproject's first, else the project's first, as repo lists them.
  SB_SP_REPO=""
  [ -z "$subfile" ] || SB_SP_REPO="$(sb_fm_list "$subfile" repos 2>/dev/null | head -1)"
  [ -n "$SB_SP_REPO" ] || SB_SP_REPO="$(sb_repo_rows_at "$SB_P_PATH" | head -1 | cut -f1)"
  if [ "$SB_SP_HOME" = "vault" ]; then
    SB_SP_DIR="$(dirname "$SB_T_FILE")/spec"
    SB_SP_SHOW="$(sb_rel "$SB_SP_DIR")"
    [ -n "$SB_SP_REPO" ] || SB_SP_REPO="-"
    return 0
  fi
  SB_SP_ERR=""
  if [ -z "$SB_SP_REPO" ]; then
    SB_SP_ERR="$SB_P_NAME lists no repo for the spec: add one to repos in $SB_P_PATH/claude/profile.md"
  elif ! row="$(sb_spec_repo_row "$SB_SP_REPO")"; then
    SB_SP_ERR="$SB_SP_REPO is not in repos of $SB_P_NAME"
  else
    IFS=$'\t' read -r name path state <<EOF
$row
EOF
    case "$state" in
      ok) ;;
      missing) SB_SP_ERR="the folder of $name is missing: $(sb_path_out "$path")" ;;
      *) SB_SP_ERR="no location is recorded for $name: set repos_root or repo_paths in $SB_P_PATH/claude/profile.md" ;;
    esac
  fi
  if [ -n "$SB_SP_ERR" ]; then
    # With SB_SP_SOFT=1 the caller prints what holds first, then exits with the reason.
    [ "${SB_SP_SOFT:-0}" = "1" ] || sb_die 1 "$SB_SP_ERR"
    [ -n "$SB_SP_REPO" ] || SB_SP_REPO="-"
    SB_SP_DIR=""
    SB_SP_SHOW="-"
    return 0
  fi
  SB_SP_REPO="$name"
  SB_SP_DIR="$path/spec/$SB_T_ID"
  SB_SP_SHOW="$(sb_path_out "$SB_SP_DIR")"
}

# Write one spec file unless it exists; print its path when created.
sb_spec_write() {
  local part="$1" label="$2" dest="$SB_SP_DIR/$1.md" show="$SB_SP_SHOW/$1.md" title text
  if [ -e "$dest" ]; then
    printf 'exists: %s\n' "$show" >&2
    return 0
  fi
  title="$(sb_fm_get "$SB_T_FILE" title 2>/dev/null)"
  [ -n "$title" ] || title="$SB_T_ID"
  text="$(sb_fill_text "spec-$part.md.tmpl" "ID=$SB_T_ID" "TITLE=$title")" || exit 2
  case "$text" in *'{{'*) sb_die 5 "a placeholder was left unfilled in spec-$part.md.tmpl, or the title contains {{" ;; esac
  mkdir -p "$SB_SP_DIR" || sb_die 1 "cannot create $SB_SP_SHOW"
  if [ "$SB_SP_HOME" = "vault" ]; then
    printf -- '---\naliases:\n  - "%s %s"\ntype: spec\ntags:\n  - type/spec\n---\n\n> Up: [[%s|%s]]\n\n%s\n' \
      "$SB_T_ID" "$label" "${SB_T_REL%.md}" "$SB_T_ID" "$text" >"$dest" || sb_die 1 "cannot write $show"
  else
    printf '%s\n' "$text" >"$dest" || sb_die 1 "cannot write $show"
  fi
  printf '%s\n' "$show"
}

# Set SB_SP_FILE to the absolute path of the spec file of a part, or exit 1 when it is missing.
# Called in the main shell, never in a command substitution, so that the exit stops the command.
sb_spec_need_file() {
  SB_SP_FILE="$SB_SP_DIR/$1.md"
  [ -f "$SB_SP_FILE" ] || sb_die 1 "no $1.md at $SB_SP_SHOW: run second-brain spec new $SB_T_ID"
}

# Read a tasks.md, or stdin with no file; print one TSV row per task item: id, todo or done, title ("-" when none).
sb_spec_task_rows() {
  LC_ALL=C awk "$(sb_awk_lib)"'
    { sub(/\r$/, "") }
    /^(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^- \[[ xX]\] T[0-9]+([ \t:]|$)/ {
      st = (substr($0, 4, 1) == " " ? "todo" : "done")
      rest = substr($0, 7); id = rest; sub(/[ \t:].*$/, "", id)
      t = substr(rest, length(id) + 1); sub(/^[ \t]*[-:]?[ \t]*/, "", t); gsub(/\t/, " ", t); t = trim(t)
      print id "\t" st "\t" (t == "" ? "-" : t)
    }' "$@"
}

# Tick a task item of a tasks.md, keeping the file's line endings; fenced code is not read.
# Returns 1 when no item has the id, 4 when two items have it, 6 when it is ticked already and 2
# when the file cannot be written.
sb_spec_tick_file() {
  local file="$1" tmp rc=0
  tmp="$(mktemp "${TMPDIR:-/tmp}/sb-tick.XXXXXX")" || return 2
  LC_ALL=C SB_ID="$2" awk '
    BEGIN { want = toupper(ENVIRON["SB_ID"]); hit = 0 }
    {
      raw = $0; line = raw; sub(/\r$/, "", line)
      if (line ~ /^[ \t]*(```|~~~)/) fence = !fence
      else if (!fence && line ~ /^- \[[ xX]\] T[0-9]+([ \t:]|$)/) {
        id = substr(line, 7); sub(/[ \t:].*$/, "", id)
        if (toupper(id) == want && hit++ == 0) {
          if (substr(line, 4, 1) != " ") was = 1
          else raw = "- [x]" substr(raw, 6)
        }
      }
      print raw
    }
    END { exit(!hit ? 1 : (hit > 1 ? 4 : (was ? 6 : 0))) }' "$file" >"$tmp" || rc=$?
  if [ "$rc" -eq 0 ]; then cat "$tmp" >"$file" || rc=2; fi
  rm -f "$tmp"
  return "$rc"
}

# Print the item of one task of a tasks.md, as written: its line and the lines under it, to the next
# line at the start of a line outside fenced code. Returns 1 when no item has the id, 4 when two do.
sb_spec_task_item() {
  LC_ALL=C SB_ID="$2" awk "$(sb_awk_lib)"'
    BEGIN { want = toupper(ENVIRON["SB_ID"]) }
    { sub(/\r$/, "") }
    /^[ \t]*(```|~~~)/ { fence = !fence; if (on) print; next }
    on && !fence && /^[^ \t]/ { on = 0 }
    !fence && /^- \[[ xX]\] T[0-9]+([ \t:]|$)/ {
      id = substr($0, 7); sub(/[ \t:].*$/, "", id)
      if (toupper(id) == want) { found++; if (found == 1) on = 1 }
    }
    on { print }
    END { exit(!found ? 1 : (found > 1 ? 4 : 0)) }' "$1"
}

# Print the value of one field line of a task item on stdin: "  - <Field>: <value>".
sb_spec_field() {
  LC_ALL=C SB_F="$1" awk "$(sb_awk_lib)"'
    BEGIN { f = tolower(ENVIRON["SB_F"]) ":" }
    {
      line = $0; sub(/^[ \t]+-[ \t]+/, "", line)
      if ($0 ~ /^[ \t]+-[ \t]/ && tolower(substr(line, 1, length(f))) == f) { print trim(substr(line, length(f) + 1)); exit }
    }'
}

# Print the level-2 sections of a file that the comma-separated names pick, each as "### <heading>",
# a blank line and its body. Mode "id" matches a heading whose first word is the name (R1 in
# "## R1 - Login"), mode "name" the whole heading; both without letter case. Exits 1 with
# "none<TAB>name" or "two<TAB>name" on stderr for the first name with no section, or with two.
sb_spec_sections() {
  LC_ALL=C SB_MODE="$2" SB_NAMES="$3" awk "$(sb_awk_lib)"'
    function key(h,   k) { k = h; if (ENVIRON["SB_MODE"] == "id") sub(/[ \t].*$/, "", k); return tolower(trim(k)) }
    { sub(/\r$/, "") }
    /^(```|~~~)/ { fence = !fence }
    !fence && /^## / { h = $0; sub(/^##[ \t]+/, "", h); sub(/[ \t#]+$/, "", h); cur = key(h); if (!(cur in head)) { head[cur] = h; body[cur] = "" } else { dup[cur] = 1; cur = "" }; next }
    !fence && /^# / { cur = ""; next }
    cur != "" { body[cur] = body[cur] $0 "\n" }
    END {
      n = split(ENVIRON["SB_NAMES"], nm, ",")
      for (i = 1; i <= n; i++) {
        k = tolower(trim(nm[i])); if (k == "") continue
        if (!(k in head)) { print "none\t" trim(nm[i]) > "/dev/stderr"; exit 1 }
        if (k in dup) { print "two\t" trim(nm[i]) > "/dev/stderr"; exit 1 }
        b = body[k]; sub(/^\n+/, "", b); sub(/\n+$/, "", b)
        printf "### %s\n\n%s\n\n", head[k], b
      }
    }' "$1"
}

# Read a task's README and its requirements.md; print each break in the trace between them once,
# one per line: AC<n> for each criterion no requirement serves, in order, then the id of each
# requirement with no good item on its "- Serves:" lines or with an item that is not good, in file
# order. A criterion is a "- [ ]", "- [x]" or "- [X]" line under the README's "## Acceptance
# criteria", numbered from 1; a good item is AC<n>, in any letter case, for a criterion the story
# has. Frontmatter of the README, fenced code, a CR at a line's end and a BOM are not read.
# Usage: sb_spec_trace <readme> <requirements>
sb_spec_trace() {
  LC_ALL=C awk "$(sb_awk_lib)"'
    BEGIN { nac = 0; nr = 0 }
    FNR == 1 { readme = (FILENAME == ARGV[1]); fence = 0; fm = 0; on = 0; cur = 0; sub(/^\357\273\277/, "") }
    { sub(/\r$/, "") }
    readme && FNR == 1 && $0 == "---" { fm = 1; next }
    fm { if ($0 == "---") fm = 0; next }
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    readme {
      if (/^## /) { h = $0; sub(/^##[ \t]+/, "", h); sub(/[ \t#]+$/, "", h); on = (tolower(h) == "acceptance criteria") }
      else if (/^# /) on = 0
      else if (on && /^- \[[ xX]\]( |$)/) nac++
      next
    }
    /^## / {
      h = $0; sub(/^##[ \t]+/, "", h); sub(/[ \t#]+$/, "", h); sub(/[ \t].*$/, "", h); cur = 0
      if (h ~ /^[Rr][0-9]+$/) { cur = ++nr; rid[nr] = h }
      next
    }
    /^# / { cur = 0; next }
    cur && tolower(substr($0, 1, 9)) == "- serves:" {
      n = split(substr($0, 10), it, ",")
      for (i = 1; i <= n; i++) {
        v = trim(it[i])
        if (v == "") continue
        if (v ~ /^[Aa][Cc][1-9][0-9]*$/ && substr(v, 3) + 0 <= nac) { good[cur] = 1; served[substr(v, 3) + 0] = 1 }
        else bad[cur] = 1
      }
    }
    END {
      for (i = 1; i <= nac; i++) if (!(i in served)) print "AC" i
      for (i = 1; i <= nr; i++) {
        if ((i in good) && !(i in bad)) continue
        k = tolower(rid[i])
        if (!(k in said)) { said[k] = 1; print rid[i] }
      }
    }' "$1" "$2"
}

# Print the "## Uses" body of a task's packet: for each task its "- Uses:" line names, in that
# order, "### <task> - <title>" and that item's "- Provides:" lines, as written. Exits 1 when a task
# it names is not in tasks.md, is not an earlier task, or has no "- Provides:" line.
# Usage: sb_spec_uses <tasks.md> <task> <the Uses value>
sb_spec_uses() {
  local tfile="$1" task="$2" rows pos u hit upos uid uti item prov
  rows="$(sb_spec_task_rows "$tfile")"
  pos="$(printf '%s\n' "$rows" | SB_ID="$task" awk -F'\t' 'toupper($1) == toupper(ENVIRON["SB_ID"]) { print NR; exit }')"
  printf '%s\n' "$3" | tr ',' '\n' | while IFS= read -r u; do
    u="$(printf '%s' "$u" | tr -d ' \t\r')"
    [ -n "$u" ] || continue
    hit="$(printf '%s\n' "$rows" | SB_ID="$u" awk -F'\t' 'toupper($1) == toupper(ENVIRON["SB_ID"]) { print NR "\t" $1 "\t" $3; exit }')"
    [ -n "$hit" ] || sb_die 1 "$task uses $u, which $SB_SP_SHOW/tasks.md has no item for"
    IFS=$'\t' read -r upos uid uti <<EOF
$hit
EOF
    [ "$upos" -lt "$pos" ] || sb_die 1 "$task uses $uid, which is not an earlier task in $SB_SP_SHOW/tasks.md"
    item="$(sb_spec_task_item "$tfile" "$uid")" || sb_die 1 "two items in $SB_SP_SHOW/tasks.md have the id $uid: give each task its own id"
    prov="$(printf '%s\n' "$item" | LC_ALL=C awk '{ sub(/\r$/, "") } /^[ \t]+-[ \t]+[Pp][Rr][Oo][Vv][Ii][Dd][Ee][Ss]:/ { sub(/^[ \t]+/, ""); print }')"
    [ -n "$prov" ] || sb_die 1 "$task uses $uid, which has no - Provides: line in $SB_SP_SHOW/tasks.md"
    printf '### %s - %s\n\n%s\n\n' "$uid" "$uti" "$prov"
  done
}

# Print the context packet of one task: what the implementer is given, and nothing else.
sb_spec_packet() {
  local task="$1" tfile rfile dfile item reqs design uses title branch row name path state out miss rc
  local vrow vname vhome vfile vshow vstate vr usesout="" binfo commits issues c clist="" diffline f
  sb_spec_need_file tasks
  tfile="$SB_SP_FILE"
  sb_spec_need_file requirements
  rfile="$SB_SP_FILE"
  sb_spec_need_file design
  dfile="$SB_SP_FILE"
  rc=0
  item="$(sb_spec_task_item "$tfile" "$task")" || rc=$?
  case "$rc" in
    0) ;;
    4) sb_die 1 "two items in $SB_SP_SHOW/tasks.md have the id $task: give each task its own id" ;;
    *) sb_die 1 "no task $task in $SB_SP_SHOW/tasks.md" ;;
  esac
  task="$(printf '%s\n' "$item" | sb_spec_task_rows | cut -f1)"
  title="$(printf '%s\n' "$item" | sb_spec_task_rows | cut -f3)"
  reqs="$(printf '%s\n' "$item" | sb_spec_field Requirements)"
  design="$(printf '%s\n' "$item" | sb_spec_field Design)"
  uses="$(printf '%s\n' "$item" | sb_spec_field Uses)"
  case "$(printf '%s' "$reqs" | tr '[:upper:]' '[:lower:]')" in
    '' | '-' | none | n/a | '<'*) sb_die 1 "$task names no requirement in $SB_SP_SHOW/tasks.md" ;;
  esac
  for f in "$reqs" "$design" "$uses"; do
    case "$f" in *,) sb_die 1 "a field of $task ends in a comma: write each field of a task on one line" ;; esac
  done
  case "$(printf '%s' "$design" | tr '[:upper:]' '[:lower:]')" in '-' | none | n/a | '<'*) design="" ;; esac
  case "$(printf '%s' "$uses" | tr '[:upper:]' '[:lower:]')" in '-' | none | n/a | '<'*) uses="" ;; esac
  if [ -n "$uses" ]; then usesout="$(sb_spec_uses "$tfile" "$task" "$uses")" || exit $?; fi
  # The task's commits and issues in build.json; the diff of those commits goes in a temp file.
  binfo="$(sb_spec_build_run SB_MODE=task SB_TASK="$task")" || { rc=$?; sb_spec_build_fail "$rc"; }
  commits="$(printf '%s\n' "$binfo" | sed -n '1s/^commits: //p')"
  issues="$(printf '%s\n' "$binfo" | sed '1d')"
  [ "$SB_SP_REPO" != "-" ] || sb_die 1 "$SB_P_NAME lists no repo to build $task in: add one to repos in $SB_P_PATH/claude/profile.md"
  row="$(sb_spec_repo_row "$SB_SP_REPO")" || sb_die 1 "$SB_SP_REPO is not in repos of $SB_P_NAME"
  IFS=$'\t' read -r name path state <<EOF
$row
EOF
  sb_spec_need_folder "$name" "$path" "$state"
  branch="$(sb_fm_get "$SB_T_FILE" branch 2>/dev/null)"
  vrow="$(sb_val_rows "$name")"
  IFS=$'\t' read -r vname vhome vfile vshow vstate vr <<EOF
$vrow
EOF
  diffline="none (no commit)"
  for c in $(printf '%s' "$commits" | tr ',' ' '); do
    case "$c" in *[!0-9a-fA-F]*) ;; *) clist="$clist $c" ;; esac
  done
  if [ -n "$clist" ]; then
    f="$(mktemp "${TMPDIR:-/tmp}/sb-diff-$SB_T_ID-$task.XXXXXX")" || sb_die 1 "cannot write a temp file"
    diffline="none (git show failed)"
    for c in $clist; do
      if git -C "$path" show --no-color --no-ext-diff "$c" >>"$f" 2>/dev/null; then
        diffline="$(sb_path_out "$f")"
      else
        sb_note "git show $c failed in $name"
      fi
    done
    [ "$diffline" != "none (git show failed)" ] || rm -f "$f"
  fi
  out="$(mktemp "${TMPDIR:-/tmp}/sb-packet.XXXXXX")" || sb_die 1 "cannot write a temp file"
  {
    printf 'story: %s\ntask: %s\ntitle: %s\nrepo: %s\nrepo_path: %s\nbranch: %s\n' \
      "$SB_T_ID" "$task" "$title" "$name" "$(sb_path_out "$path")" "${branch:--}"
    if [ "$vstate" = "ok" ]; then printf 'validation: %s\n' "$vshow"; else printf 'validation: none (%s)\n' "${vstate:-unknown}"; fi
    printf 'commits: %s\ndiff: %s\n' "${commits:--}" "$diffline"
    printf '\n## Task\n\n%s\n\n## Requirements\n\n' "$item"
  } >"$out"
  if ! miss="$(sb_spec_sections "$rfile" id "$reqs" 2>&1 >>"$out")"; then
    rm -f "$out"
    case "$miss" in
      two*) sb_die 1 "$SB_SP_SHOW/requirements.md has two sections for ${miss#*$'\t'}: give each requirement its own id" ;;
      *) sb_die 1 "$task names ${miss#*$'\t'}, which $SB_SP_SHOW/requirements.md has no section for" ;;
    esac
  fi
  if [ -n "$design" ]; then
    printf '## Design\n\n' >>"$out"
    if ! miss="$(sb_spec_sections "$dfile" name "$design" 2>&1 >>"$out")"; then
      rm -f "$out"
      case "$miss" in
        two*) sb_die 1 "$SB_SP_SHOW/design.md has two sections named ${miss#*$'\t'}: give each its own heading" ;;
        *) sb_die 1 "$task names the design section ${miss#*$'\t'}, which $SB_SP_SHOW/design.md does not have" ;;
      esac
    fi
  fi
  if [ -n "$usesout" ]; then printf '## Uses\n\n%s\n\n' "$usesout" >>"$out"; fi
  if [ -n "$issues" ]; then printf '## Issues\n\n%s\n\n' "$issues" >>"$out"; fi
  if [ "$vstate" = "ok" ]; then
    { printf '## Validation\n\n'; sb_section "$vfile" "$name"; } >>"$out"
  fi
  cat "$out"
  rm -f "$out"
}

# Write the spec links into a spec story's README: design.md as the first line of
# "## Approach / Key decisions", tasks.md as the first line of "## Changes" and "## Verification".
# A section that holds only "None yet." or the task template's text gets the link alone; any other
# keeps its text under the link; one with its link is left alone. Line endings, the final newline,
# frontmatter and fenced code are kept. Prints "linked: <heading>" per change, or "no change".
sb_spec_link() {
  local dl tl tmpl tmp out miss nofinal=0 rc=0 line
  if [ "$SB_SP_DELIVERY" != "spec" ]; then
    printf 'no change: %s is not built from a spec (delivery: %s)\n' "$SB_T_ID" "$SB_SP_DELIVERY"
    return 0
  fi
  [ -z "${SB_SP_ERR:-}" ] || sb_die 1 "$SB_SP_ERR"
  sb_spec_need_file design
  sb_spec_need_file tasks
  if [ "$SB_SP_HOME" = "vault" ]; then
    dl="See [[$SB_SP_SHOW/design|$SB_T_ID Design]]."
    tl="See [[$SB_SP_SHOW/tasks|$SB_T_ID Tasks]]."
  else
    dl="See \`spec/$SB_T_ID/design.md\` in the \`$SB_SP_REPO\` repo."
    tl="See \`spec/$SB_T_ID/tasks.md\` in the \`$SB_SP_REPO\` repo."
  fi
  tmpl="$(sb_plugin_root)/templates/task-readme.md.tmpl"
  [ -n "$(tail -c 1 "$SB_T_FILE")" ] && nofinal=1
  tmp="$(mktemp "${TMPDIR:-/tmp}/sb-link.XXXXXX")" || sb_die 1 "cannot write a temp file"
  out="$(SB_OUT="$tmp" SB_DL="$dl" SB_TL="$tl" SB_NOFINAL="$nofinal" \
    SB_T1="$(sb_section "$tmpl" "Approach / Key decisions" 2>/dev/null)" \
    SB_T2="$(sb_section "$tmpl" "Changes" 2>/dev/null)" \
    SB_T3="$(sb_section "$tmpl" "Verification" 2>/dev/null)" LC_ALL=C awk "$(sb_awk_lib)"'
    function norm(s,   n, i, a, o) {
      n = split(s, a, "\n"); o = ""
      for (i = 1; i <= n; i++) { sub(/\r$/, "", a[i]); a[i] = trim(a[i]); if (a[i] != "") o = o (o == "" ? "" : "\n") a[i] }
      return o
    }
    BEGIN {
      want["approach / key decisions"] = 1; want["changes"] = 2; want["verification"] = 3
      name[1] = "Approach / Key decisions"; name[2] = "Changes"; name[3] = "Verification"
      link[1] = ENVIRON["SB_DL"]; link[2] = ENVIRON["SB_TL"]; link[3] = ENVIRON["SB_TL"]
      tm[1] = norm(ENVIRON["SB_T1"]); tm[2] = norm(ENVIRON["SB_T2"]); tm[3] = norm(ENVIRON["SB_T3"])
    }
    {
      if (NR == 1) eol = ($0 ~ /\r$/ ? "\r" : "")
      line[NR] = $0; t = $0; sub(/\r$/, "", t); if (NR == 1) sub(/^\357\273\277/, "", t)
      txt[NR] = t
    }
    END {
      n = NR; fm = 0; fence = 0; cur = 0
      for (i = 1; i <= n; i++) {
        t = txt[i]; kind[i] = ""
        if (i == 1 && t == "---") { fm = 1; continue }
        if (fm) { if (t == "---") fm = 0; continue }
        if (t ~ /^[ \t]*(```|~~~)/) { fence = !fence; sec[i] = cur; continue }
        if (!fence && t ~ /^##? /) {
          cur = 0
          if (t ~ /^## /) { h = t; sub(/^##[ \t]+/, "", h); sub(/[ \t#]+$/, "", h); h = tolower(h); if ((h in want) && !(want[h] in at)) { cur = want[h]; at[cur] = i } }
          continue
        }
        sec[i] = cur
      }
      for (k = 1; k <= 3; k++) {
        if (!(k in at)) { print "missing\t" name[k]; continue }
        body = ""; has = 0
        for (i = at[k] + 1; i <= n && sec[i] == k; i++) { body = body txt[i] "\n"; if (trim(txt[i]) == link[k]) has = 1 }
        last[k] = i - 1
        if (has) continue
        b = norm(body)
        mode[k] = ((b == "None yet." || (tm[k] != "" && b == tm[k])) ? "replace" : "insert")
        print "linked\t" name[k]
      }
      o = ENVIRON["SB_OUT"]
      for (i = 1; i <= n; i++) {
        k = 0
        for (j = 1; j <= 3; j++) if ((j in mode) && at[j] == i) k = j
        if (!k) { if (!skip[i]) out_line(line[i], i == n); continue }
        out_line(line[i], 0)
        if (mode[k] == "replace") {
          out_line(eol, 0); out_line(link[k] eol, 0); out_line(eol, last[k] == n)
          for (m = i + 1; m <= last[k]; m++) skip[m] = 1
          if (last[k] == n) { done_last = 1 }
        } else {
          if (i < n && trim(txt[i + 1]) == "") { out_line(line[i + 1], 0); skip[i + 1] = 1 }
          else out_line(eol, 0)
          out_line(link[k] eol, 0); out_line(eol, 0)
        }
      }
    }
    function out_line(s, islast) {
      if (islast && ENVIRON["SB_NOFINAL"] == "1") printf "%s", s > o
      else print s > o
    }' "$SB_T_FILE")" || rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -f "$tmp"
    sb_die 1 "cannot read $SB_T_REL"
  fi
  miss=0
  while IFS=$'\t' read -r rc line; do
    case "$rc" in
      missing) printf 'note: no ## %s in %s\n' "$line" "$SB_T_REL" >&2 ;;
      linked) miss=1; printf 'linked: %s\n' "$line" ;;
    esac
  done <<EOF
$out
EOF
  if [ "$miss" -eq 1 ]; then
    cat "$tmp" >"$SB_T_FILE" || { rm -f "$tmp"; sb_die 1 "cannot write $SB_T_REL"; }
  else
    printf 'no change\n'
  fi
  rm -f "$tmp"
}

# Print the awk function build_row(t), which reads a "## Build" row into B_ID, B_ST, B_CM (the
# commits as written, "-" when none) and B_TI. It reads left to right: a title may hold " - ", and
# a row with no commit may read "commits -" or "commits " before the title.
sb_spec_row_awk() {
  printf '%s\n' '
function build_row(t,   r, p) {
  r = substr(t, 3); p = index(r, " - "); B_ID = substr(r, 1, p - 1); r = substr(r, p + 3)
  p = index(r, " - "); B_ST = (p ? substr(r, 1, p - 1) : r); r = (p ? substr(r, p) : "")
  B_CM = "-"
  if (sub(/^ - commits/, "", r)) {
    if (r ~ /^ +`/) {
      p = index(r, " - "); B_CM = trim(p ? substr(r, 1, p - 1) : r); r = (p ? substr(r, p) : "")
    } else if (r ~ /^ -( |$)/) r = substr(r, 3)
  }
  if (!sub(/^ +- /, "", r)) r = ""
  B_TI = r
}'
}

# Read TSV rows on stdin; print them as a JSON array of objects, one key per column, in order.
# Usage: sb_spec_json_rows <key>...
sb_spec_json_rows() {
  LC_ALL=C SB_KEYS="$*" awk -F'\t' "$(sb_awk_lib)"'
    BEGIN { nk = split(ENVIRON["SB_KEYS"], k, " "); printf "[" }
    $0 == "" { next }
    {
      printf "%s\n  {", (rows++ ? "," : "")
      for (i = 1; i <= nk; i++) printf "%s%s: %s", (i > 1 ? ", " : ""), jstr(k[i]), jstr($i)
      printf "}"
    }
    END { print (rows ? "\n]" : "]") }'
}

# Print the awk functions that read JSON. jp_add(line) adds one line of the text to JC[1..JL], one
# byte each, and jp_parse() reads it: J[path] gets each scalar, JT[path] its type (o, a, s or l for
# a number, true, false or null) and JN[path] an array's length. A path is the keys and the array
# indexes, from 1, joined by SUBSEP. jp_parse returns 0 when the text is not one JSON value, blank
# text included. Each byte is read once: a substr per byte of the whole text costs its length on
# some awks.
sb_json_awk() {
  printf '%s\n' '
function jp_add(s,   n, i, ch) {
  if (JP_SPLIT == "") JP_SPLIT = (split("ab", ch, "") == 2 ? 1 : 0)
  if (JP_SPLIT) { n = split(s, ch, ""); for (i = 1; i <= n; i++) JC[++JL] = ch[i] }
  else { n = length(s); for (i = 1; i <= n; i++) JC[++JL] = substr(s, i, 1) }
  JC[++JL] = "\n"
}
function jp_parse() {
  JI = 1; JERR = 0
  jp_ws()
  if (JI > JL) return 0
  if (!jp_val("")) return 0
  jp_ws()
  return JI > JL
}
function jp_ws(   c) {
  while (JI <= JL) { c = JC[JI]; if (c != " " && c != "\t" && c != "\n" && c != "\r") break; JI++ }
}
function jp_key(p, k) { return (p == "" ? k : p SUBSEP k) }
function jp_take(n,   o, i) {
  o = ""
  for (i = 0; i < n && JI + i <= JL; i++) o = o JC[JI + i]
  return o
}
function jp_val(p,   c, t) {
  jp_ws()
  if (JI > JL) return 0
  c = JC[JI]
  if (c == "{") return jp_obj(p)
  if (c == "[") return jp_arr(p)
  if (c == "\"") { JT[p] = "s"; J[p] = jp_str(); return !JERR }
  t = ""
  while (JI <= JL && index("+-.0123456789Eabcdefilnrstu", JC[JI])) t = t JC[JI++]
  if (t !~ /^(-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?|true|false|null)$/) return 0
  JT[p] = "l"; J[p] = t
  return 1
}
function jp_obj(p,   k, c) {
  JI++; JT[p] = "o"; jp_ws()
  if (JC[JI] == "}") { JI++; return 1 }
  while (1) {
    jp_ws()
    if (JI > JL || JC[JI] != "\"") return 0
    k = jp_str()
    if (JERR) return 0
    jp_ws()
    if (JI > JL || JC[JI] != ":") return 0
    JI++
    if (!jp_val(jp_key(p, k))) return 0
    jp_ws()
    if (JI > JL) return 0
    c = JC[JI++]
    if (c == "}") return 1
    if (c != ",") return 0
  }
}
function jp_arr(p,   n, c) {
  JI++; JT[p] = "a"; JN[p] = 0; n = 0; jp_ws()
  if (JC[JI] == "]") { JI++; return 1 }
  while (1) {
    if (!jp_val(jp_key(p, ++n))) return 0
    JN[p] = n
    jp_ws()
    if (JI > JL) return 0
    c = JC[JI++]
    if (c == "]") return 1
    if (c != ",") return 0
  }
}
function jp_str(   o, c, e, cp, lo) {
  JI++; o = ""
  while (JI <= JL) {
    c = JC[JI]
    if (c == "\"") { JI++; return o }
    if (c != "\\") { o = o c; JI++; continue }
    e = JC[JI + 1]; JI += 2
    if (e == "n") o = o "\n"
    else if (e == "t") o = o "\t"
    else if (e == "r") o = o "\r"
    else if (e == "b") o = o "\010"
    else if (e == "f") o = o "\014"
    else if (e == "u") {
      cp = jp_hex(jp_take(4)); JI += 4
      if (cp < 0) { JERR = 1; return o }
      if (cp >= 55296 && cp < 56320 && JC[JI] == "\\" && JC[JI + 1] == "u") {
        JI += 2; lo = jp_hex(jp_take(4))
        if (lo >= 56320 && lo < 57344) { cp = 65536 + (cp - 55296) * 1024 + (lo - 56320); JI += 4 }
        else JI -= 2
      }
      o = o jp_utf8(cp)
    }
    else o = o e
  }
  JERR = 1
  return o
}
function jp_hex(h,   i, v, d) {
  if (length(h) != 4) return -1
  v = 0; h = tolower(h)
  for (i = 1; i <= 4; i++) { d = index("0123456789abcdef", substr(h, i, 1)); if (!d) return -1; v = v * 16 + d - 1 }
  return v
}
function jp_utf8(cp) {
  if (cp < 128) return sprintf("%c", cp)
  if (cp < 2048) return sprintf("%c%c", 192 + int(cp / 64), 128 + cp % 64)
  if (cp < 65536) return sprintf("%c%c%c", 224 + int(cp / 4096), 128 + int(cp / 64) % 64, 128 + cp % 64)
  return sprintf("%c%c%c%c", 240 + int(cp / 262144), 128 + int(cp / 4096) % 64, 128 + int(cp / 64) % 64, 128 + cp % 64)
}'
}

# Run the build program on the story in SB_T_FILE. It reads build.json (SB_SP_BJ, when it is
# there), the README for a "## Build" section that versions before 0.7.0 wrote, and the rows of
# tasks.md in SB_ROWS. SB_MODE says what it does:
# - text, json: print the tasks as spec status prints them; nothing (or []) with no build data.
# - task: print "commits: <hashes or ->" for the task SB_TASK, then its issue lines.
# - write: apply SB_OP (status or issue) to SB_TASK, write the JSON to SB_OUT and, when the README
#   had a "## Build" section, the README without it to SB_OUTMD, and print "moved".
# Exits 3 when write names no task it knows, 4 when build.json is not a JSON object with a tasks
# array, blank text included.
sb_spec_build_awk() {
  printf '%s\n' "$(sb_awk_lib)$(sb_spec_row_awk)$(sb_json_awk)" '
function dash(s) { return (s == "" ? "-" : s) }
function addtask(id, ti,   k) {
  k = toupper(id)
  if (k in idx) return idx[k]
  nt++; tid[nt] = id; tti[nt] = ti; tb[nt] = "todo"; tr[nt] = "-"; ncm[nt] = 0; nis[nt] = 0; nh[nt] = 0
  idx[k] = nt
  return nt
}
function addcommit(r, c,   j) {
  for (j = 1; j <= ncm[r]; j++) if (cm[r, j] == c) return
  cm[r, ++ncm[r]] = c
}
function addissue(r, at, se, tx, fx,   j) {
  j = ++nis[r]; ia[r, j] = at; ise[r, j] = se; itx[r, j] = tx; ifx[r, j] = fx
}
function addhist(r, at, se, fd, st,   j) {
  j = ++nh[r]; ha[r, j] = at; hse[r, j] = se; hfd[r, j] = fd; hst[r, j] = st
}
function commits_text(r,   j, s) {
  s = ""
  for (j = 1; j <= ncm[r]; j++) s = s (j > 1 ? ", " : "") cm[r, j]
  return dash(s)
}
function fold(s) { gsub(/\r\n|\n|\r/, " ", s); return s }
function issue_line(r, j) { return "Issue " substr(dash(ia[r, j]), 1, 10) ": " fold(itx[r, j]) " Fix: " fold(ifx[r, j]) }
function md_line(s, islast) {
  if (islast && ENVIRON["SB_NOFINAL"] == "1") printf "%s", s > MD
  else print s > MD
}
function write_json(   r, j, s) {
  printf "{\n  \"story\": %s,\n  \"tasks\": [", jstr(ENVIRON["SB_STORY"]) > JO
  for (r = 1; r <= nt; r++) {
    printf "%s\n    {\n      \"id\": %s,\n      \"title\": %s,\n", (r > 1 ? "," : ""), jstr(tid[r]), jstr(dash(tti[r])) > JO
    printf "      \"build\": %s,\n      \"review\": %s,\n", jstr(tb[r]), jstr(tr[r]) > JO
    s = ""
    for (j = 1; j <= ncm[r]; j++) s = s (j > 1 ? ", " : "") jstr(cm[r, j])
    printf "      \"commits\": [%s],\n      \"issues\": [", s > JO
    for (j = 1; j <= nis[r]; j++)
      printf "%s\n        {\"at\": %s, \"session\": %s, \"issue\": %s, \"fix\": %s}", (j > 1 ? "," : ""), jstr(dash(ia[r, j])), jstr(dash(ise[r, j])), jstr(itx[r, j]), jstr(ifx[r, j]) > JO
    printf "%s],\n      \"history\": [", (nis[r] ? "\n      " : "") > JO
    for (j = 1; j <= nh[r]; j++)
      printf "%s\n        {\"at\": %s, \"session\": %s, \"field\": %s, \"state\": %s}", (j > 1 ? "," : ""), jstr(dash(ha[r, j])), jstr(dash(hse[r, j])), jstr(hfd[r, j]), jstr(hst[r, j]) > JO
    printf "%s]\n    }", (nh[r] ? "\n      " : "") > JO
  }
  printf "%s]\n}\n", (nt ? "\n  " : "") > JO
}
ENVIRON["SB_JF"] == "1" && FILENAME == ARGV[1] { jp_add($0); next }
{
  nr++
  line[nr] = $0; t = $0; sub(/\r$/, "", t); if (nr == 1) sub(/^\357\273\277/, "", t); txt[nr] = t
}
END {
  MD = ENVIRON["SB_OUTMD"]; JO = ENVIRON["SB_OUT"]; mode = ENVIRON["SB_MODE"]
  # The README "## Build" section, outside frontmatter and fenced code.
  n = nr; fm = 0; fmend = 0; fence = 0; at = 0; last = 0
  for (i = 1; i <= n; i++) {
    t = txt[i]
    if (i == 1 && t == "---") { fm = 1; continue }
    if (fm) { if (t == "---") { fm = 0; fmend = i }; continue }
    if (t ~ /^[ \t]*(```|~~~)/) { fence = !fence; continue }
    if (!fence && t ~ /^##? /) {
      if (at && !last) last = i - 1
      h = tolower(t); sub(/[ \t#]+$/, "", h)
      if (!at && h == "## build") at = i
    }
  }
  if (at && !last) last = n
  nold = 0; cur = 0
  if (at) for (i = at + 1; i <= last; i++) {
    t = txt[i]
    if (t ~ /^- T[0-9]+ - /) {
      build_row(t); nold++; oid[nold] = B_ID; ost[nold] = B_ST; ocm[nold] = B_CM; oti[nold] = B_TI; oni[nold] = 0; cur = nold
      continue
    }
    if (cur && t ~ /^[ \t]+- /) oiss[cur, ++oni[cur]] = trim(substr(t, index(t, "-") + 2))
  }
  # tasks.md first, in its order; a ticked task starts as built and passed.
  nrw = split(ENVIRON["SB_ROWS"], rw, "\n")
  for (i = 1; i <= nrw; i++) {
    if (rw[i] == "") continue
    split(rw[i], c, "\t")
    r = addtask(c[1], c[3]); inmd[r] = 1
    if (c[2] == "done") { tb[r] = "built"; tr[r] = "passed" }
  }
  # Then build.json, whose tasks win.
  hasjson = 0
  if (ENVIRON["SB_JF"] == "1") {
    if (!jp_parse() || JT[""] != "o" || JT["tasks"] != "a") exit 4
    hasjson = 1
    for (q = 1; q <= JN["tasks"]; q++) {
      p = "tasks" SUBSEP q
      id = J[p SUBSEP "id"]
      if (id == "") continue
      r = addtask(id, J[p SUBSEP "title"]); fromjson[r] = 1
      if ((p SUBSEP "build") in J) tb[r] = J[p SUBSEP "build"]
      if ((p SUBSEP "review") in J) tr[r] = J[p SUBSEP "review"]
      a = p SUBSEP "commits"
      for (j = 1; j <= JN[a]; j++) addcommit(r, J[a SUBSEP j])
      a = p SUBSEP "issues"
      for (j = 1; j <= JN[a]; j++) { e = a SUBSEP j; addissue(r, J[e SUBSEP "at"], J[e SUBSEP "session"], J[e SUBSEP "issue"], J[e SUBSEP "fix"]) }
      a = p SUBSEP "history"
      for (j = 1; j <= JN[a]; j++) { e = a SUBSEP j; addhist(r, J[e SUBSEP "at"], J[e SUBSEP "session"], J[e SUBSEP "field"], J[e SUBSEP "state"]) }
    }
  }
  # Then the rows of a README "## Build" section, for each task build.json does not have.
  for (e = 1; e <= nold; e++) {
    k = toupper(oid[e])
    if ((k in idx) && fromjson[idx[k]]) continue
    r = addtask(oid[e], oti[e]); st = ost[e]; hascm = (ocm[e] != "-" && ocm[e] != "")
    if (st == "in-review" || st == "passed" || st == "failed") { tb[r] = "built"; tr[r] = st }
    else if (st == "blocked" && hascm) { tb[r] = "built"; tr[r] = "blocked" }
    else { tb[r] = st; tr[r] = "-" }
    if (hascm) {
      m = split(ocm[e], hh, ",")
      for (j = 1; j <= m; j++) { v = hh[j]; gsub(/`/, "", v); v = trim(v); if (v != "") addcommit(r, v) }
    }
    for (j = 1; j <= oni[e]; j++) {
      s = oiss[e, j]; d = "-"
      if (match(s, /^Issue [^:]*: /)) { d = substr(s, 7, RLENGTH - 8); s = substr(s, RLENGTH + 1) }
      p = index(s, " Fix: ")
      if (p) addissue(r, d, "-", substr(s, 1, p - 1), substr(s, p + 6))
      else addissue(r, d, "-", s, "-")
    }
  }
  hasdata = (hasjson || at)
  if (mode == "text") {
    if (!hasdata) exit 0
    for (r = 1; r <= nt; r++) {
      print tid[r] " - build: " tb[r] " - review: " tr[r] " - commits " commits_text(r) " - " fold(dash(tti[r]))
      for (j = 1; j <= nis[r]; j++) print "  - " issue_line(r, j)
    }
    exit 0
  }
  if (mode == "json") {
    printf "["
    if (hasdata) for (r = 1; r <= nt; r++) {
      s = ""
      for (j = 1; j <= ncm[r]; j++) s = s (j > 1 ? ", " : "") jstr(cm[r, j])
      l = ""
      for (j = 1; j <= nis[r]; j++) l = l (j > 1 ? ", " : "") jstr(issue_line(r, j))
      printf "%s\n  {\"id\": %s, \"build\": %s, \"review\": %s, ", (r > 1 ? "," : ""), jstr(tid[r]), jstr(tb[r]), jstr(tr[r])
      printf "\"commits\": [%s], \"title\": %s, \"issues\": [%s]}", s, jstr(fold(dash(tti[r]))), l
    }
    print ((hasdata && nt) ? "\n]" : "]")
    exit 0
  }
  k = toupper(ENVIRON["SB_TASK"]); r = ((k in idx) ? idx[k] : 0)
  if (mode == "task") {
    print "commits: " (r ? commits_text(r) : "-")
    if (r) for (j = 1; j <= nis[r]; j++) print "- " issue_line(r, j)
    exit 0
  }
  if (!r) exit 3
  now = ENVIRON["SB_NOW"]; se = dash(ENVIRON["SB_SESSION"])
  if (ENVIRON["SB_OP"] == "status") {
    st = ENVIRON["SB_STATE"]
    fd = ((st == "in-review" || st == "passed" || st == "failed" || (st == "blocked" && tr[r] == "in-review")) ? "review" : "build")
    if (fd == "review") tr[r] = st
    else tb[r] = st
    addhist(r, now, se, fd, st)
    if (ENVIRON["SB_COMMIT"] != "") addcommit(r, ENVIRON["SB_COMMIT"])
  } else addissue(r, now, se, ENVIRON["SB_ISSUE"], ENVIRON["SB_FIX"])
  write_json()
  if (at) {
    # The section goes; at the end of the README, so do the blank lines before it.
    c0 = at
    if (last == n) while (c0 - 1 > fmend && txt[c0 - 1] ~ /^[ \t]*$/) c0--
    for (i = 1; i < c0; i++) md_line(line[i], 0)
    for (i = last + 1; i <= n; i++) md_line(line[i], i == n)
    print "moved"
  }
}'
}

# Run sb_spec_build_awk on the story; the arguments are environment settings, such as SB_MODE=text.
# build.json is SB_SP_BJ, from sb_spec_resolve; tasks.md is read when it is there.
sb_spec_build_run() {
  local rows="" jf=0
  [ -f "$SB_SP_BJ" ] && jf=1
  if [ -n "${SB_SP_DIR:-}" ] && [ -f "$SB_SP_DIR/tasks.md" ]; then rows="$(sb_spec_task_rows "$SB_SP_DIR/tasks.md")"; fi
  if [ "$jf" -eq 1 ]; then
    env "$@" SB_JF=1 SB_ROWS="$rows" SB_STORY="$SB_T_ID" LC_ALL=C awk "$(sb_spec_build_awk)" "$SB_SP_BJ" "$SB_T_FILE"
  else
    env "$@" SB_JF=0 SB_ROWS="$rows" SB_STORY="$SB_T_ID" LC_ALL=C awk "$(sb_spec_build_awk)" "$SB_T_FILE"
  fi
}

# Print the build as spec status does: one line per task (text), or the rows as JSON (json).
sb_spec_build_show() {
  local rc=0
  sb_spec_build_run SB_MODE="$1" || rc=$?
  [ "$rc" -eq 0 ] || sb_spec_build_fail "$rc"
}

# Exit as a failed build program says: 4 is a build.json that is not a JSON object with a tasks
# array.
sb_spec_build_fail() {
  case "$1" in
    4) sb_die 1 "$(sb_rel "$SB_SP_BJ") is not a JSON object with a tasks array: fix or remove it" ;;
    *) sb_die 1 "cannot read or write the build of $SB_T_ID" ;;
  esac
}

# second-brain spec status <ID> <task> <state> [--commit H] and spec issue <ID> <task> "<issue>"
# --fix "<fix>": write the build of a spec story to build.json, and move a README "## Build"
# section into it. Usage: sb_spec_build <status | issue> <task> <state> <commit> <issue> <fix> <session>
sb_spec_build() {
  local sub="$1" task="$2" state="$3" commit="$4" issue="$5" fix="$6" session="$7" tmp tmpmd out rc=0 nofinal=0
  sb_spec_need_file tasks
  [ -n "$(tail -c 1 "$SB_T_FILE")" ] && nofinal=1
  # The new build.json is written next to it, then moved in place: a write cut off leaves the old one.
  tmp="$SB_SP_BJ.$$.tmp"
  tmpmd="$(mktemp "${TMPDIR:-/tmp}/sb-build.XXXXXX")" || sb_die 1 "cannot write a temp file"
  # A kill before the move leaves no temp file in the vault.
  trap 'rm -f "$tmp" "$tmpmd"; exit 1' INT TERM HUP
  out="$(sb_spec_build_run SB_MODE=write SB_OP="$sub" SB_TASK="$task" SB_STATE="$state" SB_COMMIT="$commit" \
    SB_ISSUE="$issue" SB_FIX="$fix" SB_SESSION="$session" SB_NOW="$(sb_now)" SB_OUT="$tmp" SB_OUTMD="$tmpmd" \
    SB_NOFINAL="$nofinal")" || rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -f "$tmp" "$tmpmd"
    [ "$rc" -eq 3 ] && sb_die 1 "no task $task in $SB_SP_SHOW/tasks.md"
    sb_spec_build_fail "$rc"
  fi
  # build.json first: a README that cannot be written keeps its section, and build.json wins.
  mv -f "$tmp" "$SB_SP_BJ" || { rm -f "$tmp" "$tmpmd"; sb_die 1 "cannot write $(sb_rel "$SB_SP_BJ")"; }
  if [ "$out" = "moved" ]; then
    cat "$tmpmd" >"$SB_T_FILE" || { rm -f "$tmp" "$tmpmd"; sb_die 1 "cannot write $SB_T_REL"; }
    sb_note "moved ## Build of $SB_T_REL into $(sb_rel "$SB_SP_BJ")"
  fi
  rm -f "$tmp" "$tmpmd"
  trap - INT TERM HUP
  task="$(printf '%s' "$task" | tr '[:lower:]' '[:upper:]')"
  printf '%s: %s\n' "$task" "${state:-issue}"
}

# second-brain spec [new | tasks | tick | packet | link | status | issue] <ID> ..., each with [--project P].
cmd_spec() {
  local sub="" id="" task="" project="" rc third="" commit="" fix="" session="${CLAUDE_SESSION_ID:-}" hasfix=0
  local json=0
  local usage="usage: second-brain spec <ID> | spec new <ID> | spec tasks <ID> [--json] | spec tick <ID> <task> | spec packet <ID> <task> | spec link <ID> | spec status <ID> [--json | <task> <state> [--commit H]] | spec issue <ID> <task> \"<issue>\" --fix \"<fix>\", each with [--project P] (status and issue also take --session S)"
  case "${1:-}" in
    new | tasks | tick | packet | link | status | issue)
      sub="$1"
      shift
      ;;
  esac
  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        [ $# -ge 2 ] || sb_die 5 "--project needs a value"
        project="$2"
        shift 2
        ;;
      --commit | --fix | --session)
        case "$sub:$1" in status:--commit | issue:--fix | status:--session | issue:--session) ;; *) sb_die 5 "$usage" ;; esac
        [ $# -ge 2 ] || sb_die 5 "$1 needs a value"
        case "$1" in --commit) commit="$2" ;; --fix) fix="$2"; hasfix=1 ;; *) session="$2" ;; esac
        shift 2
        ;;
      --json)
        case "$sub" in tasks | status) json=1 ;; *) sb_die 5 "$usage" ;; esac
        shift
        ;;
      -*) sb_die 5 "$usage" ;;
      *)
        if [ -z "$id" ]; then
          id="$1"
        elif [ -z "$task" ] && case "$sub" in tick | packet | status | issue) true ;; *) false ;; esac; then
          task="$1"
        elif [ -z "$third" ] && { [ "$sub" = "status" ] || [ "$sub" = "issue" ]; }; then
          third="$1"
        else
          sb_die 5 "$usage"
        fi
        shift
        ;;
    esac
  done
  [ -n "$id" ] || sb_die 5 "$usage"
  case "$sub" in tick | packet | issue) [ -n "$task" ] || sb_die 5 "$usage" ;; esac
  if [ "$sub" = "status" ] && [ -n "$task" ] && [ -z "$third" ]; then sb_die 5 "$usage"; fi
  if [ "$sub" = "status" ] && [ -z "$task" ] && [ -n "$commit" ]; then sb_die 5 "$usage"; fi
  if [ "$json" -eq 1 ] && [ -n "$task" ]; then sb_die 5 "$usage"; fi
  if [ "$sub" = "issue" ] && { [ -z "$third" ] || [ "$hasfix" -eq 0 ] || [ -z "$fix" ]; }; then sb_die 5 "$usage"; fi
  sb_need_task "$id" "$project"
  sb_need_profile
  SB_SP_SOFT=0
  case "$sub" in '' | link) SB_SP_SOFT=1 ;; esac
  sb_spec_resolve
  case "$sub" in
    new)
      sb_spec_write requirements Requirements
      sb_spec_write design Design
      sb_spec_write tasks Tasks
      return 0
      ;;
    tasks)
      sb_spec_need_file tasks
      if [ "$json" -eq 1 ]; then
        sb_spec_task_rows "$SB_SP_FILE" | sb_spec_json_rows id state title
      else
        sb_spec_task_rows "$SB_SP_FILE"
      fi
      return 0
      ;;
    tick)
      rc=0
      sb_spec_need_file tasks
      sb_spec_tick_file "$SB_SP_FILE" "$task" || rc=$?
      case "$rc" in
        0) printf 'ticked: %s\n' "$task" ;;
        6) sb_die 6 "$task is ticked already in $SB_SP_SHOW/tasks.md" ;;
        4) sb_die 1 "two items in $SB_SP_SHOW/tasks.md have the id $task: give each task its own id" ;;
        2) sb_die 1 "cannot write $SB_SP_SHOW/tasks.md" ;;
        *) sb_die 1 "no task $task in $SB_SP_SHOW/tasks.md" ;;
      esac
      return 0
      ;;
    packet)
      sb_spec_packet "$task"
      return 0
      ;;
    link)
      sb_spec_link
      return 0
      ;;
    status)
      if [ -z "$task" ]; then
        if [ "$json" -eq 1 ]; then sb_spec_build_show json; else sb_spec_build_show text; fi
        return 0
      fi
      case "$third" in
        todo | building | built | in-review | passed | failed | blocked) ;;
        *) sb_die 5 "a build state is one of: todo, building, built, blocked; a review state is one of: in-review, passed, failed, blocked" ;;
      esac
      case "$commit" in *[!0-9a-fA-F]*) sb_die 5 "--commit takes a commit hash: $commit" ;; esac
      sb_spec_build status "$task" "$third" "$commit" "" "" "$session"
      return 0
      ;;
    issue)
      sb_spec_build issue "$task" "" "" "$third" "$fix" "$session"
      return 0
      ;;
  esac
  printf 'id: %s\ndelivery: %s\nspec_home: %s\nrepo: %s\ndir: %s\n' \
    "$SB_T_ID" "$SB_SP_DELIVERY" "$SB_SP_HOME" "$SB_SP_REPO" "$SB_SP_SHOW"
  if [ -n "${SB_SP_ERR:-}" ]; then
    printf 'requirements: -\ndesign: -\ntasks: -\n'
    sb_die 1 "$SB_SP_ERR"
  fi
  printf 'requirements: %s/requirements.md\ndesign: %s/design.md\ntasks: %s/tasks.md\n' \
    "$SB_SP_SHOW" "$SB_SP_SHOW" "$SB_SP_SHOW"
}

# Print the state of a repo's section of a validation.md: missing (no file), no-section, empty (a
# heading with nothing under it) or ok.
sb_val_state() {
  local body
  [ -f "$1" ] || { printf 'missing\n'; return 0; }
  if ! body="$(sb_section "$1" "$2" 2>/dev/null)"; then
    printf 'no-section\n'
  elif [ -z "$body" ]; then
    printf 'empty\n'
  else
    printf 'ok\n'
  fi
}

# Print one validation row per repo of the current project, or of the one repo named exactly:
# name, home, absolute file (or "-"), shown path (or "-"), state, repo state. State is ok, missing,
# no-section, empty, or unknown for a repo home with no recorded location.
sb_val_rows() {
  local only="${1:-}" nl=$'\n' tab=$'\t' f h r rest lower name path rstate home file show
  local phome map="$nl"
  phome="$(sb_spec_value validation_home "$SB_P_PROFILE")"
  # Read each subproject note once: its repos, in lower case, with the home it sets.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    h="$(sb_fm_get "$f" validation_home 2>/dev/null)"
    [ -n "$h" ] || continue
    h="$(sb_spec_pick "$h" vault vault repo)"
    while IFS= read -r r; do
      [ -n "$r" ] && map="$map$r$tab$h$nl"
    done <<EOF2
$(sb_fm_list "$f" repos 2>/dev/null | tr '[:upper:]' '[:lower:]')
EOF2
  done <<EOF
$(sb_sub_files "$SB_P_PATH")
EOF
  while IFS=$'\t' read -r name path rstate; do
    [ -n "$name" ] || continue
    [ -z "$only" ] || [ "$name" = "$only" ] || continue
    home="$phome"
    lower="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
    case "$map" in
      *"$nl$lower$tab"*)
        rest="${map#*"$nl$lower$tab"}"
        home="${rest%%"$nl"*}"
        ;;
    esac
    if [ "$home" = "vault" ]; then
      file="$SB_P_DIR/claude/validation.md"
      show="$SB_P_PATH/claude/validation.md"
    elif [ "$path" = "-" ]; then
      printf '%s\trepo\t-\t-\tunknown\t%s\n' "$name" "$rstate"
      continue
    else
      file="$path/validation.md"
      show="$(sb_path_out "$file")"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$home" "$file" "$show" "$(sb_val_state "$file" "$name")" "$rstate"
  done <<EOF
$(sb_repo_rows_at "$SB_P_PATH")
EOF
}

# Return 0 when a repo's section of a validation.md still holds a placeholder of
# validation-repo.md.tmpl: text in angle brackets, as the doctor's placeholders check reads it.
# A retired placeholder, one an earlier version of the template held, counts too: the list in
# BEGIN is its one home.
sb_val_placeholders() {
  sb_section "$1" "$2" 2>/dev/null | LC_ALL=C SB_T="$(sb_plugin_root)/templates/validation-repo.md.tmpl" awk '
    function spans(s,   i, j, n, c, code, start) {
      n = 0; code = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "`") { code = !code; start = i + 1; continue }
        if (c != "<" || (code && i != start)) continue
        j = index(substr(s, i + 1), ">")
        if (j < 2 || substr(s, i + 1, 1) ~ /[ \t]/) continue
        sp[++n] = substr(s, i, j + 1); i += j
      }
      return n
    }
    BEGIN {
      t = ENVIRON["SB_T"]
      while ((getline line < t) > 0) { m = spans(line); for (k = 1; k <= m; k++) ph[sp[k]] = 1 }
      close(t)
      ph["<The steps that use the change as a user does, and what to look for.>"] = 1
    }
    { sub(/\r$/, ""); m = spans($0); for (k = 1; k <= m; k++) if (sp[k] in ph) { found = 1; exit } }
    END { exit(found ? 0 : 1) }'
}

# Add a repo's section to a validation.md, writing the file when it is missing. The section is
# added after one blank line, in the line endings the file has.
sb_val_write() {
  local name="$1" home="$2" file="$3" show="$4" text
  case "$(sb_val_state "$file" "$name")" in
    ok | empty)
      printf 'exists: %s\n' "$show" >&2
      return 0
      ;;
  esac
  text="$(sb_fill_text validation-repo.md.tmpl "REPO=$name")" || exit 2
  case "$text" in *'{{'*) sb_die 5 "a placeholder was left unfilled in validation-repo.md.tmpl" ;; esac
  if [ ! -f "$file" ]; then
    if [ "$home" = "vault" ]; then
      sb_fill validation.md.tmpl "$file" "PROJECT=$SB_P_NAME" "PROJECT_PATH=$SB_P_PATH" || sb_die 1 "cannot write $show"
    else
      printf '# %s validation\n\nHow to run and check %s. Agents read the section below before they build or\nreview a change.\n' \
        "$name" "$name" >"$file" || sb_die 1 "cannot write $show"
    fi
  fi
  sb_body_append "$file" "$text" || sb_die 1 "cannot write $show"
  printf '%s\n' "$show"
}

# second-brain validation <project> [repo] [--json] | validation new <project> <repo>
cmd_validation() {
  local new=0 a project="" repo="" row name home file show state rstate n=0 json=0
  local usage="usage: second-brain validation <project> [repo] [--json]"
  usage="$usage | validation new <project> <repo>"
  if [ "${1:-}" = "new" ]; then
    new=1
    shift
  fi
  for a in "$@"; do
    case "$a" in
      --json) [ "$new" -eq 0 ] || sb_die 5 "$usage"; json=1; continue ;;
      -*) sb_die 5 "$usage" ;;
    esac
    n=$((n + 1))
    if [ "$n" -eq 1 ]; then project="$a"; else repo="$a"; fi
  done
  if [ "$new" -eq 1 ]; then [ "$n" -eq 2 ] || sb_die 5 "$usage"; fi
  [ "$n" -ge 1 ] && [ "$n" -le 2 ] || sb_die 5 "$usage"
  sb_need_project "$project"
  sb_need_profile
  if [ -z "$repo" ]; then
    if [ "$json" -eq 1 ]; then
      sb_val_rows | awk -F'\t' '{ print $1 "\t" $2 "\t" $4 "\t" $5 }' |
        sb_spec_json_rows name home path state
    else
      sb_val_rows | awk -F'\t' '{ print $1 "\t" $2 "\t" $4 "\t" $5 }'
    fi
    return 0
  fi
  row="$(sb_spec_repo_row "$repo")" || sb_die 1 "$repo is not in repos of $SB_P_NAME ($SB_P_PATH/claude/profile.md)"
  IFS=$'\t' read -r name file state <<EOF
$row
EOF
  row="$(sb_val_rows "$name")"
  IFS=$'\t' read -r name home file show state rstate <<EOF
$row
EOF
  [ "$state" != "unknown" ] || sb_die 1 "no location is recorded for $name: set repos_root or repo_paths in $SB_P_PATH/claude/profile.md"
  if [ "$home" = "repo" ] && [ "$rstate" != "ok" ]; then
    sb_die 1 "the folder of $name is missing: $(sb_path_out "${file%/validation.md}")"
  fi
  if [ "$new" -eq 1 ]; then
    sb_val_write "$name" "$home" "$file" "$show"
    return 0
  fi
  case "$state" in
    missing) sb_die 1 "no validation.md for $name: run second-brain validation new \"$SB_P_NAME\" $name" ;;
    no-section) sb_die 1 "$show has no ## $name section: run second-brain validation new \"$SB_P_NAME\" $name" ;;
  esac
  if [ "$json" -eq 1 ]; then
    SB_PATH="$show" SB_BODY="$(sb_section "$file" "$name")" LC_ALL=C awk "$(sb_awk_lib)"'
      BEGIN {
        printf "{\n  \"path\": %s,\n", jstr(ENVIRON["SB_PATH"])
        printf "  \"body\": %s\n}\n", jstr(ENVIRON["SB_BODY"])
      }'
    return 0
  fi
  printf 'path: %s\n' "$show"
  sb_section "$file" "$name" || true
}
