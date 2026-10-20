#!/usr/bin/env bash
# sprint.sh - sprint notes: the one in progress, opening the next, closing with carry-over.

# Read file paths on stdin; print one TSV row per sprint note: path, id, status, start, end, goal.
sb_sprint_scan() {
  LC_ALL=C awk "$(sb_awk_lib)"'
    function clean(s) { gsub(/[\t\r]/, " ", s); return (s == "" ? "-" : s) }
    {
      path = $0
      if (path == "") next
      id = ""; status = ""; sstart = ""; send = ""; goal = ""; type = ""; lineno = 0; readable = 0
      while ((getline line < path) > 0) {
        readable = 1; lineno++
        sub(/\r$/, "", line)
        if (lineno == 1) { sub(/^\357\273\277/, "", line); if (line != "---") break; continue }
        if (line == "---") break
        if (line !~ /^[A-Za-z0-9_][A-Za-z0-9_-]*:/) continue
        i = index(line, ":"); key = substr(line, 1, i - 1); v = unq(substr(line, i + 1))
        if (key == "sprint") id = v
        else if (key == "status") status = v
        else if (key == "start") sstart = v
        else if (key == "end") send = v
        else if (key == "goal") goal = v
        else if (key == "type") type = v
      }
      close(path)
      if (!readable) next
      base = path; sub(/^.*\//, "", base); sub(/\.md$/, "", base)
      if (type != "sprint" && !date_ok(base)) next
      if (id == "") id = base
      print path "\t" clean(id) "\t" clean(status) "\t" clean(sstart) "\t" clean(send) "\t" clean(goal)
    }
  '
}

# Print the sprint notes of a folder, one absolute path per line.
sb_sprint_files() {
  local f
  for f in "$1"/*.md; do
    [ -f "$f" ] || continue
    case "$f" in */README.md) continue ;; esac
    printf '%s\n' "$f"
  done
}

# Print the scan row of the sprint in progress for a project path; nothing when there is none.
sb_sprint_current_row() {
  local dir
  dir="$SB_ROOT/$1/$(sb_setting "$1" sprints_root sprints)"
  [ -d "$dir" ] || return 0
  sb_sprint_files "$dir" | sb_sprint_scan | awk -F'\t' '$3 == "in-progress"' | LC_ALL=C sort -t "$(printf '\t')" -k2,2 | tail -1
}

# Print the id of the sprint in progress for a project path.
sb_sprint_current_id() {
  sb_sprint_current_row "$1" | awk -F'\t' '{ print $2 }'
}

# Print the sprint length in days from the profile; 14 when it is missing or not a number.
sb_sprint_length() {
  local n
  n="$(sb_setting "$SB_P_PATH" sprint_length_days 14)"
  case "$n" in '' | *[!0-9]* | 0) n=14 ;; esac
  printf '%s\n' "$n"
}

# Print the sprint in progress: id, start, end, days left, goal.
sb_sprint_current() {
  local row
  [ $# -eq 1 ] || sb_die 5 "usage: second-brain sprint current <project>"
  sb_need_project "$1"
  sb_need_sprints
  row="$(sb_sprint_current_row "$SB_P_PATH")"
  [ -n "$row" ] || sb_die 1 "no sprint is in progress for $SB_P_NAME"
  printf '%s\n' "$row" | LC_ALL=C SB_T="$(sb_today)" awk -F'\t' "$(sb_awk_lib)"'
    {
      left = "-"
      if (date_ok($5) && date_ok(ENVIRON["SB_T"])) left = date_days($5) - date_days(ENVIRON["SB_T"])
      print $2 "\t" $4 "\t" $5 "\t" left "\t" $6
    }'
}

# Print the sprint the cadence gives next for the current project: id, start, end.
# It is the first cadence end on or after today that has no note. Returns 1 with no anchor.
sb_sprint_next_row() {
  local len anchor end tries=0
  len="$(sb_sprint_length)"
  anchor="$(sb_setting "$SB_P_PATH" sprint_anchor_end "")"
  sb_date_ok "$anchor" || return 1
  end="$(LC_ALL=C SB_A="$anchor" SB_T="$(sb_today)" SB_L="$len" awk "$(sb_awk_lib)"'BEGIN {
    a = date_days(ENVIRON["SB_A"]); t = date_days(ENVIRON["SB_T"]); len = ENVIRON["SB_L"] + 0
    k = (t - a) / len
    if (k != int(k)) k = (k > 0 ? int(k) + 1 : int(k))
    print civil_from_days(a + k * len)
  }')"
  while [ -e "$SB_P_DIR/$SB_SPRINTS_ROOT/$end.md" ] && [ "$tries" -lt 60 ]; do
    end="$(sb_date_add "$end" "$len")"
    tries=$((tries + 1))
  done
  printf '%s\t%s\t%s\n' "$end" "$(sb_date_add "$end" "$((1 - len))")" "$end"
}

