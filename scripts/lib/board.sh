#!/usr/bin/env bash
# board.sh - the task board: the views of the board file, read from task frontmatter.

# Print the task READMEs directly inside a tasks folder, one absolute path per line.
sb_task_files() {
  local f
  for f in "$1"/*/README.md; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
}

# Read file paths on stdin; print one TSV row of frontmatter per readable file.
# Fields: path, id, status, sprint, topics, branch, next, title, carried_from, type, envs, heading,
# depends_on. Empty is "-". envs is env:id:status,...; heading is the first heading, read when title
# is absent; depends_on is the vault paths its links lead to, without .md, comma separated.
sb_task_scan() {
  LC_ALL=C awk "$(sb_awk_lib)"'
    function clean(s) { gsub(/[\t\r]/, " ", s); return (s == "" ? "-" : s) }
    function additem(k, v) {
      if (v == "") return
      if (k == "tags") {
        sub(/^#/, "", v)
        if (substr(v, 1, 5) == "type/" || substr(v, 1, 7) == "status/") return
        topics = (topics == "" ? v : topics "," v)
      } else if (k == "carried_from") carried = (carried == "" ? v : carried "," v)
      else if (k == "depends_on") { v = dep_target(v); if (v != "") deps = (deps == "" ? v : deps "," v) }
    }
    {
      path = $0
      if (path == "") next
      status = ""; sprint = ""; branch = ""; nxt = ""; title = ""; type = ""; topics = ""; carried = ""; deps = ""
      envs = ""; h1 = ""; key = ""; lineno = 0; readable = 0; st = 0; after = 0
      n = split(path, part, "/")
      id = (n >= 2 ? part[n - 1] : path)
      while ((getline line < path) > 0) {
        readable = 1; lineno++
        sub(/\r$/, "", line)
        if (lineno == 1) {
          sub(/^\357\273\277/, "", line)
          if (line == "---") { st = 1; continue }
          st = 2
        }
        if (st == 2) {
          if (line ~ /^# /) {
            h1 = trim(substr(line, 3)); p = id " - "
            if (substr(h1, 1, length(p)) == p) h1 = substr(h1, length(p) + 1)
            break
          }
          if (++after > 12) break
          continue
        }
        if (line == "---") { if (title != "") break; st = 2; continue }
        if (line ~ /^[A-Za-z0-9_][A-Za-z0-9_-]*:/) {
          i = index(line, ":"); key = substr(line, 1, i - 1); v = trim(substr(line, i + 1))
          if (key == "status") status = unq(v)
          else if (key == "sprint") sprint = unq(v)
          else if (key == "branch") branch = unq(v)
          else if (key == "next") nxt = unq(v)
          else if (key == "title") title = unq(v)
          else if (key == "type") type = unq(v)
          else if (key == "tags" || key == "carried_from" || key == "depends_on") {
            if (substr(v, 1, 1) == "[") { n = split_inline(v, it); for (k = 1; k <= n; k++) additem(key, it[k]) }
            else additem(key, unq(v))
          }
          continue
        }
        if ((key == "tags" || key == "carried_from" || key == "depends_on") && line ~ /^[ \t]*-([ \t]|$)/) {
          v = line; sub(/^[ \t]*-[ \t]*/, "", v); additem(key, unq(v))
        } else if (key == "envs" && line ~ /^[ \t]+[^ \t#]/) {
          v = trim(line); i = index(v, ":")
          if (i > 1) envs = (envs == "" ? "" : envs ",") substr(v, 1, i - 1) ":" mapfield(substr(v, i + 1), "id") ":" mapfield(substr(v, i + 1), "status")
        }
      }
      close(path)
      if (!readable) next
      print path "\t" clean(id) "\t" clean(status) "\t" clean(sprint) "\t" clean(topics) "\t" clean(branch) "\t" clean(nxt) "\t" clean(title) "\t" clean(carried) "\t" clean(type) "\t" clean(envs) "\t" clean(h1) "\t" clean(deps)
    }
  '
}

