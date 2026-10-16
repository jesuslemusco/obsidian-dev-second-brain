#!/usr/bin/env bash
# task.sh - one task README: find it, read its head, set properties, add a note, create it.

# Read file paths on stdin; print those whose frontmatter aliases hold the wanted name.
sb_alias_scan() {
  LC_ALL=C SB_W="$1" awk "$(sb_awk_lib)"'
    BEGIN { want = tolower(ENVIRON["SB_W"]) }
    {
      path = $0
      if (path == "") next
      key = ""; lineno = 0; hit = 0
      while ((getline line < path) > 0) {
        lineno++
        sub(/\r$/, "", line)
        if (lineno == 1) { sub(/^\357\273\277/, "", line); if (line != "---") break; continue }
        if (line == "---") break
        if (line ~ /^[A-Za-z0-9_][A-Za-z0-9_-]*:/) {
          i = index(line, ":"); key = substr(line, 1, i - 1); v = trim(substr(line, i + 1))
          if (key != "aliases") continue
          if (substr(v, 1, 1) == "[") { n = split_inline(v, it); for (k = 1; k <= n; k++) if (tolower(it[k]) == want) hit = 1 }
          else if (v != "" && tolower(unq(v)) == want) hit = 1
        } else if (key == "aliases" && line ~ /^[ \t]*-([ \t]|$)/) {
          v = line; sub(/^[ \t]*-[ \t]*/, "", v)
          if (tolower(unq(v)) == want) hit = 1
        }
        if (hit) break
      }
      close(path)
      if (hit) print path
    }
  '
}

# Print "project<TAB>file" for each index row whose tasks folder holds the id.
# On Windows a backslash separates folders too, so an id that holds one names no task folder.
sb_task_by_path() {
  local id="$1" rows="$2" name path keys f
  if sb_is_windows; then case "$id" in *\\*) return 0 ;; esac; fi
  while IFS=$'\t' read -r name path keys; do
    [ -n "$name" ] || continue
    f="$SB_ROOT/$path/$(sb_setting "$path" tasks_root tasks)/$id/README.md"
    [ -f "$f" ] && printf '%s\t%s\n' "$name" "$f"
  done <<EOF
$rows
EOF
  return 0
}

# Print "project<TAB>file" for each task README that lists the id as an alias.
sb_task_by_alias() {
  local id="$1" rows="$2" name path keys f
  while IFS=$'\t' read -r name path keys; do
    [ -n "$name" ] || continue
    sb_task_files "$SB_ROOT/$path/$(sb_setting "$path" tasks_root tasks)" | sb_alias_scan "$id" |
      while IFS= read -r f; do printf '%s\t%s\n' "$name" "$f"; done
  done <<EOF
$rows
EOF
  return 0
}