# Print what sprint open would create with no end date: id, start, end.
sb_sprint_next() {
  [ $# -eq 1 ] || sb_die 5 "usage: second-brain sprint next <project>"
  sb_need_project "$1"
  sb_need_profile
  sb_need_sprints
  sb_sprint_next_row || sb_die 1 "the profile has no sprint_anchor_end; open the first sprint with --end YYYY-MM-DD"
}

# Set goal or committed on the sprint in progress; print the changed keys.
sb_sprint_set() {
  local project="" kv key value out="" n=0 i=0 row note tab=$'\t'
  local pairs
  local usage="usage: second-brain sprint set <project> goal=<text> committed=<n>"
  pairs=()
  while [ $# -gt 0 ]; do
    case "$1" in
      *=*)
        [ -n "$project" ] || sb_die 5 "$usage"
        pairs[$n]="$1"
        n=$((n + 1))
        ;;
      -*) sb_die 5 "$usage" ;;
      *)
        [ -z "$project" ] || sb_die 5 "$usage"
        project="$1"
        ;;
    esac
    shift
  done
  if [ -z "$project" ] || [ "$n" -eq 0 ]; then sb_die 5 "$usage"; fi
  while [ "$i" -lt "$n" ]; do
    kv="${pairs[$i]}"
    key="${kv%%=*}"
    value="${kv#*=}"
    case "$key" in
      goal) ;;
      committed)
        case "$value" in '' | *[!0-9]*) sb_die 5 "committed is a whole number: $value" ;; esac
        ;;
      *) sb_die 5 "sprint set changes goal and committed only, not $key" ;;
    esac
    i=$((i + 1))
  done
  sb_need_project "$project"
  sb_need_sprints
  row="$(sb_sprint_current_row "$SB_P_PATH")"
  [ -n "$row" ] || sb_die 1 "no sprint is in progress for $SB_P_NAME"
  note="${row%%"$tab"*}"
  i=0
  while [ "$i" -lt "$n" ]; do
    kv="${pairs[$i]}"
    key="${kv%%=*}"
    value="$(printf '%s' "${kv#*=}" | tr '\n\r\t' '   ')"
    if [ "$key" = "goal" ]; then
      sb_fm_set_raw "$note" goal "$(sb_yaml_quote "$value" 1)"
    else
      sb_fm_set_raw "$note" committed "$value"
    fi
    [ "$SB_FM_CHANGED" -eq 0 ] || out="$out$key: ${value:--}"$'\n'
    i=$((i + 1))
  done
  if [ -n "$out" ]; then printf '%s' "$out"; else printf 'no change\n'; fi
}

# Print folder ids for a comma list of task ids or aliases; an unknown name is kept as given.
sb_sprint_ids() {
  local list="$1" dir="$SB_P_DIR/$SB_TASKS_ROOT" out="" name hit nl=$'\n'
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ -z "$(sb_task_readme "$dir" "$name")" ]; then
      hit="$(sb_task_files "$dir" | sb_alias_scan "$name")"
      case "$hit" in
        '' | *"$nl"*) ;;
        *) name="$(basename "$(dirname "$hit")")" ;;
      esac
    fi
    out="$out${out:+,}$name"
  done <<EOF
$(printf '%s\n' "$list" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
EOF
  printf '%s\n' "$out"
}

