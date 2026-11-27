#!/usr/bin/env bash
# task.sh - one task README: find it, read its head, set properties, add a note, create it.

# Read file paths on stdin; print those whose frontmatter aliases hold the wanted name.
sb_alias_scan() {
  LC_ALL=C SB_W="$1" awk "$(sb_awk_lib)"'
    BEGIN { want = tolower(ENVIRON["SB_W"]) }
    $0 != "" { split("", al); alias_set($0, al); if (want in al) print }'
}

# sb_alias_hits: read file paths, one per line, then a line that is \034 alone, then names, one
# per line; print "<name><TAB><path>" for each path whose frontmatter aliases hold a name, without
# letter case, as sb_alias_scan finds them: each name once, in their order, and the paths in
# theirs. Each file is read once, for every name.
sb_alias_hits() {
  LC_ALL=C awk "$(sb_awk_lib)"'
    read_list() { next }
    $0 != "" && !($0 in asked) { asked[$0] = 1; want[++nw] = $0 }
    END {
      for (j = 1; j <= list_n && nw; j++) {
        split("", al)
        alias_set(list_file[j], al)
        for (i = 1; i <= nw; i++) if (tolower(want[i]) in al) hit[i, j] = 1
      }
      for (i = 1; i <= nw; i++) for (j = 1; j <= list_n; j++) if ((i, j) in hit) print want[i] "\t" list_file[j]
    }'
}

# Print "project<TAB>file" for each index row whose tasks folder holds the id, live or archived.
# On Windows a backslash separates folders too, so an id that holds one names no task folder.
sb_task_by_path() {
  local id="$1" rows="$2" name path keys f
  if sb_is_windows; then case "$id" in *\\*) return 0 ;; esac; fi
  while IFS=$'\t' read -r name path keys; do
    [ -n "$name" ] || continue
    sb_task_readme "$SB_ROOT/$path/$(sb_setting "$path" tasks_root tasks)" "$id" |
      while IFS= read -r f; do printf '%s\t%s\n' "$name" "$f"; done
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
    sb_task_list "$SB_ROOT/$path/$(sb_setting "$path" tasks_root tasks)" | sb_alias_scan "$id" |
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