# Find a task by id or alias, or exit 1 or 4; sets SB_T_FILE, SB_T_REL, SB_T_ID and the project.
sb_need_task() {
  local id="$1" project="${2:-}" rows="" hits="" count name
  sb_need_root
  case "$id" in '' | */* | .*) sb_die 5 "not a task id: $id" ;; esac
  if [ -n "$project" ]; then
    sb_need_project "$project"
    rows="$SB_P_NAME"$'\t'"$SB_P_PATH"$'\t'"$SB_P_KEYS"
  else
    rows="$(sb_project_rows_by_key "$id")"
    [ -z "$rows" ] || hits="$(sb_task_by_path "$id" "$rows")"
    [ -n "$hits" ] || rows="$(sb_projects_tsv)"
  fi
  [ -n "$hits" ] || hits="$(sb_task_by_path "$id" "$rows")"
  [ -n "$hits" ] || hits="$(sb_task_by_alias "$id" "$rows")"
  [ -n "$hits" ] || sb_die 1 "no task found for: $id"
  count="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
  if [ "$count" -gt 1 ]; then
    printf '%s\n' "$hits" | SB_R="$SB_ROOT/" awk -F'\t' '{ p = $2; r = ENVIRON["SB_R"]; if (substr(p, 1, length(r)) == r) p = substr(p, length(r) + 1); print p }'
    sb_die 4 "several tasks match $id; name the project with --project"
  fi
  IFS=$'\t' read -r name SB_T_FILE <<EOF
$hits
EOF
  sb_need_project "$name"
  SB_T_REL="$(sb_rel "$SB_T_FILE")"
  SB_T_ID="$(basename "$(dirname "$SB_T_FILE")")"
}

# Print the short head of a task: properties, summary line and newest status note.
sb_task_head() {
  local id="" project=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        [ $# -ge 2 ] || sb_die 5 "--project needs a value"
        project="$2"
        shift 2
        ;;
      -*) sb_die 5 "usage: second-brain task head <ID> [--project P]" ;;
      *)
        [ -z "$id" ] || sb_die 5 "usage: second-brain task head <ID> [--project P]"
        id="$1"
        shift
        ;;
    esac
  done
  [ -n "$id" ] || sb_die 5 "usage: second-brain task head <ID> [--project P]"
  sb_need_task "$id" "$project"
  LC_ALL=C SB_ID="$SB_T_ID" SB_REL="$SB_T_REL" awk "$(sb_awk_lib)"'
    function addtag(v) {
      sub(/^#/, "", v)
      if (v == "" || substr(v, 1, 5) == "type/" || substr(v, 1, 7) == "status/") return
      topics = (topics == "" ? v : topics ", " v)
    }
    function show(k, v) { print k ": " (v == "" ? "-" : v) }
    BEGIN { id = ENVIRON["SB_ID"]; state = 0 }
    {
      line = $0; sub(/\r$/, "", line)
      if (NR == 1) {
        sub(/^\357\273\277/, "", line)
        if (line == "---") { state = 1; next }
        state = 2
      }
      if (state == 1) {
        if (line == "---") { state = 2; next }
        if (line ~ /^[A-Za-z0-9_][A-Za-z0-9_-]*:/) {
          i = index(line, ":"); key = substr(line, 1, i - 1); v = trim(substr(line, i + 1))
          if (key == "status") status = unq(v)
          else if (key == "sprint") sprint = unq(v)
          else if (key == "branch") branch = unq(v)
          else if (key == "epic") epic = unq(v)
          else if (key == "subproject") subp = unq(v)
          else if (key == "next") nxt = unq(v)
          else if (key == "title") title = unq(v)
          else if (key == "tags") {
            if (substr(v, 1, 1) == "[") { n = split_inline(v, it); for (k = 1; k <= n; k++) addtag(it[k]) }
            else addtag(unq(v))
          }
          next
        }
        if (key == "tags" && line ~ /^[ \t]*-([ \t]|$)/) { v = line; sub(/^[ \t]*-[ \t]*/, "", v); addtag(unq(v)); next }
        if (key == "envs" && line ~ /^[ \t]+[^ \t#]/) {
          e = trim(line); i = index(e, ":")
          if (i > 1) envs = (envs == "" ? "" : envs ",") substr(e, 1, i - 1) ":" mapfield(substr(e, i + 1), "id") ":" mapfield(substr(e, i + 1), "status")
        }
        next
      }
      if (h1 == "" && line ~ /^# /) { h1 = trim(substr(line, 3)); next }
      if (!gotsum && line ~ /^\*\*Summary:\*\*/) { summary = trim(substr(line, 13)); gotsum = 1; insum = 1; next }
      if (insum) {
        if (line ~ /^[ \t]*$/ || line ~ /^#/ || line ~ /^\*\*[A-Za-z]/) insum = 0
        else { summary = summary " " trim(line); next }
      }
      if (line ~ /^## /) { innotes = (tolower(line) ~ /^##[ \t]+status notes[ \t]*$/); next }
      if (innotes && note == "" && line !~ /^[ \t]*$/ && line !~ /^[ \t]*</) note = trim(line)
    }
    END {
      if (title == "") {
        title = h1; p = id " - "
        if (substr(title, 1, length(p)) == p) title = substr(title, length(p) + 1)
      }
      if (summary ~ /^<.*>$/) summary = ""
      print "id: " id
      print "path: " ENVIRON["SB_REL"]
      show("title", title); show("status", status); show("next", nxt)
      show("sprint", sprint); show("branch", branch); show("epic", epic)
      if (subp != "") show("subproject", subp)
      show("topics", topics)
      show("envs", envs); show("summary", cut(summary, 300)); show("last_note", cut(note, 300))
    }
  ' "$SB_T_FILE"
}

# Set or remove scalar properties of a task; status and its tag change together.
sb_task_set() {
  local id="" project="" kv key value out="" n=0 i=0
  local pairs
  pairs=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        [ $# -ge 2 ] || sb_die 5 "--project needs a value"
        project="$2"
        shift 2
        ;;
      *=*)
        if [ -z "$id" ]; then sb_die 5 "usage: second-brain task set <ID> key=value... [--project P]"; fi
        pairs[$n]="$1"
        n=$((n + 1))
        shift
        ;;
      -*) sb_die 5 "usage: second-brain task set <ID> key=value... [--project P]" ;;
      *)
        [ -z "$id" ] || sb_die 5 "not a key=value pair: $1"
        id="$1"
        shift
        ;;
    esac
  done
  if [ -z "$id" ] || [ "$n" -eq 0 ]; then
    sb_die 5 "usage: second-brain task set <ID> key=value... [--project P]"
  fi
  while [ "$i" -lt "$n" ]; do
    kv="${pairs[$i]}"
    key="${kv%%=*}"
    value="${kv#*=}"
    case "$key" in
      '' | *[!A-Za-z0-9_-]*) sb_die 5 "not a property name: $key" ;;
      jira_id) sb_die 5 "the helper never writes jira_id; the ticket id is the folder name and the first alias" ;;
      aliases | tags | envs | carried_from) sb_die 5 "task set changes scalar properties only; edit $key in the note" ;;
      status)
        case "$value" in
          planned | in-progress | in-review | done | abandoned) ;;
          *) sb_die 5 "status must be one of: planned, in-progress, in-review, done, abandoned" ;;
        esac
        ;;
      sprint)
        [ -z "$value" ] || sb_date_ok "$value" || sb_die 5 "a sprint id is its end date, YYYY-MM-DD: $value"
        ;;
      type)
        case "$value" in
          '' | *[!a-z0-9-]*) sb_die 5 "a type is lowercase letters, digits and hyphens, and cannot be removed: $value" ;;
        esac
        ;;
    esac
    i=$((i + 1))
  done
  sb_need_task "$id" "$project"
  i=0
  while [ "$i" -lt "$n" ]; do
    # Removing a leftover sprint id is still allowed where sprints are off.
    case "${pairs[$i]}" in sprint=?*) sb_need_sprints ;; esac
    # A subproject is one of the project's, written as its note is named.
    case "${pairs[$i]}" in
      subproject=?*)
        sb_need_sub "${pairs[$i]#subproject=}"
        pairs[$i]="subproject=$SB_S_NAME"
        ;;
    esac
    i=$((i + 1))
  done
  i=0
  while [ "$i" -lt "$n" ]; do
    kv="${pairs[$i]}"
    key="${kv%%=*}"
    value="${kv#*=}"
    sb_fm_set "$SB_T_FILE" "$key" "$value" || sb_die 1 "cannot edit $SB_T_REL"
    if [ "$SB_FM_CHANGED" -eq 1 ]; then
      if [ -n "$value" ]; then out="$out$key: $value"$'\n'; else out="$out$key: (removed)"$'\n'; fi
    fi
    if [ "$key" = "status" ]; then
      sb_fm_status_tag "$SB_T_FILE" "$value"
      if [ "$SB_FM_CHANGED" -eq 1 ]; then
        case "$value" in
          done | abandoned) out="${out}tags: status/done"$'\n' ;;
          *) out="${out}tags: status/active"$'\n' ;;
        esac
      fi
    elif [ "$key" = "type" ]; then
      # The type/ tag follows the property: replace the one there, or add it before the status tag.
      if sb_fm_list "$SB_T_FILE" tags | grep -q '^#\{0,1\}type/'; then
        sb_fm_edit "$SB_T_FILE" listswap tags "type/" "type/$value"
      else
        sb_fm_edit "$SB_T_FILE" tagadd tags "type/$value"
      fi
      [ "$SB_FM_CHANGED" -eq 0 ] || out="${out}tags: type/$value"$'\n'
    fi
    i=$((i + 1))
  done
  if [ -n "$out" ]; then printf '%s' "$out"; else printf 'no change\n'; fi
}