# Rewrite the sprint literal of the board view named Current sprint; return 1 when it has none.
sb_board_set_sprint() {
  local file="$1" id="$2" tmp rc=0
  [ -f "$file" ] || return 1
  tmp="$(mktemp "${TMPDIR:-/tmp}/sb-base.XXXXXX")" || return 1
  LC_ALL=C SB_ID="$id" awk '
    BEGIN { id = ENVIRON["SB_ID"]; inview = 0; done = 0 }
    {
      raw = $0; line = raw; sub(/\r$/, "", line)
      eol = (raw != line) ? "\r" : ""
      if (line ~ /^[ \t]*-[ \t]+(type|name):/) inview = 0
      if (line ~ /^[ \t]*(-[ \t]+)?name:[ \t]*["\047]?Current sprint["\047]?[ \t]*$/) inview = 1
      if (inview && !done && line ~ /sprint[ \t]*==/) {
        i = index(line, "==")
        head = substr(line, 1, i + 1); rest = substr(line, i + 2)
        a = index(rest, "\"")
        if (a > 0) {
          b = index(substr(rest, a + 1), "\"")
          if (b > 0) { rest = substr(rest, 1, a) id substr(rest, a + b); done = 1 }
        }
        print head rest eol
        next
      }
      print raw
    }
    END { exit(done ? 0 : 1) }
  ' "$file" >"$tmp" || rc=1
  if [ "$rc" -eq 0 ] && ! sb_same_file "$tmp" "$file"; then cat "$tmp" >"$file"; fi
  rm -f "$tmp"
  return "$rc"
}

# Open the next sprint: note, hub line and the board literal. Exit 6 while one is in progress.
sb_sprint_open() {
  local project="" end="" goal="" given=0 len anchor cur dir note hub alias uplink start line row
  local known moved="" file tid old tab=$'\t'
  local usage="usage: second-brain sprint open <project> [--end YYYY-MM-DD] [--goal G]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --end | --goal)
        [ $# -ge 2 ] || sb_die 5 "$1 needs a value"
        if [ "$1" = "--end" ]; then end="$2"; else goal="$2"; fi
        shift 2
        ;;
      -*) sb_die 5 "$usage" ;;
      *)
        [ -z "$project" ] || sb_die 5 "$usage"
        project="$1"
        shift
        ;;
    esac
  done
  [ -n "$project" ] || sb_die 5 "$usage"
  sb_need_project "$project"
  sb_need_profile
  sb_need_sprints
  len="$(sb_sprint_length)"
  anchor="$(sb_setting "$SB_P_PATH" sprint_anchor_end "")"
  dir="$SB_P_DIR/$SB_SPRINTS_ROOT"
  cur="$(sb_sprint_current_id "$SB_P_PATH")"
  [ -z "$cur" ] || sb_die 6 "sprint $cur is still in progress; close it first"
  if [ -n "$end" ]; then
    given=1
    sb_date_ok "$end" || sb_die 5 "--end needs a real date, YYYY-MM-DD: $end"
  else
    row="$(sb_sprint_next_row)" || sb_die 5 "the profile has no sprint_anchor_end; pass --end YYYY-MM-DD"
    end="${row%%"$tab"*}"
  fi
  note="$dir/$end.md"
  [ ! -e "$note" ] || sb_die 6 "the sprint note exists: $SB_P_PATH/$SB_SPRINTS_ROOT/$end.md"
  start="$(sb_date_add "$end" "$((1 - len))")"
  hub="$dir/README.md"
  alias="$(sb_fm_list "$hub" aliases 2>/dev/null | head -1)"
  [ -n "$alias" ] || alias="$SB_P_NAME Sprints Hub"
  uplink="[[$SB_P_PATH/$SB_SPRINTS_ROOT/README|$alias]]"
  sb_fill sprint-note.md.tmpl "$note" "PROJECT=$SB_P_NAME" "SPRINT_ID=$end" "START=$start" "END=$end" "UP_LINK=$uplink" ||
    sb_die 1 "cannot write $SB_P_PATH/$SB_SPRINTS_ROOT/$end.md"
  if [ -n "$goal" ]; then
    goal="$(printf '%s' "$goal" | tr '\n\r\t' '   ')"
    sb_fm_set_raw "$note" goal "$(sb_yaml_quote "$goal" 1)"
  fi
  line="- [[$SB_P_PATH/$SB_SPRINTS_ROOT/$end|$SB_P_NAME Sprint $end]] - $start to $end"
  if [ -f "$hub" ]; then
    if ! grep -qF "[[$SB_P_PATH/$SB_SPRINTS_ROOT/$end|" "$hub"; then
      sb_body_insert "$hub" "## Sprints" list "$line" || sb_body_append "$hub" "$line"
    fi
  else
    sb_note "no sprints hub at $SB_P_PATH/$SB_SPRINTS_ROOT/README.md; the link line was not added"
  fi
  sb_board_set_sprint "$SB_P_DIR/$SB_TASKS_ROOT/tasks.base" "$end" ||
    sb_note "the board at $SB_P_PATH/$SB_TASKS_ROOT/tasks.base has no Current sprint view to update"
  # The first sprint sets the cadence anchor; an anchor that is already there is never moved.
  if [ "$given" -eq 1 ] && ! sb_date_ok "$anchor"; then
    sb_fm_set "$SB_P_PROFILE" sprint_anchor_end "$end"
    sb_note "sprint_anchor_end in the profile is now $end"
  fi
  # Open tasks that point at a sprint with no note follow the sprint being opened.
  known="$(sb_sprint_files "$dir" | sb_sprint_scan | awk -F'\t' '{ print $2 }')"
  while IFS=$'\t' read -r file tid old; do
    [ -n "$file" ] || continue
    if printf '%s\n' "$known" | grep -qxF -- "$old"; then continue; fi
    sb_fm_set "$file" sprint "$end" || continue
    moved="${moved}re-pointed: $tid from $old to $end"$'\n'
  done <<EOF
