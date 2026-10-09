#!/usr/bin/env bash
# snapshot.sh - save the vault's state before a bulk change, compare it later, test the CLI.

# Print the folder that holds the snapshots.
sb_snap_home() {
  printf '%s\n' "$SB_ROOT/.second-brain/snapshots"
}

# Print the link directory: SECOND_BRAIN_CLAUDE_HOME, else .claude in the home folder.
sb_snap_link_dir() {
  printf '%s\n' "${SECOND_BRAIN_CLAUDE_HOME:-${HOME:-}/.claude}"
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

# Read CLI output on stdin; drop blank lines and a lone "No ... found." message.
sb_snap_rows() {
  LC_ALL=C awk '{ sub(/\r$/, "") } NF && $0 !~ /^No [A-Za-z ]+ found\.?$/'
}

# Print a CLI listing, sorted, or the line "unavailable" when the app does not answer.
sb_snap_ob_view() {
  local out
  if sb_ob_up && out="$(sb_ob "$@")"; then
    case "$out" in
      Error*) ;;
      *)
        printf '%s\n' "$out" | sb_snap_rows | LC_ALL=C sort
        return 0
        ;;
    esac
  fi
  printf 'unavailable\n'
}

# Print one row per task of every project in the index: project, id, status.
sb_snap_tasks() {
  local name path keys
  if [ ! -f "$SB_ROOT/CLAUDE.md" ]; then
    printf 'unavailable\n'
    return 0
  fi
  sb_projects_tsv | while IFS=$'\t' read -r name path keys; do
    [ -n "$name" ] || continue
    sb_task_files "$SB_ROOT/$path/$(sb_setting "$path" tasks_root tasks)" | sb_task_scan |
      SB_N="$name" awk -F'\t' '{ print ENVIRON["SB_N"] "\t" $2 "\t" $3 }'
  done | LC_ALL=C sort
}