# Print one status note line for today.
sb_note_line() {
  local text
  text="$(printf '%s' "$1" | tr '\n\r\t' '   ')"
  if [ -n "${2:-}" ]; then
    printf '**%s (session `%s`) - %s**\n' "$(sb_today)" "$2" "$text"
  else
    printf '**%s - %s**\n' "$(sb_today)" "$text"
  fi
}

# Put a dated line at the top of a note's status notes.
sb_add_status_note() {
  local file="$1" line="$2"
  sb_body_insert "$file" "## Status notes" after "$line" && return 0
  sb_body_insert "$file" "## Discovery log" before "## Status notes"$'\n\n'"$line" && return 0
  sb_body_append "$file" "## Status notes"$'\n\n'"$line"
}

# Prepend a dated status note to a task.
sb_task_note() {
  local id="" text="" project="" session="${CLAUDE_SESSION_ID:-}" line
  while [ $# -gt 0 ]; do
    case "$1" in
      --project | --session)
        [ $# -ge 2 ] || sb_die 5 "$1 needs a value"
        if [ "$1" = "--project" ]; then project="$2"; else session="$2"; fi
        shift 2
        ;;
      *)
        if [ -z "$id" ]; then
          id="$1"
        elif [ -z "$text" ]; then
          text="$1"
        else
          sb_die 5 "usage: second-brain task note <ID> \"<text>\" [--project P] [--session S]"
        fi
        shift
        ;;
    esac
  done
  if [ -z "$id" ] || [ -z "$text" ]; then
    sb_die 5 "usage: second-brain task note <ID> \"<text>\" [--project P] [--session S]"
  fi
  sb_need_task "$id" "$project"
  line="$(sb_note_line "$text" "$session")"
  sb_add_status_note "$SB_T_FILE" "$line" || sb_die 1 "cannot edit $SB_T_REL"
  printf '%s\n' "$line"
}

