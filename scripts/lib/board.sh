#!/usr/bin/env bash
# board.sh - the task board: the views of the board file, read from task frontmatter.

# The five status folders of a tasks folder in the status layout, in this order.
SB_TASK_STATUSES="planned in-progress in-review done abandoned"
# The folder names of a tasks folder that are never a task, so no task id: archive, the five status
# folders and backlog. Each but archive is a group folder by name, whatever it holds, in this order.
SB_TASK_RESERVED="archive $SB_TASK_STATUSES backlog"

# Print the task layout of the project in SB_P_PATH: flat, archive, status or sprint, from
# task_layout in any letter case. Another value, or no key, is flat. sprint is flat too when the
# profile turns sprints off with uses_sprints: false.
sb_task_layout() {
  local layout
  sb_lc "$(sb_setting "$SB_P_PATH" task_layout flat)"
  layout="$SB_LC"
  case "$layout" in
    archive | status) printf '%s\n' "$layout" ;;
    sprint) if sb_uses_sprints "$SB_P_PATH"; then printf 'sprint\n'; else printf 'flat\n'; fi ;;
    *) printf 'flat\n' ;;
  esac
}

# Print the group folders of a tasks folder, the folders that hold tasks, one absolute path per
# line: the five status folders in the order of SB_TASK_STATUSES, then backlog, then the others
# sorted, those that are there. In every layout. A folder directly inside the tasks folder with no
# README.md of its own holds tasks, such as a sprint's folder, 2026-12-04 or sprint-12; one with a
# README.md is a task. The names of SB_TASK_RESERVED are no task id, so the five and backlog hold
# tasks with a README too. archive keeps its own rule, archive/<YYYY>/<ID>/, and is no group folder.
sb_task_groups() {
  local d s others="" nl=$'\n'
  for s in $SB_TASK_RESERVED; do
    [ "$s" = archive ] || [ ! -d "$1/$s" ] || printf '%s\n' "$1/$s"
  done
  for d in "$1"/*/; do
    d="${d%/}"
    [ -d "$d" ] || continue
    for s in $SB_TASK_RESERVED; do [ "${d##*/}" != "$s" ] || continue 2; done
    [ -f "$d/README.md" ] || others="$others$d$nl"
  done
  # Two folders or more are sorted; one is printed as it is, with no sort started.
  case "$others" in
    *"$nl"?*) printf '%s' "$others" | LC_ALL=C sort ;;
    *) printf '%s' "$others" ;;
  esac
}

# Print the word the project in SB_P_PATH names its parent stories by: feature when the profile's
# parent_label is feature, in any letter case, else epic. The frontmatter key stays epic.
sb_parent_label() {
  sb_lc "$(sb_setting "$SB_P_PATH" parent_label epic)"
  case "$SB_LC" in
    feature) printf 'feature\n' ;;
    *) printf 'epic\n' ;;
  esac
}

