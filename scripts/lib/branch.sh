#!/usr/bin/env bash
# branch.sh - a ticket's branches, a file on another branch and the work started, read with git.
# Every git command here only reads, and none takes a setting from outside the repository.

# Run git in a folder with no setting from outside. Every GIT_ variable is cleared first:
# GIT_CONFIG_PARAMETERS and GIT_CONFIG_COUNT pass -c settings, such as a gpg.program that a
# signature check runs, and GIT_DIR names another repository. Nothing is paged.
# Usage: sb_br_git <folder> <git args>...
sb_br_git() {
  local dir="$1" v
  shift
  (
    for v in ${!GIT_*}; do unset "$v"; done
    exec git --no-pager -C "$dir" "$@"
  )
}

# Print the local and remote branches of a repository, one row each: the name git shows, its
# short hash, its full ref and its name without the remote, sorted by ref. A remote's HEAD is
# left out.
sb_br_refs() {
  sb_br_git "$1" for-each-ref --format='%(refname)%09%(objectname:short)' refs/heads refs/remotes 2>/dev/null |
    awk -F'\t' '
      { r = $1; n = r }
      sub(/^refs\/heads\//, "", n) { print n "\t" $2 "\t" r "\t" n; next }
      sub(/^refs\/remotes\//, "", n) {
        if (n ~ /\/HEAD$/) next
        p = n; sub(/^[^\/]*\//, "", p)
        print n "\t" $2 "\t" r "\t" p
      }'
}

# Read rows on stdin; print those whose first cell carries one of the ids, given one per line:
# the id in any letter case, with no letter or digit right before or after it. So feature/EX-1-fix
# carries EX-1, and feature/EX-10 and TEX-1 do not.
sb_br_carry() {
  SB_IDS="$1" LC_ALL=C awk -F'\t' '
    BEGIN { n = split(tolower(ENVIRON["SB_IDS"]), id, "\n") }
    function carries(s, w,   from, j, p, a, b) {
      from = 1
      while ((j = index(substr(s, from), w)) > 0) {
        p = from + j - 1
        a = (p == 1) ? "" : substr(s, p - 1, 1)
        b = substr(s, p + length(w), 1)
        if (a !~ /[a-z0-9]/ && b !~ /[a-z0-9]/) return 1
        from = p + 1
      }
      return 0
    }
    {
      s = tolower($1)
      for (i = 1; i <= n; i++) if (id[i] != "" && carries(s, id[i])) { print; next }
    }'
}

# Print the ids a ticket's branch may carry, one per line: the id asked for, then for a tracked
# task its folder id and each alias that is a key of the project, a hyphen and a number, as the
# later ids of an environment set are.
# Usage: sb_br_ids <id> <task README or empty>
sb_br_ids() {
  printf '%s\n' "$1"
  [ -n "$2" ] || return 0
  basename "$(dirname "$2")"
  sb_fm_list "$2" aliases 2>/dev/null | SB_K="$SB_P_KEYS" LC_ALL=C awk '
    BEGIN { nk = split(tolower(ENVIRON["SB_K"]), k, ",") }
    {
      a = tolower($0)
      for (i = 1; i <= nk; i++) {
        kk = k[i]; gsub(/^[ \t]+|[ \t]+$/, "", kk)
        if (kk != "" && index(a, kk "-") == 1 && substr(a, length(kk) + 2) ~ /^[0-9]+$/) { print $0; break }
      }
    }'
}

# Print "name<TAB>recorded folder" of the project's repo a folder is, or a worktree of; "-<TAB>-"
# when it is none of them. The rows are those sb_repo_rows_at prints.
# Usage: sb_br_repo_at <folder> <rows>
sb_br_repo_at() {
  local phys common main="" rn rp rs rphys
  phys="$(cd "$1" && pwd -P)"
  # A linked worktree's common git folder is that of its repo's main folder.
  common="$(sb_br_git "$1" rev-parse --git-common-dir 2>/dev/null)"
  if [ -n "$common" ]; then
    common="$(sb_path_in "$common")"
    main="$(cd "$1" && cd "$common" 2>/dev/null && pwd -P)"
    main="${main%/.git}"
  fi
  while IFS=$'\t' read -r rn rp rs; do
    [ "$rs" = ok ] || continue
    rphys="$(cd "$rp" 2>/dev/null && pwd -P)" || continue
    if [ "$rphys" = "$phys" ] || [ "$rphys" = "$main" ]; then
      printf '%s\t%s\n' "$rn" "$rp"
      return 0
    fi
  done <<EOF
$2
EOF
  printf -- '-\t-\n'
}

# Print a "branch: <name> <short hash>" line for each ref row; nothing for no rows.
# Usage: sb_br_lines <ref rows>
sb_br_lines() {
  [ -z "$1" ] || printf '%s\n' "$1" | awk -F'\t' '{ print "branch: " $1 " " $2 }'
}

# Set SB_BR_ROW to the ref row of the ticket's branch: the task's recorded branch when the repo
# has it, locally first, else the one branch that carries the ticket's ids. Exit 1 when none
# does, and 4, after their branch lines, when several do.
# Usage: sb_br_ticket_branch <id> <recorded> <ref rows> <carried rows> <folder>
sb_br_ticket_branch() {
  local row
  row="$(printf '%s\n' "$3" | SB_W="$2" awk -F'\t' '
    BEGIN { w = ENVIRON["SB_W"] }
    $1 == "" { next }
    $3 == "refs/heads/" w { local = $0 }
    $4 == w && remote == "" && $3 ~ /^refs\/remotes\// { remote = $0 }
    $1 == w && named == "" { named = $0 }
    END { print (local != "" ? local : (remote != "" ? remote : named)) }')"
  if [ -n "$row" ]; then
    SB_BR_ROW="$row"
    return 0
  fi
  [ -n "$4" ] || sb_die 1 "no branch carries $1 in $(sb_path_out "$5")"
  row="$(printf '%s\n' "$4" | awk -F'\t' '
    !($4 in seen) { seen[$4] = 1; names++ }
    $3 ~ /^refs\/heads\// && !($4 in local) { local[$4] = $0 }
    !($4 in any) { any[$4] = $0; last = $4 }
    END { if (names == 1) print (last in local ? local[last] : any[last]) }')"
  if [ -z "$row" ]; then
    sb_br_lines "$4"
    sb_die 4 "several branches carry $1: record the canonical one with second-brain task set $1 branch=<branch>"
  fi
  SB_BR_ROW="$row"
}

# Print lines indented by two blanks after a "key:" line, or "key: -" when there are none.
# Usage: sb_br_block <key> <text>
sb_br_block() {
  if [ -z "$2" ]; then
    printf '%s: -\n' "$1"
    return 0
  fi
  printf '%s:\n' "$1"
  printf '%s\n' "$2" | sed 's/^[[:space:]]*/  /'
}

# second-brain branch <project> <ID> [--path <dir>] [--show <ref> <file> | --started]
cmd_branch() {
  local usage="usage: second-brain branch <project> <ID> [--path <dir>] [--show <ref> <file> | --started]"
  local a n=0 project="" id="" at="" hasat=0 mode=list ref="" file=""
  local rows hits tfile="" rec="-" sub="" by_repo ids want row rpath rstate dir name base pattern
  local current head refs carried on=no tbname tbref bname bref hash kind log stat
  while [ $# -gt 0 ]; do
    a="$1"
    case "$a" in
      --path)
        [ $# -ge 2 ] && [ -n "$2" ] || sb_die 5 "--path needs a folder"
        at="$2"
        hasat=1
        shift 2
        continue
        ;;
      --show)
        [ "$mode" = list ] || sb_die 5 "$usage"
        [ $# -ge 3 ] && [ -n "$2" ] && [ -n "$3" ] || sb_die 5 "--show needs a ref and a file"
        ref="$2"
        file="$3"
        mode=show
        shift 3
        continue
        ;;
      --started)
        [ "$mode" = list ] || sb_die 5 "$usage"
        mode=started
        shift
        continue
        ;;
      -*) sb_die 5 "$usage" ;;
    esac
    n=$((n + 1))
    case "$n" in
      1) project="$a" ;;
      2) id="$a" ;;
      *) sb_die 5 "$usage" ;;
    esac
    shift
  done
  [ "$n" -eq 2 ] || sb_die 5 "$usage"
  case "$id" in '' | */* | .*) sb_die 5 "not a task id: $id" ;; esac
  # A ref that starts with a dash would reach git as an option.
  case "$ref" in -*) sb_die 5 "a ref cannot start with a dash: $ref" ;; esac
  sb_need_project "$project"
  sb_need_profile
  command -v git >/dev/null 2>&1 || sb_die 1 "git is not installed"

  # The task, when the ticket has one: its recorded branch and its subproject.
  hits="$(sb_task_by_path "$id" "$SB_P_NAME"$'\t'"$SB_P_PATH"$'\t'"$SB_P_KEYS")"
  [ -n "$hits" ] || hits="$(sb_task_by_alias "$id" "$SB_P_NAME"$'\t'"$SB_P_PATH"$'\t'"$SB_P_KEYS")"
  case "$hits" in
    *$'\n'*)
      printf '%s\n' "$hits" | cut -f2- | while IFS= read -r a; do sb_rel "$a"; done
      sb_die 4 "several tasks match $id in $SB_P_NAME"
      ;;
    ?*) tfile="${hits#*$'\t'}" ;;
  esac
  if [ -n "$tfile" ]; then
    rec="$(sb_fm_get "$tfile" branch 2>/dev/null)"
    [ -n "$rec" ] || rec="-"
    sub="$(sb_fm_get "$tfile" subproject 2>/dev/null)"
  fi
  SB_S_FILE=""
  if [ -n "$sub" ] && ! sb_sub_resolve "$sub"; then
    sb_note "$id names the subproject $sub, which $SB_P_NAME has not: the profile's settings are read"
  fi

  # The repo: the folder --path names, else the subproject's first repo, else the profile's.
  rows="$(sb_repo_rows_at "$SB_P_PATH")"
  if [ "$hasat" -eq 1 ]; then
    at="$(sb_path_in "$at")"
    [ -d "$at" ] || sb_die 1 "the folder is missing: $(sb_path_out "$at")"
    dir="$(cd "$at" && pwd)"
    row="$(sb_br_repo_at "$dir" "$rows")"
    IFS=$'\t' read -r name rpath <<EOF
$row
EOF
  else
    want=""
    [ -z "$SB_S_FILE" ] || want="$(sb_fm_list "$SB_S_FILE" repos 2>/dev/null | head -1)"
    [ -n "$want" ] || want="$(printf '%s\n' "$rows" | head -1 | cut -f1)"
    [ -n "$want" ] || sb_die 1 "no repo is listed in repos of $SB_P_NAME ($SB_P_PATH/claude/profile.md): name its folder with --path"
    row="$(sb_val_repo_row "$want")" || sb_die 1 "$want is not in repos of $SB_P_NAME ($SB_P_PATH/claude/profile.md)"
    IFS=$'\t' read -r name rpath rstate <<EOF
$row
EOF
    sb_val_need_folder "$name" "$rpath" "$rstate"
    dir="$rpath"
  fi
  sb_br_git "$dir" rev-parse --git-dir >/dev/null 2>&1 || sb_die 1 "not a git repository: $(sb_path_out "$dir")"
  # With no subproject on the task, the one whose repos hold the repo's folder gives the settings.
  if [ -z "$SB_S_FILE" ] && [ -z "$sub" ]; then
    [ "$rpath" != "-" ] || rpath="$dir"
    by_repo="$(sb_sub_by_cwd "$SB_P_PATH" "$rpath" 2>/dev/null)"
    case "$by_repo" in '' | *$'\n'*) ;; *) sb_sub_resolve "$by_repo" ;; esac
  fi
  if [ -n "$SB_S_FILE" ]; then
    base="$(sb_sub_value "$SB_S_FILE" base_branch)"
    pattern="$(sb_sub_value "$SB_S_FILE" branch_pattern)"
  else
    base="$(sb_fm_get "$SB_P_PROFILE" base_branch 2>/dev/null)"
    pattern="$(sb_fm_get "$SB_P_PROFILE" branch_pattern 2>/dev/null)"
  fi
  [ -n "$base" ] || base="-"
  [ -n "$pattern" ] || pattern="-"

  if [ "$mode" = show ]; then
    hash="$(sb_br_git "$dir" rev-parse -q --verify "$ref^{commit}" 2>/dev/null)" ||
      sb_die 1 "no ref $ref in $(sb_path_out "$dir")"
    kind="$(sb_br_git "$dir" cat-file -t "$hash:$file" 2>/dev/null)" || sb_die 1 "no file $file at $ref"
    [ "$kind" = blob ] || sb_die 1 "$file at $ref is a folder, not a file"
    sb_br_git "$dir" cat-file blob "$hash:$file"
    return $?
  fi

  ids="$(sb_br_ids "$id" "$tfile")"
  refs="$(sb_br_refs "$dir")"
  carried="$(printf '%s\n' "$refs" | sb_br_carry "$ids")"

  if [ "$mode" = started ]; then
    sb_br_ticket_branch "$id" "$rec" "$refs" "$carried" "$dir"
    IFS=$'\t' read -r tbname hash tbref a <<EOF
$SB_BR_ROW
EOF
    [ "$base" != "-" ] || sb_die 1 "no base_branch is set for $SB_P_NAME"
    # The remote's base branch when there is one, as a build starts from it, else the local one.
    row="$(printf '%s\n' "$refs" | SB_W="$base" awk -F'\t' '
      BEGIN { w = ENVIRON["SB_W"] }
      $3 == "refs/remotes/origin/" w { remote = $0 }
      $3 == "refs/heads/" w { local = $0 }
      END { print (remote != "" ? remote : local) }')"
    [ -n "$row" ] || sb_die 1 "the base branch $base is not in $(sb_path_out "$dir")"
    IFS=$'\t' read -r bname hash bref a <<EOF
$row
EOF
    # Full refs, so that no tag or other ref of the same name is read in their place.
    log="$(sb_br_git "$dir" log --no-show-signature --no-color --format='%h %s' "$bref..$tbref" 2>/dev/null)" ||
      sb_die 1 "git could not read the log of $tbname against $bname"
    stat="$(sb_br_git "$dir" diff --no-ext-diff --no-textconv --no-color --stat=200 "$bref...$tbref" 2>/dev/null)" ||
      sb_die 1 "git could not compare $tbname with $bname"
    printf 'branch: %s\nbase: %s\n' "$tbname" "$bname"
    sb_br_block log "$log"
    sb_br_block stat "$stat"
    return 0
  fi

  current="$(sb_br_git "$dir" symbolic-ref --short -q HEAD 2>/dev/null)" || current=""
  head="$(sb_br_git "$dir" rev-parse -q --verify --short HEAD 2>/dev/null)" || head=""
  if [ -n "$current" ] && [ -n "$(printf '%s\n' "$current" | sb_br_carry "$ids")" ]; then on=yes; fi
  printf 'repo: %s\npath: %s\ncurrent: %s\nhead: %s\n' "$name" "$(sb_path_out "$dir")" "${current:--}" "${head:--}"
  printf 'base_branch: %s\nbranch_pattern: %s\n' "$base" "$pattern"
  sb_br_lines "$carried"
  printf 'recorded: %s\non_ticket: %s\n' "$rec" "$on"
}
