#!/usr/bin/env bash
# snapshot.sh - save the vault's state before a bulk change and compare it later.

# Print the folder that holds the snapshots.
sb_snap_home() {
  printf '%s\n' "$SB_ROOT/.second-brain/snapshots"
}

# Print a snapshot name that sorts by time; SECOND_BRAIN_NOW replaces the clock.
sb_snap_stamp() {
  local now="${SECOND_BRAIN_NOW:-}"
  [ -n "$now" ] || now="$(date +%H%M%S)"
  now="$(printf '%s' "$now" | sed 's/[ T]/-/g; s/://g')"
  case "$now" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*) ;;
    *) now="$(sb_today)-$now" ;;
  esac
  printf '%s\n' "$now"
}

# Exit 5 unless the argument can name a snapshot folder.
sb_snap_check_name() {
  case "$1" in
    '' | .* | -* | *[!A-Za-z0-9._-]*)
      sb_die 5 "a snapshot name holds letters, digits, dots, hyphens and underscores: $1"
      ;;
  esac
}

# Print the unresolved links of the vault as "path: <link as written>", sorted. The line number
# is left out, so an edit above a link does not show as a difference.
sb_snap_unresolved() {
  sb_graph_unresolved | LC_ALL=C awk '
    match($0, /\.[Mm][Dd]:[0-9]+: /) { print substr($0, 1, RSTART + 2) ": " substr($0, RSTART + RLENGTH) }' |
    LC_ALL=C sort -u
}

# Print one row per alias in the frontmatter of every note of the vault: alias, vault path. Sorted.
sb_snap_aliases() {
  (
    cd "$SB_ROOT" || exit 1
    find . -type d -name '.?*' -prune -o -type f -name '*.[mM][dD]' -print | LC_ALL=C awk "$(sb_awk_lib)"'
      function put(v) { gsub(/[\t\r]/, " ", v); if (v != "") print v "\t" substr(file, 3) }
      {
        file = $0; key = ""; lineno = 0
        while ((getline line < file) > 0) {
          lineno++
          sub(/\r$/, "", line)
          if (lineno == 1) { sub(/^\357\273\277/, "", line); if (line != "---") break; continue }
          if (line == "---") break
          if (line ~ /^[A-Za-z0-9_][A-Za-z0-9_-]*:/) {
            i = index(line, ":"); key = substr(line, 1, i - 1); v = trim(substr(line, i + 1))
            if (key != "aliases") continue
            if (substr(v, 1, 1) == "[") { n = split_inline(v, it); for (k = 1; k <= n; k++) put(it[k]) }
            else put(unq(v))
          } else if (key == "aliases" && line ~ /^[ \t]*-([ \t]|$)/) {
            v = line; sub(/^[ \t]*-[ \t]*/, "", v); put(unq(v))
          }
        }
        close(file)
      }'
  ) | LC_ALL=C sort
}

# Print one row per task of every project in the index: project, id, status.
sb_snap_tasks() {
  local name path keys
  sb_projects_tsv | while IFS=$'\t' read -r name path keys; do
    [ -n "$name" ] || continue
    sb_task_files "$SB_ROOT/$path/$(sb_setting "$path" tasks_root tasks)" | sb_task_scan |
      SB_N="$name" awk -F'\t' '{ print ENVIRON["SB_N"] "\t" $2 "\t" $3 }'
  done | LC_ALL=C sort
}

# Print the link rows of the link library, sorted.
sb_snap_links() {
  local out
  out="$( (sb_link_scan) 2>/dev/null </dev/null)" || true
  [ -z "$out" ] || printf '%s\n' "$out" | LC_ALL=C sort
  return 0
}

# Print the doctor report.
sb_snap_doctor() {
  (cmd_doctor) 2>/dev/null </dev/null
  return 0
}

# Write the views of the state now into a folder; a second argument adds the doctor report.
sb_snap_build() {
  local dir="$1"
  sb_snap_unresolved >"$dir/unresolved.txt"
  sb_snap_aliases >"$dir/aliases.txt"
  sb_snap_tasks >"$dir/tasks.tsv"
  sb_snap_links >"$dir/links.txt"
  [ -z "${2:-}" ] || sb_snap_doctor >"$dir/doctor.txt"
  return 0
}