$(sb_task_files "$SB_P_DIR/$SB_TASKS_ROOT" | sb_task_scan | awk -F'\t' '$4 != "-" && $3 != "done" && $3 != "abandoned" { print $1 "\t" $2 "\t" $4 }')
EOF
  sb_rel "$note"
  printf '%s' "$moved"
}

# Close the sprint in progress; every open task must be carried, sent to the backlog or abandoned.
# Status notes with the reason are left to the caller.
sb_sprint_close() {
  local project="" carry="" backlog="" abandon=""
  local row note id status start end goal len next plan problems action file tid title rest
  local done_ids="" carried_ids="" backlog_ids="" abandoned_ids="" text link nl=$'\n'
  local done_md="" carried_md="" backlog_md="" abandoned_md="" n_done=0 n_carried=0 n_backlog=0 n_abandoned=0
  local usage="usage: second-brain sprint close <project> [--carry ID,ID] [--backlog ID,ID] [--abandon ID,ID]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --carry | --backlog | --abandon)
        [ $# -ge 2 ] || sb_die 5 "$1 needs a value"
        case "$1" in
          --carry) carry="$carry,$2" ;;
          --backlog) backlog="$backlog,$2" ;;
          --abandon) abandon="$abandon,$2" ;;
        esac
        shift 2
        ;;
      -*) sb_die 5 "$usage" ;;
      *)
        [ -z "$project" ] || sb_die 5 "$usage"
        project="$1"
        shift
        ;;
    esac
  done
  [ -n "$project" ] || sb_die 5 "$usage"
  sb_need_project "$project"
  sb_need_sprints
  row="$(sb_sprint_current_row "$SB_P_PATH")"
  [ -n "$row" ] || sb_die 1 "no sprint is in progress for $SB_P_NAME"
  IFS=$'\t' read -r note id status start end goal <<EOF
