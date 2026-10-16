#!/usr/bin/env bash
# subproject.sh - subprojects: one note per subproject in a project's claude/subprojects/ folder.

# Print the absolute path of each subproject note of a project path, in name order.
sb_sub_files() {
  local f
  for f in "$SB_ROOT/$1/claude/subprojects"/*.md; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
  return 0
}

# Print the name of a subproject note: its file name without .md.
sb_sub_name() {
  local n="${1##*/}"
  printf '%s\n' "${n%.md}"
}

# Read lines on stdin; print the ones that hold something, joined with ", ".
sb_sub_join() {
  awk 'NF { s = s (n++ ? ", " : "") $0 } END { print s }'
}

# Print the vault path of a subproject's docs folder: <topics_root>/<name>/ in the current project.
sb_sub_docs() {
  if [ "$SB_TOPICS_ROOT" = "." ]; then
    printf '%s/%s\n' "$SB_P_PATH" "$1"
  else
    printf '%s/%s/%s\n' "$SB_P_PATH" "$SB_TOPICS_ROOT" "$1"
  fi
}

# Find a subproject of the current project by name, exact first, then ignoring case; sets SB_S_FILE
# and SB_S_NAME. Returns 1 when there is none.
sb_sub_resolve() {
  local f n want loose=""
  want="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  SB_S_FILE=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n="$(sb_sub_name "$f")"
    if [ "$n" = "$1" ]; then
      SB_S_FILE="$f"
      break
    fi
    if [ -z "$loose" ] && [ "$(printf '%s' "$n" | tr '[:upper:]' '[:lower:]')" = "$want" ]; then loose="$f"; fi
  done <<EOF
$(sb_sub_files "$SB_P_PATH")
EOF
  [ -n "$SB_S_FILE" ] || SB_S_FILE="$loose"
  [ -n "$SB_S_FILE" ] || return 1
  SB_S_NAME="$(sb_sub_name "$SB_S_FILE")"
}

# Resolve a subproject of the current project by name, or exit 1.
sb_need_sub() {
  sb_sub_resolve "$1" || sb_die 1 "no subproject $1 in $SB_P_NAME (list them with: second-brain subproject $SB_P_NAME)"
}

# Print the value a subproject has for a key: its own, or the profile's when its own is absent or
# empty. Lists come joined with ", "; an empty value prints "-".
sb_sub_value() {
  local file="$1" key="$2" v
  case "$key" in
    repos) v="$(sb_fm_list "$file" repos 2>/dev/null | sb_sub_join)" ;;
    environments | repo_paths)
      v="$(sb_fm_list "$file" "$key" 2>/dev/null | sb_sub_join)"
      [ -n "$v" ] || v="$(sb_fm_list "$SB_P_PROFILE" "$key" 2>/dev/null | sb_sub_join)"
      ;;
    *)
      v="$(sb_fm_get "$file" "$key" 2>/dev/null)"
      [ -n "$v" ] || v="$(sb_fm_get "$SB_P_PROFILE" "$key" 2>/dev/null)"
      ;;
  esac
  printf '%s\n' "${v:--}"
}

# Print the effective settings of the subproject in SB_S_FILE as "key: value" lines.
sb_sub_show() {
  local k r rn rp rs rows paths=""
  printf 'subproject: %s\n' "$SB_S_NAME"
  printf 'note: %s\n' "$(sb_rel "$SB_S_FILE")"
  printf 'docs: %s\n' "$(sb_sub_docs "$SB_S_NAME")"
  for k in repos base_branch production_branch branch_pattern environments; do
    printf '%s: %s\n' "$k" "$(sb_sub_value "$SB_S_FILE" "$k")"
  done
  # Where each of its repos is, as the repo command finds it: the note's entry, the profile's, or
  # repos_root.
  rows="$(sb_repo_rows_at "$SB_P_PATH")"
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    while IFS=$'\t' read -r rn rp rs; do
      if [ "$(printf '%s' "$rn" | tr '[:upper:]' '[:lower:]')" = "$(printf '%s' "$r" | tr '[:upper:]' '[:lower:]')" ]; then
        [ "$rp" = "-" ] || paths="${paths:+$paths, }$r=$(sb_path_out "$rp")"
        break
      fi
    done <<EOF2
$rows
EOF2
  done <<EOF
$(sb_fm_list "$SB_S_FILE" repos 2>/dev/null)
EOF
  printf 'repo_paths: %s\n' "${paths:--}"
}