# Print the topic tags of a note, one per line, or "-" when it has none.
sb_task_topics() {
  local out
  out="$(sb_fm_list "$1" tags | sed 's/^#//' | grep -v -e '^type/' -e '^status/' || true)"
  if [ -n "$out" ]; then printf '%s\n' "$out"; else printf '%s\n' "-"; fi
}

# Add or remove a topic tag on a task; print the topic tags that result.
sb_task_tag() {
  local id="" action="" tag="" project="" troot topics_dir bad
  local usage="usage: second-brain task tag <ID> add|remove <tag> [--project P]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        [ $# -ge 2 ] || sb_die 5 "--project needs a value"
        project="$2"
        shift 2
        ;;
      *)
        if [ -z "$id" ]; then
          id="$1"
        elif [ -z "$action" ]; then
          action="$1"
        elif [ -z "$tag" ]; then
          tag="$1"
        else
          sb_die 5 "$usage"
        fi
        shift
        ;;
    esac
  done
  case "$action" in add | remove) ;; *) sb_die 5 "$usage" ;; esac
  tag="$(printf '%s' "$tag" | tr '\n\r\t' '   ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  tag="${tag#\#}"
  tag="${tag#/}"
  tag="${tag%/}"
  [ -n "$tag" ] || sb_die 5 "$usage"
  case "$(printf '%s' "$tag" | tr '[:upper:]' '[:lower:]')" in
    type | status | type/* | status/*) sb_die 5 "type/ and status/ tags follow the type and status properties; they are not edited here" ;;
  esac
  bad="$(printf '%s' "$tag" | LC_ALL=C tr -d -c '#:,"[]{}|\\'"'")"
  [ -z "$bad" ] || sb_die 5 "not a topic tag: $tag"
  sb_need_task "$id" "$project"
  if [ "$action" = "remove" ]; then
    sb_fm_edit "$SB_T_FILE" listdel tags "$tag" || sb_die 1 "cannot edit $SB_T_REL"
    sb_task_topics "$SB_T_FILE"
    return 0
  fi
  tag="$(printf '%s' "$tag" | tr '[:upper:]' '[:lower:]' | tr ' _' '--')"
  troot="$(printf '%s' "$SB_TOPICS_ROOT" | tr '[:upper:]' '[:lower:]')"
  [ "$troot" = "." ] || tag="${tag#"$troot"/}"
  [ -n "$tag" ] || sb_die 5 "not a topic tag"
  topics_dir="$SB_P_DIR"
  [ "$SB_TOPICS_ROOT" = "." ] || topics_dir="$SB_P_DIR/$SB_TOPICS_ROOT"
  sb_topic_dir "$topics_dir" "$tag" >/dev/null || sb_note "no folder for the topic tag $tag under $SB_P_PATH/$SB_TOPICS_ROOT"
  sb_fm_edit "$SB_T_FILE" tagadd tags "$tag" || sb_die 1 "cannot edit $SB_T_REL"
  sb_task_topics "$SB_T_FILE"
}

# Add an alias to a task, after the ones it has; print the aliases that result.
sb_task_alias() {
  local id="" action="" alias="" project="" other
  local usage="usage: second-brain task alias <ID> add <alias> [--project P]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        [ $# -ge 2 ] || sb_die 5 "--project needs a value"
        project="$2"
        shift 2
        ;;
      *)
        if [ -z "$id" ]; then
          id="$1"
        elif [ -z "$action" ]; then
          action="$1"
        else
          alias="${alias:+$alias }$1"
        fi
        shift
        ;;
    esac
  done
  [ "$action" = "add" ] || sb_die 5 "$usage"
  alias="$(printf '%s' "$alias" | tr '\n\r\t' '   ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -n "$alias" ] || sb_die 5 "$usage"
  sb_need_task "$id" "$project"
  # An alias names one task: refuse one that another task of the project already answers to.
  other=""
  case "$alias" in
    */* | .*) ;;
    *) [ ! -f "$SB_P_DIR/$SB_TASKS_ROOT/$alias/README.md" ] || other="$SB_P_DIR/$SB_TASKS_ROOT/$alias/README.md" ;;
  esac
  [ -n "$other" ] || other="$(sb_task_files "$SB_P_DIR/$SB_TASKS_ROOT" | sb_alias_scan "$alias" | grep -vxF -- "$SB_T_FILE" | head -1)"
  if [ -n "$other" ] && [ "$other" != "$SB_T_FILE" ]; then
    sb_die 6 "$alias already names another task: $(sb_rel "$other")"
  fi
  # The first alias is the folder id; put it there when the note has no aliases yet.
  [ -n "$(sb_fm_list "$SB_T_FILE" aliases | head -1)" ] || sb_fm_edit "$SB_T_FILE" listadd aliases "$SB_T_ID"
  sb_fm_edit "$SB_T_FILE" listadd aliases "$alias" || sb_die 1 "cannot edit $SB_T_REL"
  sb_fm_list "$SB_T_FILE" aliases
}