# Read rows on stdin and print the README of each that is a task one level deeper in a group
# folder, in the order they come. A row "C<TAB><README>[<TAB><parent README><TAB><parent name>]" is
# one inside a task's folder: it is a child task when its epic names that task, by its folder name
# or an alias of its README, without letter case. With no parent fields, the parent is the task
# whose folder holds the folder of the README. A row "T<TAB><README>" is one in a folder with no
# README.md of its own: it is a task when that folder is named for a task found elsewhere, by its
# folder name or an alias, without letter case. A task found elsewhere is a row "S<TAB><README>",
# which is never printed, a child task the C rows find, or a task another T row finds.
sb_task_kids() {
  LC_ALL=C awk -F'\t' "$(sb_awk_lib)"'
    # The epic of a note, unquoted and in lower case; empty when it has none.
    function epic_of(path,   line, n, v) {
      n = 0; v = ""
      while ((getline line < path) > 0) {
        n++; sub(/\r$/, "", line)
        if (n == 1) { sub(/^\357\273\277/, "", line); if (line != "---") break; continue }
        if (line == "---") break
        if (line ~ /^epic:/) { v = unq(substr(line, 6)); break }
      }
      close(path)
      return tolower(v)
    }
    # 1 when the aliases of a note hold a name, compared in lower case; each note is read once.
    function aliased(path, want,   line, n, key, v, i, k, m, it) {
      if (!(path in seen)) {
        seen[path] = 1; n = 0; key = ""
        while ((getline line < path) > 0) {
          n++; sub(/\r$/, "", line)
          if (n == 1) { sub(/^\357\273\277/, "", line); if (line != "---") break; continue }
          if (line == "---") break
          if (line ~ /^[A-Za-z0-9_][A-Za-z0-9_-]*:/) {
            i = index(line, ":"); key = substr(line, 1, i - 1); v = trim(substr(line, i + 1))
            if (key != "aliases") continue
            if (substr(v, 1, 1) == "[") { m = split_inline(v, it); for (k = 1; k <= m; k++) al[path "\034" tolower(it[k])] = 1 }
            else if (v != "") al[path "\034" tolower(unq(v))] = 1
          } else if (key == "aliases" && line ~ /^[ \t]*-([ \t]|$)/) {
            v = line; sub(/^[ \t]*-[ \t]*/, "", v); al[path "\034" tolower(unq(v))] = 1
          }
        }
        close(path)
      }
      return ((path "\034" want) in al)
    }
    # The folder name of a README, and the name of the folder above that.
    function folder(path) { sub(/\/[^\/]*$/, "", path); sub(/^.*\//, "", path); return path }
    function above(path) { sub(/\/[^\/]*\/[^\/]*$/, "", path); sub(/^.*\//, "", path); return path }
    # A task found elsewhere: its folder name counts at once, its aliases once a holder needs them.
    function found(path) { name[tolower(folder(path))] = 1; src[++ns] = path }
    function named(h,   i, line, n, key, v, k, m, it, f) {
      if (h in name) return 1
      for (i = 1; i <= ns; i++) {
        f = src[i]
        if (f in loaded) continue
        loaded[f] = 1; n = 0; key = ""
        while ((getline line < f) > 0) {
          n++; sub(/\r$/, "", line)
          if (n == 1) { sub(/^\357\273\277/, "", line); if (line != "---") break; continue }
          if (line == "---") break
          if (line ~ /^[A-Za-z0-9_][A-Za-z0-9_-]*:/) {
            k = index(line, ":"); key = substr(line, 1, k - 1); v = trim(substr(line, k + 1))
            if (key != "aliases") continue
            if (substr(v, 1, 1) == "[") { m = split_inline(v, it); for (k = 1; k <= m; k++) aset[tolower(it[k])] = 1 }
            else if (v != "") aset[tolower(unq(v))] = 1
          } else if (key == "aliases" && line ~ /^[ \t]*-([ \t]|$)/) {
            v = line; sub(/^[ \t]*-[ \t]*/, "", v); aset[tolower(unq(v))] = 1
          }
        }
        close(f)
      }
      return (h in aset)
    }
    $1 == "S" { found($2); next }
    $1 == "T" { row[++nr] = $2; kind[nr] = "T"; next }
    $1 == "C" {
      pr = $3; pn = $4
      if (pr == "") {
        pr = $2; sub(/\/[^\/]*\/[^\/]*$/, "", pr)
        pn = pr; sub(/^.*\//, "", pn); pr = pr "/README.md"
      }
      row[++nr] = $2; kind[nr] = "C"
      e = epic_of($2)
      if (e == "" || e == "-") next
      if (e == tolower(pn) || aliased(pr, e)) { ok[nr] = 1; found($2) }
    }
    END {
      # A T row may lean on a task another T row finds: go round until none is added.
      do {
        more = 0
        for (i = 1; i <= nr; i++) {
          if (kind[i] != "T" || (i in ok)) continue
          if (named(tolower(above(row[i])))) { ok[i] = 1; found(row[i]); more = 1 }
        }
      } while (more)
      for (i = 1; i <= nr; i++) if (i in ok) print row[i]
    }'
}

# sb_task_nested <found> <group folder>...: print the task READMEs one level deeper in each group
# folder, one absolute path per line, in the order of the folders: in a task's folder, each
# <ID>/README.md whose epic names that task, a child task; in a folder with no README.md of its own
# that is named for a task found elsewhere, each <folder>/<ID>/README.md, as sb_task_kids says.
# <found> holds the task READMEs found at the shallower levels, one per line. In every layout.
sb_task_nested() {
  local g d c rows="" tab=$'\t' nl=$'\n' found="$1"
  shift
  for g in "$@"; do
    for d in "$g"/*/; do
      d="${d%/}"
      [ -d "$d" ] || continue
      for c in "$d"/*/README.md; do
        [ -f "$c" ] || continue
        if [ -f "$d/README.md" ]; then rows="${rows}C$tab$c$nl"; else rows="${rows}T$tab$c$nl"; fi
      done
    done
  done
  [ -z "$rows" ] || { printf '%s\n' "$found" | awk 'length($0) { print "S\t" $0 }'; printf '%s' "$rows"; } | sb_task_kids
}

# Print the task READMEs of a tasks folder, one absolute path per line: those directly inside it,
# then those in each group folder, <group>/<ID>/README.md, in the order of sb_task_groups, then
# those one level deeper in the group folders, as sb_task_nested lists them, then the archived
# ones, archive/<YYYY>/<ID>/README.md. In every layout. A folder named in SB_TASK_RESERVED is never
# a task.
sb_task_files() {
  local f g s groups list shallow="" archived="" nl=$'\n'
  list=()
  for f in "$1"/*/README.md; do
    for s in $SB_TASK_RESERVED; do [ "$f" != "$1/$s/README.md" ] || continue 2; done
    [ -f "$f" ] && shallow="$shallow$f$nl"
  done
  groups="$(sb_task_groups "$1")"
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    list[${#list[@]}]="$g"
    for f in "$g"/*/README.md; do [ -f "$f" ] && shallow="$shallow$f$nl"; done
  done <<EOF
$groups
EOF
  for f in "$1"/archive/[0-9][0-9][0-9][0-9]/*/README.md; do [ -f "$f" ] && archived="$archived$f$nl"; done
  printf '%s' "$shallow"
  [ "${#list[@]}" -eq 0 ] || sb_task_nested "$shallow$archived" "${list[@]}"
  printf '%s' "$archived"
  return 0
}

# The task READMEs of one tasks folder, listed once by a command that moves several of its tasks:
# SB_TASK_LIST_DIR is the folder and SB_TASK_LIST the READMEs, as sb_task_files prints them. A
# lookup that needs every task, such as one in a folder with no README.md, reads them from here.
SB_TASK_LIST_DIR=""
SB_TASK_LIST=""

# sb_task_list_keep <tasks folder>: list the tasks of a folder once, for sb_task_list.
sb_task_list_keep() {
  SB_TASK_LIST_DIR=""
  SB_TASK_LIST="$(sb_task_files "$1")"
  SB_TASK_LIST_DIR="$1"
}

# sb_task_list_drop: forget the kept list, once the tasks it names move.
sb_task_list_drop() {
  SB_TASK_LIST_DIR=""
  SB_TASK_LIST=""
}

# sb_task_list <tasks folder>: print the task READMEs of a folder as sb_task_files does, from the
# list sb_task_list_keep kept when it is that folder's.
sb_task_list() {
  if [ -n "${SB_TASK_LIST_DIR:-}" ] && [ "$1" = "$SB_TASK_LIST_DIR" ]; then
    [ -z "$SB_TASK_LIST" ] || printf '%s\n' "$SB_TASK_LIST"
    return 0
  fi
  sb_task_files "$1"
}

# Print the README of one task folder of a tasks folder: directly inside it, in a group folder, in
# the order of sb_task_groups, one level deeper in a group folder, as sb_task_nested takes it, or
# archived, in that order; nothing when it has none. A folder named in SB_TASK_RESERVED is never a
# task. One in a folder with no README.md of its own is a task when sb_task_files lists it.
sb_task_readme() {
  local f g s d rows="" held="" tab=$'\t' nl=$'\n' groups all
  f="$1/$2/README.md"
  for s in $SB_TASK_RESERVED; do [ "$f" != "$1/$s/README.md" ] || f=""; done
  [ -z "$f" ] || [ ! -f "$f" ] || printf '%s\n' "$f"
  groups="$(sb_task_groups "$1")"
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    [ ! -f "$g/$2/README.md" ] || printf '%s\n' "$g/$2/README.md"
    for f in "$g"/*/"$2"/README.md; do
      [ -f "$f" ] || continue
      d="${f%/*/README.md}"
      if [ -f "$d/README.md" ]; then rows="${rows}C$tab$f$nl"; else held="$held$f$nl"; fi
    done
  done <<EOF
$groups
EOF
  [ -z "$rows" ] || printf '%s' "$rows" | sb_task_kids
  # Whether a folder with no README holds tasks rests on every task found elsewhere.
  if [ -n "$held" ]; then
    all="$(sb_task_list "$1")"
    while IFS= read -r f; do
      [ -z "$f" ] || ! printf '%s\n' "$all" | grep -qxF -- "$f" || printf '%s\n' "$f"
    done <<EOF
$held
EOF
  fi
  for f in "$1"/archive/[0-9][0-9][0-9][0-9]/"$2"/README.md; do [ -f "$f" ] && printf '%s\n' "$f"; done
  return 0
}

# sb_task_parent <README> [<epic>]: print the folder name of the parent of a task, the task its
# epic names, or the epic given, by its folder name or an alias, without letter case, among the
# tasks of the tasks folder of the project in SB_P_DIR. Return 1 when the epic is empty, "-" or
# names the task itself alone, and 2 when it names no other task of the project, or several.
sb_task_parent() {
  local file="$1" epic files hits self=0 n
  if [ $# -ge 2 ]; then
    epic="$2"
  else
    epic="$(sb_fm_get "$file" epic 2>/dev/null)" || epic=""
  fi
  case "$epic" in '' | -) return 1 ;; esac
  files="$(sb_task_files "$SB_P_DIR/$SB_TASKS_ROOT")"
  hits="$({
    printf '%s\n' "$files" | LC_ALL=C SB_W="$epic" awk -F/ 'NF > 1 && tolower($(NF - 1)) == tolower(ENVIRON["SB_W"])'
    printf '%s\n' "$files" | sb_alias_scan "$epic"
  } | LC_ALL=C sort -u)"
  if printf '%s\n' "$hits" | grep -qxF -- "$file"; then self=1; fi
  hits="$(printf '%s\n' "$hits" | grep -vxF -- "$file" | grep . || true)"
  n="$(printf '%s' "$hits" | grep -c '' || true)"
  if [ "$n" -eq 1 ]; then
    hits="${hits%/README.md}"
    printf '%s\n' "${hits##*/}"
    return 0
  fi
  [ "$n" -ne 0 ] || [ "$self" -eq 0 ] || return 1
  return 2
}

# sb_task_parents [<field>]: read the task READMEs of a tasks folder, one per line, then a line
# that is \034 alone, then TSV rows whose first field, or the field given, is a task README. Print
# each row with one more field, the folder name sb_task_parent prints for that README among those
# tasks, or nothing where it prints none: an epic that is empty, "-", or names the task itself
# alone, no other task or several. The aliases of the tasks are read once, for every row, and
# only when a row's README has an epic.
sb_task_parents() {
  LC_ALL=C SB_F="${1:-1}" awk -F'\t' "$(sb_awk_lib)"'
    function named(name, f) { if (!((name SUBSEP f) in has)) { has[name SUBSEP f] = 1; hits[name] = hits[name] "\034" f } }
    # Each task by its folder name and by each alias, in lower case.
    function load(   i, f, p, np, al, a) {
      loaded = 1
      for (i = 1; i <= nf; i++) {
        f = file[i]
        np = split(f, p, "/")
        if (np > 1) named(tolower(p[np - 1]), f)
        split("", al)
        alias_set(f, al)
        for (a in al) named(a, f)
      }
    }
    # The task itself among the hits is no parent, and leaves none when it is the only one.
    function parent(self,   e, k, a, j, n, last) {
      e = fm_value(self, "epic")
      if (e == "" || e == "-") return ""
      if (!loaded) load()
      n = 0
      k = split(hits[tolower(e)], a, "\034")
      for (j = 2; j <= k; j++) if (a[j] != self) { n++; last = a[j] }
      if (n != 1) return ""
      k = split(last, a, "/")
      return a[k - 1]
    }
    BEGIN { at = ENVIRON["SB_F"] + 0 }
    $0 == "\034" && !part { part = 1; next }
    !part { if ($0 != "" && !($0 in listed)) { listed[$0] = 1; file[++nf] = $0 } next }
    { print $0 "\t" parent($at) }'
}

# sb_task_parent_in <rows> <README>: set SB_PARENT to the parent field of the README's row among
# rows that sb_task_parents printed for READMEs alone, "<README><TAB><parent>"; empty with none.
sb_task_parent_in() {
  local rest nl=$'\n' tab=$'\t'
  SB_PARENT=""
  case "$nl$1" in
    *"$nl$2$tab"*)
      rest="$nl$1"
      rest="${rest#*"$nl$2$tab"}"
      SB_PARENT="${rest%%"$nl"*}"
      ;;
  esac
}

# Read file paths on stdin; print one TSV row of frontmatter per readable file.
# Fields: path, id, status, sprint, topics, branch, next, title, carried_from, type, envs, heading,
# depends_on, subproject, epic. Empty is "-". envs is env:id:status,...; heading is the first heading,
# read when title is absent; depends_on is the vault paths its links lead to, without .md, comma
# separated.
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
      status = ""; sprint = ""; branch = ""; nxt = ""; title = ""; type = ""; topics = ""; carried = ""; deps = ""; subp = ""; epic = ""
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
          else if (key == "subproject") subp = unq(v)
          else if (key == "epic") epic = unq(v)
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
      print path "\t" clean(id) "\t" clean(status) "\t" clean(sprint) "\t" clean(topics) "\t" clean(branch) "\t" clean(nxt) "\t" clean(title) "\t" clean(carried) "\t" clean(type) "\t" clean(envs) "\t" clean(h1) "\t" clean(deps) "\t" clean(subp) "\t" clean(epic)
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

# Read scan rows on stdin; keep the rows of one view, sorted the way the view sorts. A third
# argument keeps only the tasks of that subproject, compared without letter case.
sb_board_filter() {
  SB_VIEW="$1" SB_SPRINT="${2:-}" SB_SUB="${3:-}" awk -F'\t' '
    function active(s) { return (s == "planned" || s == "in-progress" || s == "in-review") }
    function known(s) { return (active(s) || s == "done" || s == "abandoned") }
    BEGIN { view = ENVIRON["SB_VIEW"]; cur = ENVIRON["SB_SPRINT"]; want = tolower(ENVIRON["SB_SUB"]) }
    want != "" && tolower($14) != want { next }
    {
      keep = 0; k = $3 "\t" $2
      if (view == "Active") keep = active($3)
      else if (view == "All") keep = 1
      else if (view == "Needs a status") { keep = !known($3); k = $2 }
      else if (view == "Current sprint") keep = (cur != "" && $4 == cur)
      else if (view == "By subproject") { keep = active($3); k = ($14 == "-" ? "~" : $14) "\t" $2 }
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
# id | title | status | sprint | topics | branch | next | envs | depends_on, and | subproject in the
# By subproject view, the one its rows are grouped by.
sb_board_rows() {
  SB_VIEW="${1:-}" awk -F'\t' '
    function cell(s) { gsub(/\|/, "/", s); return s }
    BEGIN { bysub = (ENVIRON["SB_VIEW"] == "By subproject") }
    {
      title = ($8 != "-" ? $8 : $12)
      print cell($2) " | " cell(title) " | " cell($3) " | " cell($4) " | " cell($5) " | " cell($6) " | " cell($7) " | " cell($11) " | " cell($13) (bysub ? " | " cell($14) : "")
    }
  '
}

# Print a view name in its exact spelling, or return 1.
sb_board_view() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    '' | active) printf 'Active\n' ;;
    'current sprint' | current | sprint) printf 'Current sprint\n' ;;
    'by topic' | topic | topics) printf 'By topic\n' ;;
    'by subproject' | subproject | subprojects) printf 'By subproject\n' ;;
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