# Print the names of the subprojects of a project path whose repository holds a directory.
# The deepest recorded repository folder that holds it decides, as for projects. When none does,
# a folder on the way up that carries a subproject's repo name decides.
sb_sub_by_cwd() {
  local ppath="$1" phys f n r table="" best="" bestlen=0 rname rpath state rphys
  local tab=$'\t' nl=$'\n'
  phys="$(cd "$2" 2>/dev/null && pwd -P)" || return 0
  # A folder of the vault is no repository: its names never name a subproject.
  case "$phys/" in "$SB_ROOT"/*) return 0 ;; esac
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n="$(sb_sub_name "$f")"
    while IFS= read -r r; do
      [ -n "$r" ] && table="$table$r$tab$n$nl"
    done <<EOF2
$(sb_fm_list "$f" repos 2>/dev/null)
EOF2
  done <<EOF
$(sb_sub_files "$ppath")
EOF
  [ -n "$table" ] || return 0
  # The profile's repos go in too, with no subproject, so that the deepest name match can be one.
  while IFS= read -r r; do
    [ -n "$r" ] && table="$table$r$tab$nl"
  done <<EOF
$(sb_fm_list "$SB_ROOT/$ppath/claude/profile.md" repos 2>/dev/null)
EOF
  while IFS=$'\t' read -r rname rpath state; do
    [ "$state" = "ok" ] || continue
    rphys="$(cd -P "$rpath" 2>/dev/null && pwd -P)" || continue
    case "$phys/" in
      "$rphys"/*)
        if [ "${#rphys}" -gt "$bestlen" ]; then
          bestlen="${#rphys}"
          best="$rname"
        elif [ "${#rphys}" -eq "$bestlen" ]; then
          best="$best$nl$rname"
        fi
        ;;
    esac
  done <<EOF
$(sb_repo_rows_at "$ppath")
EOF
  # A recorded folder of a repository that is in no subproject gives no subproject.
  printf '%s' "$table" | LC_ALL=C SB_BEST="$best" SB_DIR="$phys" awk -F'\t' '
    BEGIN {
      nb = split(tolower(ENVIRON["SB_BEST"]), b, "\n")
      for (i = 1; i <= nb; i++) want[b[i]] = 1
      np = split(ENVIRON["SB_DIR"], part, "/")
    }
    { repo[NR] = tolower($1); gsub(/ /, "_", repo[NR]); sp[NR] = $2; raw[NR] = tolower($1) }
    END {
      if (nb) {
        for (j = 1; j <= NR; j++) if (sp[j] != "" && (raw[j] in want) && !(sp[j] in seen)) { print sp[j]; seen[sp[j]] = 1 }
        exit
      }
      # The deepest folder that carries a repo name decides, even when that repo is the profile alone.
      for (i = np; i >= 1; i--) {
        if (part[i] == "") continue
        c = tolower(part[i]); gsub(/ /, "_", c); hit = 0
        for (j = 1; j <= NR; j++) if (repo[j] == c) { hit = 1; if (sp[j] != "" && !(sp[j] in seen)) { print sp[j]; seen[sp[j]] = 1 } }
        if (hit) exit
      }
    }'
}

# List a project's subprojects, show one's effective settings, or find the one a directory is in.
cmd_subproject() {
  local project="${1:-}" name="" cwd="" f n repos hits count
  local usage="usage: second-brain subproject <project> [name | --cwd DIR]"
  [ -n "$project" ] || sb_die 5 "$usage"
  shift
  case "${1:-}" in
    --cwd)
      [ $# -eq 2 ] || sb_die 5 "$usage"
      cwd="$(sb_path_in "$2")"
      ;;
    -*) sb_die 5 "$usage" ;;
    *)
      [ $# -le 1 ] || sb_die 5 "$usage"
      name="${1:-}"
      ;;
  esac
  sb_need_project "$project"
  sb_need_profile
  if [ -n "$cwd" ]; then
    hits="$(sb_sub_by_cwd "$SB_P_PATH" "$cwd")"
    [ -n "$hits" ] || sb_die 1 "no subproject of $SB_P_NAME holds $(sb_path_out "$cwd")"
    count="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
    if [ "$count" -gt 1 ]; then
      printf '%s\n' "$hits"
      sb_die 4 "several subprojects of $SB_P_NAME hold that folder; name one"
    fi
    name="$hits"
  fi
  if [ -n "$name" ]; then
    sb_need_sub "$name"
    sb_sub_show
    return 0
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n="$(sb_sub_name "$f")"
    repos="$(sb_fm_list "$f" repos 2>/dev/null | awk 'NF { s = s (k++ ? "," : "") $0 } END { print s }')"
    printf '%s\t%s\t%s\n' "$n" "${repos:--}" "$(sb_sub_docs "$n")"
  done <<EOF
$(sb_sub_files "$SB_P_PATH")
EOF
  return 0
}