# Print the folder a topic tag maps to under a folder, or return 1.
sb_topic_dir() {
  local dir="$1" rest="$2" part entry found name
  while [ -n "$rest" ]; do
    part="${rest%%/*}"
    case "$rest" in
      */*) rest="${rest#*/}" ;;
      *) rest="" ;;
    esac
    found=""
    for entry in "$dir"/*/; do
      [ -d "$entry" ] || continue
      entry="${entry%/}"
      name="$(printf '%s' "${entry##*/}" | tr '[:upper:]' '[:lower:]' | tr ' _' '--')"
      if [ "$name" = "$part" ]; then
        found="$entry"
        break
      fi
    done
    [ -n "$found" ] || return 1
    dir="$found"
  done
  printf '%s\n' "$dir"
}

# Create a task folder and its README from the template; exit 6 when the folder exists.
sb_task_new() {
  local id="" project="" title="" topics="" envs=0 rows count dir file taglines="" tag topics_dir
  local hub alias uplink envlist="" envblock="" env block usage rc=0 troot bad other sub=""
  local tab=$'\t' nl=$'\n'
  usage="usage: second-brain task new <ID> --project P [--title T] [--topics a,b] [--envs] [--subproject S]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --project | --title | --topics | --subproject)
        [ $# -ge 2 ] || sb_die 5 "$1 needs a value"
        case "$1" in
          --project) project="$2" ;;
          --title) title="$2" ;;
          --topics) topics="$2" ;;
          --subproject) sub="$2" ;;
        esac
        shift 2
        ;;
      --envs)
        envs=1
        shift
        ;;
      -*) sb_die 5 "$usage" ;;
      *)
        [ -z "$id" ] || sb_die 5 "$usage"
        id="$1"
        shift
        ;;
    esac
  done
  [ -n "$id" ] || sb_die 5 "$usage"
  case "$id" in
    *[!A-Za-z0-9._-]* | .* | -*) sb_die 5 "a task id holds letters, digits, dots, hyphens and underscores: $id" ;;
  esac
  sb_need_root
  if [ -z "$project" ]; then
    rows="$(sb_project_rows_by_key "$id")"
    count="$(printf '%s' "$rows" | grep -c . || true)"
    [ "$count" = "1" ] || sb_die 5 "$usage"
    project="${rows%%"$tab"*}"
  fi
  sb_need_project "$project"
  sb_need_profile
  dir="$SB_P_DIR/$SB_TASKS_ROOT/$id"
  file="$dir/README.md"
  [ ! -e "$file" ] || sb_die 6 "the task already has a README: $SB_P_PATH/$SB_TASKS_ROOT/$id/README.md"
  if [ -e "$dir" ] && [ ! -d "$dir" ]; then sb_die 6 "a file is in the way: $SB_P_PATH/$SB_TASKS_ROOT/$id"; fi
  other="$(sb_task_files "$SB_P_DIR/$SB_TASKS_ROOT" | sb_alias_scan "$id" | head -1)"
  [ -z "$other" ] || sb_die 6 "$id is already an alias of $(sb_rel "$other")"
  [ -z "$sub" ] || sb_need_sub "$sub"
  if [ "$envs" -eq 1 ]; then
    # A subproject's own environments win over the profile's.
    [ -z "$sub" ] || envlist="$(sb_fm_list "$SB_S_FILE" environments)"
    [ -n "$envlist" ] || envlist="$(sb_fm_list "$SB_P_PROFILE" environments)"
    [ -n "$envlist" ] || sb_die 5 "--envs needs the environments list in the profile, and it is empty"
  fi
  title="$(printf '%s' "$title" | tr '\n\r\t' '   ')"
  [ -n "$title" ] || title="Untitled"
  topics_dir="$SB_P_DIR"
  [ "$SB_TOPICS_ROOT" = "." ] || topics_dir="$SB_P_DIR/$SB_TOPICS_ROOT"
  troot="$(printf '%s' "$SB_TOPICS_ROOT" | tr '[:upper:]' '[:lower:]')"
  while IFS= read -r tag; do
    tag="${tag#\#}"
    tag="${tag#/}"
    tag="${tag%/}"
    [ "$troot" = "." ] || tag="${tag#"$troot"/}"
    [ -n "$tag" ] || continue
    bad="$(printf '%s' "$tag" | LC_ALL=C tr -d -c '#:"[]{}|\\'"'")"
    [ -z "$bad" ] || sb_die 5 "not a topic tag: $tag"
    sb_topic_dir "$topics_dir" "$tag" >/dev/null || sb_note "no folder for the topic tag $tag under $SB_P_PATH/$SB_TOPICS_ROOT"
    taglines="$taglines${taglines:+$nl}  - $tag"
  done <<EOF