# Print a project's board for one view, from the frontmatter of its task READMEs; with
# --subproject, only the tasks of that subproject.
cmd_board() {
  local project="" view="" sub="" dir cur=""
  local usage="usage: second-brain board <project> [view] [--subproject S]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --subproject)
        [ $# -ge 2 ] || sb_die 5 "--subproject needs a value"
        sub="$2"
        shift
        ;;
      -*) sb_die 5 "$usage" ;;
      *)
        if [ -z "$project" ]; then project="$1"; else view="${view:+$view }$1"; fi
        ;;
    esac
    shift
  done
  [ -n "$project" ] || sb_die 5 "$usage"
  view="$(sb_board_view "$view")" || sb_die 5 "unknown view (views: Active, Current sprint, By topic, By subproject, Needs a status, All)"
  sb_need_project "$project"
  # The value is the note's name, as task set writes it.
  if [ -n "$sub" ]; then
    sb_need_sub "$sub"
    sub="$SB_S_NAME"
  fi
  dir="$SB_P_DIR/$SB_TASKS_ROOT"
  [ -d "$dir" ] || sb_die 1 "no tasks folder at $SB_P_PATH/$SB_TASKS_ROOT"
  if [ "$view" = "Current sprint" ]; then
    # Sprints turned off: a sprint note left in progress lists nothing.
    ! sb_uses_sprints "$SB_P_PATH" || cur="$(sb_sprint_current_id "$SB_P_PATH")"
    [ -n "$cur" ] || return 0
  fi
  sb_task_files "$dir" | sb_task_scan | sb_board_deps | sb_board_filter "$view" "$cur" "$sub" | sb_board_rows "$view"
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
