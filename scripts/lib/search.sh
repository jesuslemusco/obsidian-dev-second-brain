#!/usr/bin/env bash
# search.sh - find a note by id or alias, and search text inside one project.

# Print the markdown files under a folder, skipping dot folders.
sb_md_files() {
  [ -d "$1" ] || return 0
  find "$1" -name '.*' -prune -o -type f -name '*.md' -print 2>/dev/null
}

# Find a note by task id or alias; print vault-relative paths.
cmd_find() {
  local id="" project="" rows hits="" name path keys f pfx=""
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
    pfx="$SB_P_PATH/"
  else
    rows="$(sb_projects_tsv)"
  fi
  # 1. The task path.
  case "$id" in
    */* | .*) ;;
    *) hits="$(sb_task_by_path "$id" "$rows" | cut -f2-)" ;;
  esac
  # 2. The alias index of the app.
  if [ -z "$hits" ] && sb_ob_up; then
    hits="$(sb_ob aliases verbose | SB_W="$id" SB_PFX="$pfx" SB_R="$SB_ROOT" awk -F'\t' '
      BEGIN { w = tolower(ENVIRON["SB_W"]); pfx = ENVIRON["SB_PFX"] }
      NF >= 2 && tolower($1) == w && (pfx == "" || substr($2, 1, length(pfx)) == pfx) { print ENVIRON["SB_R"] "/" $2 }
    ' | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done)"
  fi
  # 3. The aliases in frontmatter: task READMEs first, then every note of the project.
  [ -n "$hits" ] || hits="$(sb_task_by_alias "$id" "$rows" | cut -f2-)"
  if [ -z "$hits" ]; then
    hits="$({
      while IFS=$'\t' read -r name path keys; do
        [ -n "$name" ] && sb_md_files "$SB_ROOT/$path"
      done <<EOF
$rows
EOF
      if [ -z "$project" ]; then
        for f in "$SB_ROOT"/*.md; do [ -f "$f" ] && printf '%s\n' "$f"; done
        sb_md_files "$SB_ROOT/claude"
      fi
    } | sb_alias_scan "$id" | LC_ALL=C sort -u)"
  fi
  [ -n "$hits" ] || sb_die 1 "nothing found for: $id"
  printf '%s\n' "$hits" | SB_R="$SB_ROOT/" awk '{ r = ENVIRON["SB_R"]; if (substr($0, 1, length(r)) == r) $0 = substr($0, length(r) + 1); print }'
}

# Search one folder through the app; print path:line: text rows.
sb_search_cli() {
  sb_ob search:context "query=$1" "path=$2" limit=40 | LC_ALL=C SB_PFX="$2/" awk "$(sb_awk_lib)"'
    BEGIN { pfx = ENVIRON["SB_PFX"] }
    substr($0, 1, length(pfx)) == pfx && $0 ~ /:[0-9]+:/ { print cut($0, 240) }'
}

# Search the markdown files of one folder with grep; print path:line: text rows.
sb_search_grep() {
  (cd "$SB_ROOT" && find "$2" -name '.*' -prune -o -type f -name '*.md' -exec grep -niF -e "$1" /dev/null {} + 2>/dev/null) |
    LC_ALL=C sort -t: -k1,1 -k2,2n | LC_ALL=C awk "$(sb_awk_lib)"'
    {
      i = index($0, ".md:")
      if (i == 0) next
      p = substr($0, 1, i + 2); rest = substr($0, i + 4)
      j = index(rest, ":")
      if (j == 0) next
      print cut(p ":" substr(rest, 1, j - 1) ": " trim(substr(rest, j + 1)), 240)
    }'
}

# Search text inside a project folder: the app first, grep when it is down or finds nothing.
cmd_search() {
  local project="" text="" sub="" rel out=""
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
  if [ -z "$project" ] || [ -z "$text" ]; then sb_die 5 "$usage"; fi
  sb_need_project "$project"
  sub="${sub#/}"
  sub="${sub%/}"
  case "/$sub/" in */../* | */./*) sb_die 5 "--in takes a folder inside the project: $sub" ;; esac
  rel="$SB_P_PATH${sub:+/$sub}"
  [ -d "$SB_ROOT/$rel" ] || sb_die 1 "no folder at $rel"
  if sb_ob_up; then
    out="$(sb_search_cli "$text" "$rel")"
    # An empty answer is retried once before it is believed.
    [ -n "$out" ] || out="$(sb_search_cli "$text" "$rel")"
  fi
  [ -n "$out" ] || out="$(sb_search_grep "$text" "$rel")"
  [ -n "$out" ] || sb_die 1 "no match in $rel"
  printf '%s\n' "$out" | head -40
}