# Print the short head of a task: properties, summary line and newest status note. With --json,
# one JSON object with the same keys; topics and envs are arrays. The epic line takes its key from
# the profile's parent_label.
sb_task_head() {
  local id="" project="" json=0 usage="usage: second-brain task head <ID> [--project P] [--json]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        [ $# -ge 2 ] || sb_die 5 "--project needs a value"
        project="$2"
        shift 2
        ;;
      --json)
        json=1
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
  sb_need_task "$id" "$project"
  LC_ALL=C SB_ID="$SB_T_ID" SB_REL="$SB_T_REL" SB_JSON="$json" SB_LABEL="$(sb_parent_label)" awk "$(sb_awk_lib)"'
    function addtag(v) {
      sub(/^#/, "", v)
      if (v == "" || substr(v, 1, 5) == "type/" || substr(v, 1, 7) == "status/") return
      topics = (topics == "" ? v : topics ", " v); tp[++ntp] = v
    }
    function show(k, v) {
      if (v == "") v = "-"
      if (json) printf "%s\n  %s: %s", (nk++ ? "," : "{"), jstr(k), jstr(v)
      else print k ": " v
    }
    function showlist(k, v, n, a,   i, l) {
      if (!json) { show(k, v); return }
      l = ""; for (i = 1; i <= n; i++) l = l (i > 1 ? ", " : "") jstr(a[i])
      printf "%s\n  %s: [%s]", (nk++ ? "," : "{"), jstr(k), l
    }
    BEGIN { id = ENVIRON["SB_ID"]; state = 0; json = (ENVIRON["SB_JSON"] == "1") }
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
          else if (key == "repo") repo = unq(v)
          else if (key == "epic") epic = unq(v)
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
          if (i > 1) {
            item = substr(e, 1, i - 1) ":" mapfield(substr(e, i + 1), "id") ":"
            item = item mapfield(substr(e, i + 1), "status")
            envs = (envs == "" ? item : envs "," item); en[++nen] = item
          }
        }
        next
      }
      # A heading in fenced code is no heading, as sb_body_insert reads it for task note.
      if (line ~ /^[ \t]*(```|~~~)/) fence = !fence
      if (h1 == "" && line ~ /^# /) { h1 = trim(substr(line, 3)); next }
      if (!gotsum && line ~ /^\*\*Summary:\*\*/) { summary = trim(substr(line, 13)); gotsum = 1; insum = 1; next }
      if (insum) {
        if (line ~ /^[ \t]*$/ || line ~ /^#/ || line ~ /^\*\*[A-Za-z]/) insum = 0
        else { summary = summary " " trim(line); next }
      }
      if (!fence && line ~ /^## /) { innotes = (tolower(line) ~ /^##[ \t]+status notes[ \t]*$/); next }
      if (innotes && note == "" && line !~ /^[ \t]*$/ && line !~ /^[ \t]*</) note = trim(line)
    }
    END {
      if (title == "") {
        title = h1; p = id " - "
        if (substr(title, 1, length(p)) == p) title = substr(title, length(p) + 1)
      }
      if (summary ~ /^<.*>$/) summary = ""
      show("id", id); show("path", ENVIRON["SB_REL"])
      show("title", title); show("status", status); show("next", nxt)
      show("sprint", sprint); show("branch", branch)
      if (repo != "") show("repo", repo)
      show(ENVIRON["SB_LABEL"], epic)
      showlist("topics", topics, ntp, tp)
      showlist("envs", envs, nen, en)
      show("summary", cut(summary, 300)); show("last_note", cut(note, 300))
      if (json) print "\n}"
    }
  ' "$SB_T_FILE"
}

# Set or remove scalar properties of a task; status and its tag change together. In a status
# project a status change then moves the task to the folder of its new status, and in a sprint
# project a sprint change to the folder of its new sprint, or to backlog/ for none. In both an epic
# change moves it into its parent's folder there, or out of it, and a move keeps a child under its
# parent.
sb_task_set() {
  local id="" project="" kv key value out="" n=0 i=0 status="" dest="" sprint="" has_sprint=0 layout
  local epic="" has_epic=0 move=0 parent="" prc=0 cur echanged=0
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
      depends_on) sb_die 5 "task set changes scalar properties only; use second-brain task dep for depends_on" ;;
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
    # A story's repo is one that second-brain repo lists, written as it lists it.
    case "${pairs[$i]}" in
      repo=?*)
        sb_need_repo "${pairs[$i]#repo=}"
        pairs[$i]="repo=$SB_R_NAME"
        ;;
    esac
    i=$((i + 1))
  done
  # In a status project a new status moves the task to the folder of that status once the keys are
  # written, so the destination is looked at first. The last status pair wins. The same status
  # moves nothing, and a folder that already is the destination is not in its own way.
  # In a sprint project a sprint other than the task's own moves it the same way, to the folder of
  # that sprint, or to backlog/ for none; there a status change moves nothing. The last sprint pair
  # wins. A sprint folder that is a task, with a README.md of its own, is in the way too, and a
  # pattern that names no sprint folder exits 5 before anything is written.
  # In both, an epic other than the task's own moves it into its parent's folder in the folder of
  # its status or sprint, or out to that folder with none, and every move keeps a child under its
  # parent. An epic that names no single task of the project names no parent.
  status=""
  sprint=""
  has_sprint=0
  i=0
  while [ "$i" -lt "$n" ]; do
    case "${pairs[$i]}" in
      status=*) status="${pairs[$i]#status=}" ;;
      sprint=*)
        sprint="${pairs[$i]#sprint=}"
        has_sprint=1
        ;;
      epic=*)
        epic="${pairs[$i]#epic=}"
        has_epic=1
        ;;
    esac
    i=$((i + 1))
  done
  layout="$(sb_task_layout)"
  if [ "$layout" = "status" ] || [ "$layout" = "sprint" ]; then
    if [ "$layout" = "status" ]; then
      cur="$(sb_fm_get "$SB_T_FILE" status)" || cur=""
      [ -z "$status" ] || [ "$status" = "$cur" ] || move=1
      [ -n "$status" ] || status="$cur"
    else
      cur="$(sb_fm_get "$SB_T_FILE" sprint)" || cur=""
      [ "$has_sprint" -eq 0 ] || [ "$sprint" = "$cur" ] || move=1
      [ "$has_sprint" -eq 1 ] || sprint="$cur"
    fi
    # The parent is read only for a move: the new epic's, else the task's own.
    if [ "$has_epic" -eq 1 ] && [ "$epic" != "$(sb_fm_get "$SB_T_FILE" epic)" ]; then
      move=1
      echanged=1
      parent="$(sb_task_parent "$SB_T_FILE" "$epic")" || prc=$?
    elif [ "$move" -eq 1 ]; then
      parent="$(sb_task_parent "$SB_T_FILE")" || prc=$?
    fi
    [ "$prc" -eq 0 ] || parent=""
    if [ "$prc" -eq 2 ] && [ "$echanged" -eq 1 ]; then
      sb_note "$(sb_parent_label) $epic names no single task of $SB_P_NAME"
    fi
    if [ "$move" -eq 1 ] && [ "$layout" = "status" ]; then
      # A task with no status of the five has no folder to move to.
      case "$status" in
        planned | in-progress | in-review | done | abandoned) dest="$(sb_task_status_dir "$status" "$parent")" ;;
      esac
    elif [ "$move" -eq 1 ]; then
      dest="$(sb_task_sprint_dir "$sprint" "$parent")" || exit $?
    fi
    if [ -z "$dest" ] || [ "$dest" = "${SB_T_REL%/*}" ]; then
      dest=""
    elif [ "$layout" = "sprint" ] && [ -n "$sprint" ]; then
      sb_task_sprint_dest_free "$dest" "$SB_T_FILE"
    else
      sb_task_dest_free "$dest" "$SB_T_FILE"
    fi
  fi
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
  [ -n "$dest" ] || return 0
  sb_task_relocate "$dest"
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

# Return 0 when a name, lowercased, is in SB_TASK_RESERVED: archive, one of the five status folders
# or backlog, and print that folder; such a name is no task id and no alias in any layout, since a
# file system that ignores letter case would take it for that folder.
sb_task_reserved() {
  local name s
  sb_lc "$1"
  name="$SB_LC"
  for s in $SB_TASK_RESERVED; do
    if [ "$name" = "$s" ]; then
      printf '%s\n' "$s"
      return 0
    fi
  done
  return 1
}

# sb_task_refuse_reserved <name> <task id|task alias>: exit 5 when the name is reserved, naming its
# folder: the name as typed, the status lowercased. Archive keeps its own message, and backlog names
# its folder lowercased.
sb_task_refuse_reserved() {
  local folder
  folder="$(sb_task_reserved "$1")" || return 0
  [ "$folder" != "archive" ] || sb_die 5 "archive is the folder of the archived tasks, not a $2"
  [ "$folder" != "backlog" ] || sb_die 5 "backlog is the folder of the backlog tasks, not a $2"
  sb_die 5 "$1 is the folder of the $folder tasks, not a $2"
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
  sb_task_refuse_reserved "$alias" "task alias"
  sb_need_task "$id" "$project"
  # An alias names one task: refuse one that another task of the project already answers to.
  other=""
  case "$alias" in
    */* | .*) ;;
    *) other="$(sb_task_readme "$SB_P_DIR/$SB_TASKS_ROOT" "$alias" | grep -vxF -- "$SB_T_FILE" | head -1)" ;;
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

# Add or remove a task in another task's depends_on list; print the links that result.
sb_task_dep() {
  local id="" action="" dep="" project="" target link depfile found
  local usage="usage: second-brain task dep <ID> add|remove <ID> [--project P]"
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
        elif [ -z "$dep" ]; then
          dep="$1"
        else
          sb_die 5 "$usage"
        fi
        shift
        ;;
    esac
  done
  case "$action" in add | remove) ;; *) sb_die 5 "$usage" ;; esac
  [ -n "$dep" ] || sb_die 5 "$usage"
  # The task depended on first: its path and folder id make the link.
  sb_need_task "$dep" "$project"
  depfile="$SB_T_FILE"
  target="${SB_T_REL%.md}"
  link="[[$target|$SB_T_ID]]"
  sb_need_task "$id" "$project"
  [ "$SB_T_FILE" != "$depfile" ] || sb_die 5 "a task cannot depend on itself: $SB_T_ID"
  found="$(sb_fm_list "$SB_T_FILE" depends_on | LC_ALL=C SB_W="$target" awk "$(sb_awk_lib)"'
    tolower(dep_target($0)) == tolower(ENVIRON["SB_W"]) { print; exit }')"
  if [ "$action" = "add" ]; then
    [ -n "$found" ] || sb_fm_edit "$SB_T_FILE" listadd depends_on "$link" 1 || sb_die 1 "cannot edit $SB_T_REL"
  else
    [ -z "$found" ] || sb_fm_edit "$SB_T_FILE" listdel depends_on "$found" || sb_die 1 "cannot edit $SB_T_REL"
  fi
  found="$(sb_fm_list "$SB_T_FILE" depends_on)"
  if [ -n "$found" ]; then printf '%s\n' "$found"; else printf '%s\n' "-"; fi
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

# Create a task folder and its README from the template, in planned/ in a status project and in
# backlog/ in a sprint project; exit 6 when the folder exists, when it holds tasks, as a group
# folder does, or when the id is a task in another folder.
sb_task_new() {
  local id="" project="" title="" topics="" envs=0 rows count dir file taglines="" tag topics_dir
  local hub alias uplink envlist="" envblock="" env block usage rc=0 troot bad other made d vdir
  local repo="" tab=$'\t' nl=$'\n'
  usage="usage: second-brain task new <ID> --project P [--title T] [--topics a,b] [--envs] [--repo R]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --project | --title | --topics | --repo)
        [ $# -ge 2 ] || sb_die 5 "$1 needs a value"
        case "$1" in
          --project) project="$2" ;;
          --title) title="$2" ;;
          --topics) topics="$2" ;;
          --repo) repo="$2" ;;
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
  sb_task_refuse_reserved "$id" "task id"
  sb_need_root
  if [ -z "$project" ]; then
    rows="$(sb_project_rows_by_key "$id")"
    count="$(printf '%s' "$rows" | grep -c . || true)"
    [ "$count" = "1" ] || sb_die 5 "$usage"
    project="${rows%%"$tab"*}"
  fi
  sb_need_project "$project"
  sb_need_profile
  # In a status project a new task starts in planned/, in a sprint project in backlog/, as it has no
  # sprint yet; in any other layout at the tasks root.
  vdir="$SB_P_PATH/$SB_TASKS_ROOT/$id"
  case "$(sb_task_layout)" in
    status) vdir="$(SB_T_ID="$id" sb_task_status_dir planned)" ;;
    sprint) vdir="$(SB_T_ID="$id" sb_task_sprint_dir "")" ;;
  esac
  dir="$SB_ROOT/$vdir"
  file="$dir/README.md"
  [ ! -e "$file" ] || sb_die 6 "the task already has a README: $vdir/README.md"
  if [ -e "$dir" ] && [ ! -d "$dir" ]; then sb_die 6 "a file is in the way: $vdir"; fi
  # A folder with no README that holds a task is a group folder, such as a sprint's: a README in it
  # would make it a task, and the tasks inside would leave the board.
  for d in "$dir"/*/README.md; do
    [ ! -f "$d" ] || sb_die 6 "the folder holds tasks: $vdir"
  done
  # The id is a task elsewhere: at the root, in a status folder or in the archive.
  other="$(sb_task_readme "$SB_P_DIR/$SB_TASKS_ROOT" "$id" | head -1)"
  case "$other" in
    "") ;;
    "$SB_P_DIR/$SB_TASKS_ROOT/archive/"*) sb_die 6 "the task is archived: $(sb_rel "$other")" ;;
    *) sb_die 6 "the task exists: $(sb_rel "$other")" ;;
  esac
  other="$(sb_task_files "$SB_P_DIR/$SB_TASKS_ROOT" | sb_alias_scan "$id" | head -1)"
  [ -z "$other" ] || sb_die 6 "$id is already an alias of $(sb_rel "$other")"
  [ -z "$repo" ] || sb_need_repo "$repo"
  if [ "$envs" -eq 1 ]; then
    envlist="$(sb_fm_list "$SB_P_PROFILE" environments)"
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
  # The fill makes each folder missing on the way to the task folder, such as planned/ in a status
  # project or the tasks root itself: made is the outermost of them, empty when the folder exists.
  made=""
  d="$dir"
  while [ -n "$d" ] && [ ! -d "$d" ]; do
    made="$d"
    d="${d%/*}"
  done
  sb_fill task-readme.md.tmpl "$file" "ID=$id" "TITLE=$title" "TOPIC_TAGS=$taglines" "UP_LINK=$uplink" || rc=$?
  [ "$rc" -ne 6 ] || sb_die 6 "the task README exists: $vdir/README.md"
  [ "$rc" -eq 0 ] || sb_die 1 "cannot write $vdir/README.md"
  # A project's own template may give no frontmatter, which every task command needs: write nothing.
  if ! LC_ALL=C awk '
    { sub(/\r$/, "") }
    NR == 1 { sub(/^\357\273\277/, ""); if ($0 != "---") exit 1; next }
    $0 == "---" { found = 1; exit }
    END { exit(found ? 0 : 1) }' "$file"; then
    rm -f "$file"
    if [ -n "$made" ]; then
      d="$dir"
      while rmdir "$d" 2>/dev/null && [ "$d" != "$made" ]; do d="${d%/*}"; done
    fi
    sb_die 5 "the README filled from $(sb_template_shown task-readme.md.tmpl) has no frontmatter: start the template with it, as the plugin's has"
  fi
  sb_fm_set_raw "$file" title "$(sb_yaml_quote "$title" 1)"
  [ "$(sb_yaml_quote "$id")" = "$id" ] || sb_fm_edit "$file" listswap aliases "$id" "$id"
  [ -z "$repo" ] || sb_fm_set "$file" repo "$SB_R_NAME"
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

# sb_task_status_dir <status> [parent]: print the vault path of the folder of the task in SB_T_ID
# for a status, in the status layout: <project>/<tasks_root>/<status>/<ID>, or
# <project>/<tasks_root>/<status>/<parent>/<ID> for a child of the task whose folder is <parent>.
sb_task_status_dir() {
  printf '%s\n' "$SB_P_PATH/$SB_TASKS_ROOT/$1/${2:+$2/}$SB_T_ID"
}

# sb_task_sprint_dir <sprint id or empty> [parent]: print the vault path of the folder of the task
# in SB_T_ID for a sprint, in the sprint layout: <project>/<tasks_root>/backlog/<ID> for no sprint,
# else <project>/<tasks_root>/<the sprint's folder>/<ID>, named by sb_sprint_folder, with
# <parent>/ before <ID> for a child. Exit 5 as sb_sprint_folder does.
sb_task_sprint_dir() {
  local folder=backlog
  if [ -n "$1" ]; then folder="$(sb_sprint_folder "$1")" || exit $?; fi
  printf '%s\n' "$SB_P_PATH/$SB_TASKS_ROOT/$folder/${2:+$2/}$SB_T_ID"
}

# sb_task_children <README>: print the folder name of each child task inside the folder of a task,
# one per line: a folder in it whose README.md has an epic that names the task.
sb_task_children() {
  local d="${1%/README.md}" c rows="" tab=$'\t' nl=$'\n'
  for c in "$d"/*/README.md; do [ -f "$c" ] && rows="${rows}C$tab$c$nl"; done
  [ -n "$rows" ] || return 0
  printf '%s' "$rows" | sb_task_kids | while IFS= read -r c; do
    c="${c%/README.md}"
    printf '%s\n' "${c##*/}"
  done
}

# sb_task_own <README>: print the name of each entry of the folder of a task that is its own, one
# per line, README.md first: every entry but its children's folders, a name with a dot first too.
sb_task_own() {
  local d="${1%/README.md}" e kids
  kids="$(sb_task_children "$1")"
  [ ! -e "$d/README.md" ] || printf 'README.md\n'
  for e in "$d"/* "$d"/.[!.]* "$d"/..?*; do
    [ -e "$e" ] || [ -L "$e" ] || continue
    e="${e##*/}"
    [ "$e" != "README.md" ] || continue
    if [ -n "$kids" ] && printf '%s\n' "$kids" | grep -qxF -- "$e"; then continue; fi
    printf '%s\n' "$e"
  done
}

# sb_task_kin <dest> <README>: return 0 when the vault path dest is a folder that holds tasks, with
# no README.md of its own and no link, that holds a child of the task whose README is given.
sb_task_kin() {
  local d="$SB_ROOT/$1" c rows="" name tab=$'\t' nl=$'\n'
  [ -d "$d" ] && [ ! -L "$d" ] && [ ! -e "$d/README.md" ] && [ ! -L "$d/README.md" ] || return 1
  name="${2%/README.md}"
  name="${name##*/}"
  for c in "$d"/*/README.md; do [ -f "$c" ] && rows="${rows}C$tab$c$tab$2$tab$name$nl"; done
  [ -n "$rows" ] && [ -n "$(printf '%s' "$rows" | sb_task_kids)" ]
}

# sb_task_dest_free <dest> [<README>]: exit 6 when anything is at the vault path dest, a link
# included, even a dead one: move would put a task folder inside a folder that is there already,
# under its own name. With the README of the task that moves, a folder that holds one of its
# children is no obstacle: its own entries go in beside them, each to a place that must be free.
sb_task_dest_free() {
  local e
  if [ -e "$SB_ROOT/$1" ] || [ -L "$SB_ROOT/$1" ]; then
    if [ -z "${2:-}" ] || ! sb_task_kin "$1" "$2"; then sb_die 6 "the destination exists: $1"; fi
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      if [ -e "$SB_ROOT/$1/$e" ] || [ -L "$SB_ROOT/$1/$e" ]; then sb_die 6 "the destination exists: $1/$e"; fi
    done <<EOF
$(sb_task_own "$2")
EOF
  fi
  return 0
}

# sb_task_sprint_dest_free <dest> [<README>]: for the vault path dest of a task in a sprint's
# folder, exit 6 when that folder is a task, one with a README.md of its own, then as
# sb_task_dest_free does. The sprint's folder is the first folder of dest below the tasks root, so
# a child's parent folder may be a task. backlog/ is no sprint's folder: its README.md is in no
# task's way.
sb_task_sprint_dest_free() {
  local folder="${1#"$SB_P_PATH/$SB_TASKS_ROOT/"}"
  folder="$SB_P_PATH/$SB_TASKS_ROOT/${folder%%/*}"
  [ ! -f "$SB_ROOT/$folder/README.md" ] || sb_die 6 "the sprint folder is a task: $folder"
  sb_task_dest_free "$1" "${2:-}"
}

# sb_task_links <from> <dest> <entries>: read the output of the moves of the entries of a task's
# folder, one at a time, on stdin; print one links: line per note, its counts added up, with the
# path of a note inside a moved entry at its new place.
sb_task_links() {
  LC_ALL=C SB_F="$1" SB_D="$2" SB_M="$3" awk '
    BEGIN { f = ENVIRON["SB_F"]; d = ENVIRON["SB_D"]; n = split(ENVIRON["SB_M"], m, "\n") }
    /^links: / {
      line = substr($0, 8); i = index(line, " | ")
      if (i == 0) next
      p = substr(line, 1, i - 1); c = substr(line, i + 3) + 0
      for (k = 1; k <= n; k++) {
        if (m[k] == "") continue
        e = f "/" m[k]
        if (p == e || substr(p, 1, length(e) + 1) == e "/") { p = d substr(p, length(f) + 1); break }
      }
      if (!(p in cnt)) order[++no] = p
      cnt[p] += c
    }
    END { for (k = 1; k <= no; k++) print "links: " order[k] " | " cnt[order[k]] }'
}

# sb_task_relocate <dest>: move the folder of the task in SB_T_FILE to the vault path dest through
# the move code, which rewrites every link into it. Exit 6 when anything is at dest. In a status or
# sprint project, a task that holds children moves its own entries alone, one at a time, and dest
# may be a folder that holds one of its children. A move that fails while the README is still
# where it was returns its code, with nothing changed. Otherwise SB_T_FILE and SB_T_REL name the
# README at dest, which is printed, then the move's links: lines; a task that leaves the archive
# loses its archived key. In a status or sprint project, a folder that held the task one level
# deeper in a group folder, with no README.md of its own, is removed when the move leaves it
# empty, and printed as removed: <path>. Returns the move's code.
sb_task_relocate() {
  local dest="$1" from out="" o rc=0 archive layout kids="" own e moved="" held r nl=$'\n'
  from="${SB_T_REL%/*}"
  layout="$(sb_task_layout)"
  case "$layout" in
    status | sprint)
      sb_task_dest_free "$dest" "$SB_T_FILE"
      kids="$(sb_task_children "$SB_T_FILE")"
      ;;
    *) sb_task_dest_free "$dest" ;;
  esac
  if [ -z "$kids" ] && [ ! -e "$SB_ROOT/$dest" ] && [ ! -L "$SB_ROOT/$dest" ]; then
    out="$(cmd_move -- "$from" "$dest")" || rc=$?
    if [ "$rc" -ne 0 ] && [ -e "$SB_ROOT/$from" ]; then return "$rc"; fi
  else
    own="$(sb_task_own "$SB_T_FILE")"
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      case "$e" in
        .*)
          # move takes no name with a dot first, and no link leads into one: it moves as it is.
          if [ -e "$SB_ROOT/$dest/$e" ] || [ -L "$SB_ROOT/$dest/$e" ] ||
            ! mv -n "$SB_ROOT/$from/$e" "$SB_ROOT/$dest/$e" 2>/dev/null ||
            [ -e "$SB_ROOT/$from/$e" ] || [ -L "$SB_ROOT/$from/$e" ]; then
            printf 'second-brain: cannot move %s to %s\n' "$from/$e" "$dest/$e" >&2
            rc=1
            break
          fi
          ;;
        *)
          o="$(cmd_move -- "$from/$e" "$dest/$e")" || rc=$?
          out="$out$o$nl"
          [ "$rc" -eq 0 ] || break
          ;;
      esac
      moved="$moved$e$nl"
    done <<EOF
$own
EOF
    if [ "$rc" -ne 0 ] && [ -e "$SB_ROOT/$from/README.md" ]; then return "$rc"; fi
    out="$(printf '%s' "$out" | sb_task_links "$from" "$dest" "$moved")"
    # The folder it left holds its children, or nothing, and then it goes.
    rmdir "$SB_ROOT/$from" 2>/dev/null || true
  fi
  SB_T_FILE="$SB_ROOT/$dest/README.md"
  SB_T_REL="$dest/README.md"
  printf '%s\n' "$SB_T_REL"
  printf '%s\n' "$out" | grep '^links: ' || true
  archive="$SB_P_PATH/$SB_TASKS_ROOT/archive/"
  case "$from/" in
    "$archive"*)
      case "$dest/" in
        "$archive"*) ;;
        *) sb_fm_set "$SB_T_FILE" archived "" || sb_die 1 "moved the task, but cannot edit $SB_T_REL" ;;
      esac
      ;;
  esac
  # A folder one level deeper in a group folder that held the task alone, and no README.md.
  case "$layout" in
    status | sprint)
      r="${from#"$SB_P_PATH/$SB_TASKS_ROOT/"}"
      held="${from%/*}"
      case "$r" in
        archive/* | */*/*/*) ;;
        */*/*)
          if [ -d "$SB_ROOT/$held" ] && [ ! -L "$SB_ROOT/$held" ] && [ ! -e "$SB_ROOT/$held/README.md" ] &&
            rmdir "$SB_ROOT/$held" 2>/dev/null; then
            printf 'removed: %s\n' "$held"
          fi
          ;;
      esac
      ;;
  esac
  return "$rc"
}

# sb_task_to_status <ID> <project> [<parent>]: for the doctor's fix, move a task of a status
# project to the folder of its status, a child into its parent's folder there, through
# sb_task_relocate, and print what it prints. The parent is the folder name sb_task_parent
# prints, given by a fix that read it for every task at once; with none it is read here. Nothing
# when the task is there already. Exit 5 when its status is none of the five.
sb_task_to_status() {
  local status dest parent="${3-}"
  sb_need_task "$1" "$2"
  status="$(sb_fm_get "$SB_T_FILE" status)" || status=""
  case "$status" in
    planned | in-progress | in-review | done | abandoned) ;;
    *) sb_die 5 "$SB_T_ID has no status of the five: ${status:-none}" ;;
  esac
  [ $# -ge 3 ] || parent="$(sb_task_parent "$SB_T_FILE")" || parent=""
  dest="$(sb_task_status_dir "$status" "$parent")"
  [ "$dest" != "${SB_T_REL%/*}" ] || return 0
  sb_task_relocate "$dest"
}

# sb_task_to_sprint <ID> <project> [<parent>]: for the doctor's fix, move a task of a sprint
# project to the folder of its sprint, or to backlog/ with none, a child into its parent's folder
# there, through sb_task_relocate, and print what it prints. The parent is given or read as for
# sb_task_to_status. Nothing when the task is there already. Exit 5 when its sprint gives no
# folder name, and 6 when the destination is taken, or the sprint's folder is a task, with a
# README.md of its own.
sb_task_to_sprint() {
  local sprint dest parent="${3-}"
  sb_need_task "$1" "$2"
  sprint="$(sb_fm_get "$SB_T_FILE" sprint)" || sprint=""
  [ $# -ge 3 ] || parent="$(sb_task_parent "$SB_T_FILE")" || parent=""
  dest="$(sb_task_sprint_dir "$sprint" "$parent")" || exit $?
  [ "$dest" != "${SB_T_REL%/*}" ] || return 0
  [ -z "$sprint" ] || sb_task_sprint_dest_free "$dest" "$SB_T_FILE"
  sb_task_relocate "$dest"
}

# Move a done or abandoned task to archive/<YYYY>/<ID>/ in its tasks folder through the move code,
# the year being today's, and date it in archived. Print its new path, then the move's links: lines.
# A task is archived once: exit 6 when it is in the archive already, exit 5 in a flat or status
# project.
sb_task_archive() {
  local id="" project="" layout status today from dest rc=0
  local usage="usage: second-brain task archive <ID> [--project P]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        [ $# -ge 2 ] || sb_die 5 "--project needs a value"
        project="$2"
        shift 2
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
  sb_need_task "$id" "$project"
  layout="$(sb_task_layout)"
  [ "$layout" = "archive" ] || sb_die 5 "$SB_P_NAME does not archive tasks (task_layout: $layout in its profile)"
  case "$SB_T_FILE" in "$SB_P_DIR/$SB_TASKS_ROOT/archive/"*) sb_die 6 "the task is archived already: $SB_T_REL" ;; esac
  status="$(sb_fm_get "$SB_T_FILE" status)"
  case "$status" in
    done | abandoned) ;;
    *) sb_die 5 "only a done or abandoned task is archived; $SB_T_ID is ${status:-without a status}" ;;
  esac
  today="$(sb_today)"
  from="${SB_T_REL%/*}"
  dest="$SB_P_PATH/$SB_TASKS_ROOT/archive/${today%%-*}/$SB_T_ID"
  sb_task_relocate "$dest" || rc=$?
  # A move that stopped before the folder left keeps the task as it was.
  if [ "$rc" -ne 0 ] && [ -e "$SB_ROOT/$from" ]; then return "$rc"; fi
  sb_fm_set "$SB_T_FILE" archived "$today" || sb_die 1 "moved the task, but cannot edit $SB_T_REL"
  return "$rc"
}

# Print each task that has unticked lines under "## Docs to update": its id and path, then the lines.
sb_task_docs() {
  local ids="" project="" id lines usage="usage: second-brain task docs <ID>[,<ID>...] [--project P]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        [ $# -ge 2 ] || sb_die 5 "--project needs a value"
        project="$2"
        shift 2
        ;;
      -*) sb_die 5 "$usage" ;;
      *)
        ids="$ids,$1"
        shift
        ;;
    esac
  done
  ids="$(printf '%s' "$ids" | tr ',' '\n' | grep -v '^$' || true)"
  [ -n "$ids" ] || sb_die 5 "$usage"
  # A line inside a fenced code block is an example, not a doc edit.
  while IFS= read -r id; do
    sb_need_task "$id" "$project"
    lines="$(sb_section "$SB_T_FILE" "Docs to update" |
      LC_ALL=C awk '/^[[:blank:]]*(```|~~~)/ { fence = !fence; next } !fence && /^[[:blank:]]*- \[ \]/')"
    [ -n "$lines" ] || continue
    printf '%s %s\n%s\n' "$SB_T_ID" "$SB_T_REL" "$lines"
  done <<EOF
$ids
EOF
}

# Dispatch the task subcommands.
cmd_task() {
  local sub="${1:-}"
  [ $# -gt 0 ] && shift
  case "$sub" in
    head) sb_task_head "$@" ;;
    docs) sb_task_docs "$@" ;;
    set) sb_task_set "$@" ;;
    new) sb_task_new "$@" ;;
    note) sb_task_note "$@" ;;
    tag) sb_task_tag "$@" ;;
    alias) sb_task_alias "$@" ;;
    dep) sb_task_dep "$@" ;;
    archive) sb_task_archive "$@" ;;
    *) sb_die 5 "usage: second-brain task head | docs | set | note | tag | alias | dep | new | archive <ID> ..." ;;
  esac
}