# Read scan rows on stdin; turn the depends_on paths into id:status pairs. The id is the folder of
# the task README, as the scan spells it when the task is in it; the status comes from the scan, or
# from the note, or is "missing" with no note.
sb_board_deps() {
  LC_ALL=C SB_R="$SB_ROOT/" awk -F'\t' "$(sb_awk_lib)"'
    function rel(p) { if (substr(p, 1, length(root)) == root) p = substr(p, length(root) + 1); sub(/\.md$/, "", p); return tolower(p) }
    function status_of(t,   f, l, n, st) {
      if (tolower(t) in st_of) return st_of[tolower(t)]
      f = root t ".md"; n = 0; st = "missing"
      # A path that leaves the vault is never opened.
      if (("/" t "/") ~ /\/\.\.\// || index(t, "\\") || substr(t, 1, 1) == "/") return st
      while ((getline l < f) > 0) {
        n++; sub(/\r$/, "", l)
        if (n == 1) { sub(/^\357\273\277/, "", l); st = "-"; if (l != "---") break; continue }
        if (l == "---") break
        if (l ~ /^status:/) { st = unq(substr(l, 8)); if (st == "") st = "-"; break }
      }
      close(f)
      st_of[tolower(t)] = st
      return st
    }
    BEGIN { OFS = "\t"; root = ENVIRON["SB_R"] }
    { row[NR] = $0; st_of[rel($1)] = $3; id_of[rel($1)] = $2 }
    END {
      for (r = 1; r <= NR; r++) {
        $0 = row[r]
        if ($13 != "-" && $13 != "") {
          m = split($13, d, ","); out = ""
          for (i = 1; i <= m; i++) {
            k = split(d[i], seg, "/"); did = seg[k]
            if (k >= 2 && tolower(did) == "readme") did = seg[k - 1]
            if (tolower(d[i]) in id_of) did = id_of[tolower(d[i])]
            out = out (i > 1 ? "," : "") did ":" status_of(d[i])
          }
          $13 = out
        }
        print
      }
    }'
}

# Read scan rows on stdin; keep the rows of one view, sorted the way the view sorts.
sb_board_filter() {
  SB_VIEW="$1" SB_SPRINT="${2:-}" awk -F'\t' '
    function active(s) { return (s == "planned" || s == "in-progress" || s == "in-review") }
    function known(s) { return (active(s) || s == "done" || s == "abandoned") }
    BEGIN { view = ENVIRON["SB_VIEW"]; cur = ENVIRON["SB_SPRINT"] }
    {
      keep = 0; k = $3 "\t" $2
      if (view == "Active") keep = active($3)
      else if (view == "All") keep = 1
      else if (view == "Needs a status") { keep = !known($3); k = $2 }
      else if (view == "Current sprint") keep = (cur != "" && $4 == cur)
      else if (view == "By topic") {
        keep = active($3)
        t = $5; sub(/,.*$/, "", t)
        k = (t == "-" ? "~" : t) "\t" $2
      }
      if (keep) print k "\034" $0
    }
  ' | LC_ALL=C sort | awk '{ i = index($0, "\034"); print substr($0, i + 1) }'
}

# Read scan rows on stdin; print board rows:
# id | title | status | sprint | topics | branch | next | envs | depends_on.
sb_board_rows() {
  awk -F'\t' '
    function cell(s) { gsub(/\|/, "/", s); return s }
    {
      title = ($8 != "-" ? $8 : $12)
      print cell($2) " | " cell(title) " | " cell($3) " | " cell($4) " | " cell($5) " | " cell($6) " | " cell($7) " | " cell($11) " | " cell($13)
    }
  '
}

# Print a view name in its exact spelling, or return 1.
sb_board_view() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    '' | active) printf 'Active\n' ;;
    'current sprint' | current | sprint) printf 'Current sprint\n' ;;
    'by topic' | topic | topics) printf 'By topic\n' ;;
    'needs a status' | needs | 'needs status') printf 'Needs a status\n' ;;
    all) printf 'All\n' ;;
    *) return 1 ;;
  esac
}

# Print the sprint id the board's Current sprint view filters on; nothing when it has none.
sb_board_sprint_literal() {
  [ -f "$1" ] || return 0
  LC_ALL=C awk '
    { line = $0; sub(/\r$/, "", line) }
    line ~ /^[ \t]*-[ \t]+(type|name):/ { inview = 0 }
    line ~ /^[ \t]*(-[ \t]+)?name:[ \t]*["\047]?Current sprint["\047]?[ \t]*$/ { inview = 1 }
    inview && line ~ /sprint[ \t]*==/ {
      i = index(line, "=="); rest = substr(line, i + 2)
      a = index(rest, "\""); if (a == 0) exit
      rest = substr(rest, a + 1)
      b = index(rest, "\""); if (b == 0) exit
      print substr(rest, 1, b - 1)
      exit
    }
  ' "$1"
}

# Print a project's board for one view, from the frontmatter of its task READMEs.
cmd_board() {
  local project="" view="" dir cur=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -*) sb_die 5 "usage: second-brain board <project> [view]" ;;
      *)
        if [ -z "$project" ]; then project="$1"; else view="${view:+$view }$1"; fi
        ;;
    esac
    shift
  done
  [ -n "$project" ] || sb_die 5 "usage: second-brain board <project> [view]"
  view="$(sb_board_view "$view")" || sb_die 5 "unknown view (views: Active, Current sprint, By topic, Needs a status, All)"
  sb_need_project "$project"
  dir="$SB_P_DIR/$SB_TASKS_ROOT"
  [ -d "$dir" ] || sb_die 1 "no tasks folder at $SB_P_PATH/$SB_TASKS_ROOT"
  if [ "$view" = "Current sprint" ]; then
    # Sprints turned off: a sprint note left in progress lists nothing.
    ! sb_uses_sprints "$SB_P_PATH" || cur="$(sb_sprint_current_id "$SB_P_PATH")"
    [ -n "$cur" ] || return 0
  fi
  sb_task_files "$dir" | sb_task_scan | sb_board_deps | sb_board_filter "$view" "$cur" | sb_board_rows
  return 0
}

# Print the task READMEs that carry a topic tag or one of its sub-tags.
cmd_topic() {
  local project="${1:-}" tag="${2:-}" dir hits
  if [ -z "$project" ] || [ -z "$tag" ] || [ $# -gt 2 ]; then
    sb_die 5 "usage: second-brain topic <project> <tag>"
  fi
  sb_need_project "$project"
  dir="$SB_P_DIR/$SB_TASKS_ROOT"
  [ -d "$dir" ] || sb_die 1 "no tasks folder at $SB_P_PATH/$SB_TASKS_ROOT"
  hits="$(sb_task_files "$dir" | sb_task_scan | SB_TAG="$tag" SB_R="$SB_ROOT" awk -F'\t' '
    BEGIN { tag = tolower(ENVIRON["SB_TAG"]); sub(/^#/, "", tag); sub(/\/+$/, "", tag); root = ENVIRON["SB_R"] "/" }
    {
      n = split(tolower($5), t, ",")
      for (i = 1; i <= n; i++) if (t[i] == tag || substr(t[i], 1, length(tag) + 1) == tag "/") {
        p = $1
        if (substr(p, 1, length(root)) == root) p = substr(p, length(root) + 1)
        print p
        break
      }
    }')"
  [ -n "$hits" ] || sb_die 1 "no task carries the topic tag: $tag"
  printf '%s\n' "$hits"
}
