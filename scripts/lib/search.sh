#!/usr/bin/env bash
# search.sh - find a note by id or alias, and search text inside one project.

# Print the markdown files under a folder, skipping dot folders.
sb_md_files() {
  [ -d "$1" ] || return 0
  find "$1" -name '.*' -prune -o -type f -name '*.[mM][dD]' -print 2>/dev/null
}

# Find a note by task id or alias; print vault-relative paths.
cmd_find() {
  local id="" project="" rows hits="" name path keys f
  local usage="usage: second-brain find <ID-or-alias> [--project P]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        [ $# -ge 2 ] || sb_die 5 "--project needs a value"
        project="$2"
        shift 2
        ;;
      *)
        [ -z "$id" ] || sb_die 5 "$usage"
        id="$1"
        shift
        ;;
    esac
  done
  [ -n "$id" ] || sb_die 5 "$usage"
  sb_need_root
  if [ -n "$project" ]; then
    sb_need_project "$project"
    rows="$SB_P_NAME"$'\t'"$SB_P_PATH"$'\t'"$SB_P_KEYS"
  else
    rows="$(sb_projects_tsv)"
  fi
  # 1. The task path.
  case "$id" in
    */* | .*) ;;
    *) hits="$(sb_task_by_path "$id" "$rows" | cut -f2-)" ;;
  esac
  # 2. The aliases in frontmatter: task READMEs first, then every note of the project.
  [ -n "$hits" ] || hits="$(sb_task_by_alias "$id" "$rows" | cut -f2-)"
  if [ -z "$hits" ]; then
    hits="$({
      while IFS=$'\t' read -r name path keys; do
        [ -n "$name" ] && sb_md_files "$SB_ROOT/$path"
      done <<EOF
$rows
EOF
      if [ -z "$project" ]; then
        for f in "$SB_ROOT"/*.[mM][dD]; do [ -f "$f" ] && printf '%s\n' "$f"; done
        sb_md_files "$SB_ROOT/claude"
      fi
    } | sb_alias_scan "$id" | LC_ALL=C sort -u)"
  fi
  [ -n "$hits" ] || sb_die 1 "nothing found for: $id"
  printf '%s\n' "$hits" | SB_R="$SB_ROOT/" awk '{ r = ENVIRON["SB_R"]; if (substr($0, 1, length(r)) == r) $0 = substr($0, length(r) + 1); print }'
}

# Search the notes of one folder for terms: words, and phrases in double quotes. A note matches
# when it holds every term, in any letter case, and gives its three best lines at most. Print at
# most 40 path:line: text rows, the lines that hold the most terms first.
# With several terms a line holding one of them is noise: a note gives lines that hold two or
# more, or, when it has none, the first line that holds each term. When the rows do not all fit,
# every note keeps its best line before any note keeps a second one.
sb_search_notes() {
  (
    cd "$SB_ROOT" || exit 1
    find "$2" -name '.*' -prune -o -type f -name '*.[mM][dD]' -print 2>/dev/null | LC_ALL=C SB_Q="$1" awk '
      function add(t) {
        gsub(/^ +| +$/, "", t)
        if (t != "" && !(t in known)) { known[t] = 1; word[++nw] = t }
      }
      BEGIN {
        q = tolower(ENVIRON["SB_Q"]); n = length(q); cur = ""; quoted = 0
        for (i = 1; i <= n; i++) {
          ch = substr(q, i, 1)
          if (ch == "\"") { add(cur); cur = ""; quoted = !quoted; continue }
          if (ch == " " && !quoted) { add(cur); cur = ""; continue }
          cur = cur ch
        }
        add(cur)
      }
      $0 != "" && nw > 0 {
        path = $0; ln = 0; nh = 0; found = 0; best = 0
        split("", seen)
        while ((getline line < path) > 0) {
          ln++
          low = tolower(line); c = 0; first = 0
          for (i = 1; i <= nw; i++) if (index(low, word[i]) > 0) { c++; if (!(i in seen)) { seen[i] = 1; found++; first = 1 } }
          if (c) { nh++; hits[nh] = c; at[nh] = ln; text[nh] = line; lead[nh] = first; if (c > best) best = c }
        }
        close(path)
        if (found < nw) next
        nc = 0
        for (i = 1; i <= nh; i++) {
          if (nw > 1 && hits[i] < 2 && (best >= 2 || !lead[i])) continue
          cand[++nc] = i
        }
        for (r = 1; r <= 3 && r <= nc; r++) {
          top = 0
          for (k = 1; k <= nc; k++) if (cand[k] > 0 && (top == 0 || hits[cand[k]] > hits[cand[top]])) top = k
          i = cand[top]; cand[top] = 0
          gsub(/[\t\r]/, " ", text[i]); print r "\t" hits[i] "\t" path "\t" at[i] "\t" text[i]
        }
      }'
  ) | LC_ALL=C sort -t $'\t' -k1,1n -k2,2nr -k3,3 -k4,4n | head -40 |
    LC_ALL=C sort -t $'\t' -k2,2nr -k3,3 -k4,4n | LC_ALL=C awk -F'\t' "$(sb_awk_lib)"'
    { print cut($3 ":" $4 ": " trim($5), 240) }'
}

# Search text inside a project folder, in the notes that hold every word of it.
cmd_search() {
  local project="" text="" sub="" rel out="" dq='"'
  local usage="usage: second-brain search <project> \"<text>\" [--in SUBPATH]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --in)
        [ $# -ge 2 ] || sb_die 5 "--in needs a value"
        sub="$2"
        shift 2
        ;;
      *)
        if [ -z "$project" ]; then
          project="$1"
        elif [ -z "$text" ]; then
          text="$1"
        else
          sb_die 5 "$usage"
        fi
        shift
        ;;
    esac
  done
  # A text of spaces and quotes alone holds no term.
  case "${text//$dq/}" in *[!\ ]*) ;; *) text="" ;; esac
  if [ -z "$project" ] || [ -z "$text" ]; then sb_die 5 "$usage"; fi
  sb_need_project "$project"
  sub="${sub#/}"
  sub="${sub%/}"
  case "/$sub/" in */../* | */./*) sb_die 5 "--in takes a folder inside the project: $sub" ;; esac
  if sb_is_windows; then
    case "$sub" in *\\*) sb_die 5 "--in takes a folder inside the project, with forward slashes: $sub" ;; esac
  fi
  rel="$SB_P_PATH${sub:+/$sub}"
  [ -d "$SB_ROOT/$rel" ] || sb_die 1 "no folder at $rel"
  out="$(sb_search_notes "$text" "$rel")"
  [ -n "$out" ] || sb_die 1 "no match in $rel"
  printf '%s\n' "$out"
}