$row
EOF
  sb_date_ok "$id" || sb_die 1 "the sprint id is not a date: $id"
  len="$(sb_sprint_length)"
  next="$(sb_sprint_next_row | awk -F'\t' '{ print $1 }')"
  [ -n "$next" ] || next="$(sb_date_add "$id" "$len")"
  carry="$(sb_sprint_ids "$carry")"
  backlog="$(sb_sprint_ids "$backlog")"
  abandon="$(sb_sprint_ids "$abandon")"
  plan="$(sb_task_files "$SB_P_DIR/$SB_TASKS_ROOT" | sb_task_scan |
    SB_ID="$id" SB_CARRY="$carry" SB_BACKLOG="$backlog" SB_ABANDON="$abandon" awk -F'\t' '
      function names(list, what,   n, a, i, x) {
        n = split(list, a, ",")
        for (i = 1; i <= n; i++) {
          x = a[i]; sub(/^[ \t]+/, "", x); sub(/[ \t]+$/, "", x)
          if (x == "") continue
          if (tolower(x) in act) print "twice\t-\t" x "\t-"
          act[tolower(x)] = what; named[tolower(x)] = x
        }
      }
      BEGIN {
        names(ENVIRON["SB_CARRY"], "carry"); names(ENVIRON["SB_BACKLOG"], "backlog"); names(ENVIRON["SB_ABANDON"], "abandon")
      }
      $4 == ENVIRON["SB_ID"] {
        if ($8 == "-") $8 = $12
        k = tolower($2); seen[k] = 1
        if ($3 == "done" || $3 == "abandoned") {
          if (k in act) print "closed\t-\t" $2 "\t-"
          else { what = ($3 == "done" ? "done" : "gone"); print what "\t" $1 "\t" $2 "\t" $8 }
        } else if (k in act) print act[k] "\t" $1 "\t" $2 "\t" $8
        else print "missing\t" $1 "\t" $2 "\t" $8 "\t" $3
      }
      END { for (k in act) if (!(k in seen)) print "unknown\t-\t" named[k] "\t-" }
    ')"
  problems="$(printf '%s\n' "$plan" | awk -F'\t' '$1 == "missing" { print $3 " | " $5 " | " $4 }')"
  if [ -n "$problems" ]; then
    printf '%s\n' "$problems"
    sb_die 5 "sprint $id has open tasks not named in --carry, --backlog or --abandon (listed above)"
  fi
  problems="$(printf '%s\n' "$plan" | awk -F'\t' '
    $1 == "twice" { print $3 " is named twice" }
    $1 == "closed" { print $3 " is already done or abandoned" }
    $1 == "unknown" { print $3 " is not a task of this sprint" }')"
  if [ -n "$problems" ]; then
    printf '%s\n' "$problems"
    sb_die 5 "sprint $id was not closed; fix the lists (problems listed above)"
  fi
  while IFS=$'\t' read -r action file tid title rest; do
    [ -n "$action" ] || continue
    link="${file#"$SB_ROOT"/}"
    link="- [[${link%.md}|$tid]]"
    [ "$title" = "-" ] || link="$link - $title"
    case "$action" in
      done)
        done_ids="$done_ids${done_ids:+, }$tid"
        done_md="$done_md$link$nl"
        n_done=$((n_done + 1))
        ;;
      gone)
        abandoned_ids="$abandoned_ids${abandoned_ids:+, }$tid"
        abandoned_md="$abandoned_md$link$nl"
        n_abandoned=$((n_abandoned + 1))
        ;;
      carry)
        sb_fm_edit "$file" listadd carried_from "$id" 1
        sb_fm_set "$file" sprint "$next"
        carried_ids="$carried_ids${carried_ids:+, }$tid"
        carried_md="$carried_md$link$nl"
        n_carried=$((n_carried + 1))
        ;;
      backlog)
        sb_fm_set "$file" sprint ""
        backlog_ids="$backlog_ids${backlog_ids:+, }$tid"
        backlog_md="$backlog_md$link$nl"
        n_backlog=$((n_backlog + 1))
        ;;
      abandon)
        sb_fm_set "$file" status abandoned
        sb_fm_status_tag "$file" abandoned
        abandoned_ids="$abandoned_ids${abandoned_ids:+, }$tid"
        abandoned_md="$abandoned_md$link$nl"
        n_abandoned=$((n_abandoned + 1))
        ;;
    esac
  done <<EOF
$plan
EOF
  text="Closed $(sb_today)."
  [ -z "$done_md" ] || text="$text$nl${nl}Done:$nl$nl${done_md%"$nl"}"
  [ -z "$carried_md" ] || text="$text$nl${nl}Carried over to $next:$nl$nl${carried_md%"$nl"}"
  [ -z "$backlog_md" ] || text="$text$nl${nl}Back to backlog:$nl$nl${backlog_md%"$nl"}"
  [ -z "$abandoned_md" ] || text="$text$nl${nl}Abandoned:$nl$nl${abandoned_md%"$nl"}"
  text="$text$nl${nl}Counts: done $n_done, carried over $n_carried, backlog $n_backlog, abandoned $n_abandoned."
  sb_body_insert "$note" "## Close" after "$text" || sb_body_append "$note" "## Close$nl$nl$text"
  sb_fm_set_raw "$note" completed "$n_done"
  sb_fm_set_raw "$note" carried_over "$n_carried"
  sb_fm_set "$note" status done
  sb_fm_status_tag "$note" done
  printf 'sprint: %s\ndone: %s\ncarried: %s\nbacklog: %s\nabandoned: %s\nnext: %s\n' \
    "$id" "${done_ids:--}" "${carried_ids:--}" "${backlog_ids:--}" "${abandoned_ids:--}" "$next"
}

# Dispatch the sprint subcommands.
cmd_sprint() {
  local sub="${1:-}"
  [ $# -gt 0 ] && shift
  case "$sub" in
    current) sb_sprint_current "$@" ;;
    next) sb_sprint_next "$@" ;;
    open) sb_sprint_open "$@" ;;
    set) sb_sprint_set "$@" ;;
    close) sb_sprint_close "$@" ;;
    *) sb_die 5 "usage: second-brain sprint current | next | open | set | close <project> ..." ;;
  esac
}