$(printf '%s\n' "$topics" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]' | tr ' _' '--')
EOF
  hub="$SB_P_DIR/$SB_TASKS_ROOT/README.md"
  alias="$(sb_fm_list "$hub" aliases 2>/dev/null | head -1)"
  [ -n "$alias" ] || alias="$SB_P_NAME Tasks Hub"
  uplink="[[$SB_P_PATH/$SB_TASKS_ROOT/README|$alias]]"
  sb_fill task-readme.md.tmpl "$file" "ID=$id" "TITLE=$title" "TOPIC_TAGS=$taglines" "UP_LINK=$uplink" || rc=$?
  [ "$rc" -ne 6 ] || sb_die 6 "the task README exists: $SB_P_PATH/$SB_TASKS_ROOT/$id/README.md"
  [ "$rc" -eq 0 ] || sb_die 1 "cannot write $SB_P_PATH/$SB_TASKS_ROOT/$id/README.md"
  sb_fm_set_raw "$file" title "$(sb_yaml_quote "$title" 1)"
  [ "$(sb_yaml_quote "$id")" = "$id" ] || sb_fm_edit "$file" listswap aliases "$id" "$id"
  [ -z "$sub" ] || sb_fm_set "$file" subproject "$SB_S_NAME"
  if [ "$envs" -eq 1 ]; then
    # Only the first environment has a ticket yet; the others are added as their tickets appear.
    for env in $envlist; do
      envblock="  $env: { id: $id, status: planned }"
      break
    done
    env="$(printf '%s' "$env" | tr '[:lower:]' '[:upper:]')"
    sb_fm_edit "$file" setblock envs "$envblock"
    block="$(sb_fill_text task-envs.md.tmpl "ID=$id" "ENV=$env")"
    sb_body_insert "$file" "## Description" before "$block" || sb_body_append "$file" "$block"
  fi
  sb_rel "$file"
}

# Dispatch the task subcommands.
cmd_task() {
  local sub="${1:-}"
  [ $# -gt 0 ] && shift
  case "$sub" in
    head) sb_task_head "$@" ;;
    set) sb_task_set "$@" ;;
    new) sb_task_new "$@" ;;
    note) sb_task_note "$@" ;;
    tag) sb_task_tag "$@" ;;
    alias) sb_task_alias "$@" ;;
    *) sb_die 5 "usage: second-brain task head | set | note | tag | alias | new <ID> ..." ;;
  esac
}