# Print the link rows of the link library, or the symlinks in the link directory.
sb_snap_links() {
  local dir f out rc=0
  if declare -F sb_link_scan >/dev/null 2>&1; then
    out="$( (sb_link_scan) 2>/dev/null </dev/null)" || rc=$?
    if [ -n "$out" ]; then
      printf '%s\n' "$out" | LC_ALL=C sort
    elif [ "$rc" -ne 0 ]; then
      printf 'unavailable\n'
    fi
    return 0
  fi
  dir="$(sb_snap_link_dir)"
  for f in "$dir"/skills/* "$dir"/agents/*; do
    [ -L "$f" ] && printf '%s\t%s\n' "$(basename "$f")" "$(readlink "$f")"
  done | LC_ALL=C sort
  return 0
}

# Print the doctor report, or the line "unavailable" when there is none.
sb_snap_doctor() {
  local out=""
  if declare -F cmd_doctor >/dev/null 2>&1; then
    out="$( (cmd_doctor) 2>/dev/null </dev/null)" || true
  fi
  printf '%s\n' "${out:-unavailable}"
}

# Write the views of the state now into a folder; a second argument adds the doctor report.
sb_snap_build() {
  local dir="$1"
  sb_snap_ob_view unresolved >"$dir/unresolved.txt"
  sb_snap_ob_view aliases verbose >"$dir/aliases.txt"
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

# Return 0 when a view file is missing or holds the line "unavailable".
sb_snap_unavailable() {
  [ -f "$1" ] || return 0
  [ "$(tr -d '\r' <"$1")" = "unavailable" ]
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
    if sb_snap_unavailable "$old/$f" || sb_snap_unavailable "$new/$f"; then
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

# Rewrite the limits block of the conventions note: verdict line, CLI version, optional extra line.
sb_snap_write_limits() {
  local verdict="${1#- }" version="${2:-}" extra="${3:-}" file tmp body eofnl=1 nl=$'\n'
  sb_need_root
  file="$SB_ROOT/obsidian-conventions.md"
  [ -f "$file" ] || return 1
  body="- $verdict$nl- obsidian: ${version:-unknown}"
  body="$body$nl- Scoped searches pass \`path=\` and are retried once when they come back empty."
  [ -z "$extra" ] || body="$body$nl$extra"
  if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then eofnl=0; fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/sb-snap.XXXXXX")" || return 1
  LC_ALL=C SB_BODY="$body" SB_EOFNL="$eofnl" awk '
    function put(s) { printf "%s%s", sep, s; sep = "\n" }
    function block(   i) { put(eol); for (i = 1; i <= nb; i++) put(bl[i] eol) }
    BEGIN {
      nb = split(ENVIRON["SB_BODY"], bl, "\n"); eofnl = ENVIRON["SB_EOFNL"] + 0
      sep = ""; eol = ""; state = 0; blank = 1
    }
    {
      raw = $0; line = raw; sub(/\r$/, "", line)
      if (NR == 1 && raw != line) eol = "\r"
      if (state == 1) {
        if (line !~ /^## /) next
        put(eol); state = 2
      }
      if (state == 0 && tolower(line) ~ /^##[ \t]+limits on this install/) {
        put(raw); block(); state = 1; next
      }
      blank = (line ~ /^[ \t]*$/)
      put(raw)
    }
    END {
      if (state == 0) {
        if (!blank) put(eol)
        put("## Limits on this install" eol); block()
      }
      if (eofnl) printf "\n"
    }
  ' "$file" >"$tmp" || { rm -f "$tmp"; return 1; }
  sb_same_file "$tmp" "$file" || cat "$tmp" >"$file"
  rm -f "$tmp"
  return 0
}

# Print the folder the probe searches: the first index project that exists, else claude.
sb_snap_scope() {
  local name path keys
  while IFS=$'\t' read -r name path keys; do
    if [ -n "$path" ] && [ -d "$SB_ROOT/$path" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  done <<EOF
$(sb_projects_tsv 2>/dev/null)
EOF
  printf 'claude\n'
}

# Read CLI output on stdin; print the number of result lines.
sb_snap_count() {
  sb_snap_rows | grep -c -v '^Error' || true
}

# Print a line saying whether a tag query also matches sub-tags; nothing when it cannot tell.
sb_snap_tag_line() {
  local sub top
  sub="$(sb_ob tag name=type/onboarding verbose | grep -c '\.md$')"
  [ "${sub:-0}" -gt 0 ] || return 0
  top="$(sb_ob tag name=type verbose | grep -c '\.md$')"
  if [ "${top:-0}" -gt 0 ]; then
    printf '%s\n' '- tags: `tag name=<tag>` also matches the sub-tags of the tag.'
  else
    printf '%s\n' '- tags: `tag name=<tag>` matches the exact tag only, not its sub-tags.'
  fi
}

# Test the Obsidian CLI and record the verdict in the conventions note.
cmd_probe() {
  local folder n i first="" counts="" ok=1 line version
  [ $# -eq 0 ] || sb_die 5 "usage: second-brain probe"
  sb_need_root
  if ! sb_ob_up; then
    if [ "$SB_OB_STATE" = "missing" ]; then
      sb_die 3 "the Obsidian CLI was not found; nothing was changed"
    fi
    sb_die 3 "Obsidian is not running, or it does not have this vault open; nothing was changed"
  fi
  [ -f "$SB_ROOT/obsidian-conventions.md" ] ||
    sb_die 1 "no conventions note at obsidian-conventions.md (run: second-brain scaffold vault)"
  folder="$(sb_snap_scope)"
  # a selective query: a search that matches hundreds of notes can come back empty
  for i in 1 2 3 4 5 6; do
    if [ "$folder" = "claude" ]; then
      n="$(sb_ob search query=conventions_version | sb_snap_count)"
    else
      n="$(sb_ob search query=ticket_keys "path=$folder" | sb_snap_count)"
    fi
    [ -n "$first" ] || first="$n"
    [ "$n" = "$first" ] || ok=0
    counts="$counts${counts:+ }$n"
  done
  [ "$first" -gt 0 ] || ok=0
  if [ "$ok" -eq 1 ]; then
    line="search: ok (6 of 6 scoped searches consistent, $(sb_today))"
  else
    line="search: unreliable (counts $counts, $(sb_today))"
  fi
  version="$(sb_ob version | sb_snap_rows | grep -v '^Error' | head -1)"
  sb_snap_write_limits "$line" "$version" "$(sb_snap_tag_line)" ||
    sb_die 1 "cannot write obsidian-conventions.md"
  printf '%s\n' "$line"
}