# Save the state now under .second-brain/snapshots/<name>.
cmd_snapshot() {
  local name="${1:-}" dir
  [ $# -le 1 ] || sb_die 5 "usage: second-brain snapshot [name]"
  sb_need_root
  [ -n "$name" ] || name="$(sb_snap_stamp)"
  sb_snap_check_name "$name"
  dir="$(sb_snap_home)/$name"
  [ ! -e "$dir" ] || sb_die 6 "snapshot already exists: $(sb_rel "$dir")"
  mkdir -p "$dir" || sb_die 1 "cannot create $(sb_rel "$dir")"
  sb_snap_build "$dir" doctor
  sb_rel "$dir"
}

# Print a heading and the lines only the second file holds; return 1 when there are none.
sb_snap_only() {
  local out
  out="$(LC_ALL=C awk '
    $0 == "" { next }
    side == "a" { a[$0] = 1; next }
    !($0 in a) && !seen[$0]++ { print "  " $0 }' side=a "$2" side=b "$3" | LC_ALL=C sort)"
  [ -n "$out" ] || return 1
  printf '%s\n%s\n' "$1" "$out"
}

# Print the tasks added, removed and changed between two tasks.tsv files; return 1 for none.
sb_snap_tasks_diff() {
  local out
  out="$(LC_ALL=C awk -F'\t' '
    $2 == "" { next }
    side == "old" { old[$1 "\t" $2] = $3; next }
    { new[$1 "\t" $2] = $3 }
    END {
      for (k in new) if (!(k in old)) print "1\t" k "\t" new[k]
      for (k in old) {
        if (!(k in new)) print "2\t" k "\t" old[k]
        else if (old[k] != new[k]) print "3\t" k "\t" old[k] " -> " new[k]
      }
    }' side=old "$1" side=new "$2" | LC_ALL=C sort | awk -F'\t' '
    BEGIN { head[1] = "tasks added:"; head[2] = "tasks removed:"; head[3] = "tasks changed:" }
    $1 != last { print head[$1]; last = $1 }
    { print "  " $2 " | " $3 " | " $4 }')"
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

# Print the link rows that differ between two links.txt files, old then new; return 1 for none.
sb_snap_links_diff() {
  local out
  out="$(LC_ALL=C awk '
    function key(l,   i, j) {
      i = index(l, "\t"); j = index(l, " | ")
      if (i == 0 || (j > 0 && j < i)) i = j
      return (i > 0 ? substr(l, 1, i - 1) : l)
    }
    $0 == "" { next }
    side == "old" { old[$0] = 1; next }
    { new[$0] = 1 }
    END {
      for (l in old) if (!(l in new)) print key(l) "\034" "1" "\034" "  was: " l
      for (l in new) if (!(l in old)) print key(l) "\034" "2" "\034" "  now: " l
    }' side=old "$1" side=new "$2" | LC_ALL=C sort | awk '{ print substr($0, index($0, "\034") + 3) }')"
  [ -n "$out" ] || return 1
  printf 'links changed:\n%s\n' "$out"
}

# Print what differs between two view folders, old then new; return 1 when something does.
sb_snap_diff() {
  local old="$1" new="$2" f label rc=0
  for f in unresolved.txt aliases.txt tasks.tsv links.txt; do
    if [ ! -f "$old/$f" ] || [ ! -f "$new/$f" ]; then
      printf 'not compared: %s\n' "$f"
      continue
    fi
    label="${f%.*}"
    case "$f" in
      tasks.tsv) sb_snap_tasks_diff "$old/$f" "$new/$f" && rc=1 ;;
      links.txt) sb_snap_links_diff "$old/$f" "$new/$f" && rc=1 ;;
      *)
        sb_snap_only "$label added:" "$old/$f" "$new/$f" && rc=1
        sb_snap_only "$label removed:" "$new/$f" "$old/$f" && rc=1
        ;;
    esac
  done
  return "$rc"
}

# Print the newest snapshot name, by name order; nothing when there is none.
sb_snap_newest() {
  local d
  for d in "$(sb_snap_home)"/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"
    printf '%s\n' "${d##*/}"
  done | LC_ALL=C sort | tail -1
}

# Compare a snapshot with the state now.
cmd_compare() {
  local name="${1:-}" dir tmp rc=0
  [ $# -le 1 ] || sb_die 5 "usage: second-brain compare [name]"
  sb_need_root
  if [ -n "$name" ]; then
    sb_snap_check_name "$name"
  else
    name="$(sb_snap_newest)"
    [ -n "$name" ] || sb_die 1 "no snapshot to compare with (take one with: second-brain snapshot)"
  fi
  dir="$(sb_snap_home)/$name"
  [ -d "$dir" ] || sb_die 1 "no snapshot named $name in $(sb_rel "$(sb_snap_home)")"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-snap.XXXXXX")" || sb_die 1 "cannot create a temp folder"
  sb_snap_build "$tmp"
  printf 'snapshot: %s\n' "$(sb_rel "$dir")"
  sb_snap_diff "$dir" "$tmp" || rc=1
  rm -rf "$tmp"
  [ "$rc" -ne 0 ] || printf 'no differences\n'
  return "$rc"
}
