#!/usr/bin/env bash
# link.sh - the pointer to the vault, and the links that register the vault's own skills and agents.

# Print the link directory: SECOND_BRAIN_CLAUDE_HOME, else the .claude folder in the home.
sb_link_home() {
  local d="${SECOND_BRAIN_CLAUDE_HOME:-}"
  [ -n "$d" ] || d="${HOME:-}/.claude"
  d="$(sb_path_in "$d")"
  printf '%s\n' "${d%/}"
}

# Print an absolute path with . and .. folded and its parent folders made physical.
sb_link_abs() {
  local rest="$1" out="" seg tail="" phys
  case "$rest" in /*) ;; *) rest="$PWD/$rest" ;; esac
  while [ -n "$rest" ]; do
    seg="${rest%%/*}"
    case "$rest" in */*) rest="${rest#*/}" ;; *) rest="" ;; esac
    case "$seg" in
      '' | .) ;;
      ..) out="${out%/*}" ;;
      *) out="$out/$seg" ;;
    esac
  done
  while [ -n "$out" ]; do
    tail="/${out##*/}$tail"
    out="${out%/*}"
    [ ! -d "${out:-/}" ] || break
  done
  phys="$(cd -P "${out:-/}" 2>/dev/null && pwd -P)" || phys="$out"
  [ "$phys" = "/" ] && phys=""
  out="$phys$tail"
  printf '%s\n' "${out:-/}"
}

# Print the absolute path a link points at; a relative target starts at the link's folder.
sb_link_target() {
  local t dir
  t="$(readlink "$1")" || return 1
  case "$t" in
    /*) ;;
    *)
      dir="$(cd -P "$(dirname "$1")" 2>/dev/null && pwd -P)" || dir="$(dirname "$1")"
      t="$dir/$t"
      ;;
  esac
  sb_link_abs "$t"
}

# Return 0 when a path is the vault root or lies inside it.
sb_link_in_vault() {
  case "$1/" in "$SB_ROOT"/*) return 0 ;; esac
  return 1
}

# Print kind, name, path and frontmatter name for the skills and agents of one claude folder.
sb_link_sources_in() {
  local dir="$1" f name fm
  for f in "$dir"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    f="${f%/SKILL.md}"
    name="${f##*/}"
    fm="$(sb_fm_get "$f/SKILL.md" name 2>/dev/null)"
    printf 'skill\t%s\t%s\t%s\n' "$name" "$f" "${fm:--}"
  done
  for f in "$dir"/agents/*.md; do
    [ -f "$f" ] || continue
    name="${f##*/}"
    case "$name" in [Rr][Ee][Aa][Dd][Mm][Ee].md) continue ;; esac
    fm="$(sb_fm_get "$f" name 2>/dev/null)"
    printf 'agent\t%s\t%s\t%s\n' "${name%.md}" "$f" "${fm:--}"
  done
}

# Print the sources of the vault folder and of every index project, each claude folder once.
sb_link_sources() {
  local name path keys dir seen nl=$'\n'
  sb_link_sources_in "$SB_ROOT/claude"
  seen="$nl$SB_ROOT/claude$nl"
  while IFS=$'\t' read -r name path keys; do
    [ -n "$path" ] || continue
    case "/$path/" in */../*) continue ;; esac
    dir="$SB_ROOT/$path/claude"
    case "$seen" in *"$nl$dir$nl"*) continue ;; esac
    seen="$seen$dir$nl"
    sb_link_sources_in "$dir"
  done <<EOF
$(sb_projects_tsv 2>/dev/null)
EOF
}

# Set SB_LINK_SLOT and SB_LINK_SRC: the place a source links at, and what the link there leads to.
# On Windows the agents of one claude folder share one junction, to its agents folder.
sb_link_place() {
  local home="$1" kind="$2" src="$3" dir
  SB_LINK_SLOT="$home/${kind}s/${src##*/}"
  SB_LINK_SRC="$src"
  if [ "$kind" = "agent" ] && sb_is_windows; then
    SB_LINK_SRC="${src%/*}"
    dir="${SB_LINK_SRC%/claude/agents}"
    if [ "$dir" = "$SB_ROOT" ]; then
      SB_LINK_SLOT="$home/agents/second-brain-vault"
    else
      dir="${dir#"$SB_ROOT"/}"
      SB_LINK_SLOT="$home/agents/second-brain-project-${dir//\//-}"
    fi
  fi
}

# Set SB_LINK_STATE and SB_LINK_TARGET for the place a source links at.
sb_link_slot() {
  local slot="$1" src="$2"
  SB_LINK_STATE="missing"
  SB_LINK_TARGET="$src"
  if [ -L "$slot" ]; then
    if [ ! -e "$slot" ]; then
      SB_LINK_STATE="dangling"
      SB_LINK_TARGET="$(sb_link_target "$slot")"
    elif [ "$slot" -ef "$src" ]; then
      SB_LINK_STATE="linked"
    else
      SB_LINK_STATE="wrong-target"
      SB_LINK_TARGET="$(sb_link_target "$slot")"
    fi
  elif [ -e "$slot" ]; then
    SB_LINK_STATE="wrong-target"
    SB_LINK_TARGET="-"
  fi
}

# Print TSV rows: name, kind, state, target, what the link leads to, place in the link directory.
# A place that another folder's link holds already makes a duplicate: on Windows two project
# paths that differ only by a slash and a hyphen give one junction name.
sb_link_rows() {
  local home pre kind name src fm slot state target nl=$'\n' tab=$'\t'
  local seen="$nl"
  home="$(sb_link_home)"
  while IFS=$'\t' read -r pre kind name src fm; do
    [ -n "$kind" ] || continue
    sb_link_place "$home" "$kind" "$src"
    slot="$SB_LINK_SLOT"
    if [ "$pre" = "ok" ]; then
      case "$seen" in
        *"$nl$slot$tab$SB_LINK_SRC$nl"*) ;;
        *"$nl$slot$tab"*) pre="duplicate" ;;
        *) seen="$seen$slot$tab$SB_LINK_SRC$nl" ;;
      esac
    fi
    if [ "$pre" != "ok" ]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$kind" "$pre" "$src" "$SB_LINK_SRC" "$slot"
      continue
    fi
    sb_link_slot "$slot" "$SB_LINK_SRC"
    case "$SB_LINK_STATE" in missing | linked) SB_LINK_TARGET="$src" ;; esac
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$kind" "$SB_LINK_STATE" "${SB_LINK_TARGET:--}" "$SB_LINK_SRC" "$slot"
  done <<EOF
$(sb_link_sources | awk -F'\t' '
  { row[NR] = $0; key[NR] = $1 "/" $2; count[key[NR]]++; bad[NR] = ($4 != $2) }
  END {
    for (i = 1; i <= NR; i++)
      print (bad[i] ? "name-mismatch" : (count[key[i]] > 1 ? "duplicate" : "ok")) "\t" row[i]
  }')
EOF
  for kind in skill agent; do
    for slot in "$home/${kind}s"/*; do
      if [ ! -e "$slot" ] && [ ! -L "$slot" ]; then continue; fi
      case "$seen" in *"$nl$slot$tab"*) continue ;; esac
      name="${slot##*/}"
      [ "$kind" = "skill" ] || name="${name%.md}"
      state="foreign"
      target="-"
      if [ -L "$slot" ]; then
        target="$(sb_link_target "$slot")"
        [ -e "$slot" ] || state="dangling"
      fi
      printf '%s\t%s\t%s\t%s\t-\t%s\n' "$name" "$kind" "$state" "${target:--}" "$slot"
    done
  done
}

# Print one row per skill, agent or stray link: name | kind | state | target.
sb_link_scan() {
  sb_need_root
  sb_link_rows | sb_link_format
}

# Read TSV rows on stdin; print them as name | kind | state | target.
sb_link_format() {
  local name kind state target rest
  while IFS=$'\t' read -r name kind state target rest; do
    [ -n "$name" ] || continue
    printf '%s | %s | %s | ' "$name" "$kind" "$state"
    if [ "$target" = "-" ]; then printf '%s\n' "-"; else sb_path_out "$target"; fi
  done
}

# Read TSV rows on stdin; return 1 when a row is neither linked nor foreign.
sb_link_clean() {
  awk -F'\t' '$1 != "" && $3 != "linked" && $3 != "foreign" { bad = 1 } END { exit bad }'
}

# Create missing links; repoint or remove only links that lead into the vault.
sb_link_apply() {
  local home name kind state target src slot did nl=$'\n'
  local made="$nl"
  home="$(sb_link_home)"
  mkdir -p "$home/skills" "$home/agents" || sb_die 1 "cannot create the skills and agents folders in $(sb_path_out "$home")"
  while IFS=$'\t' read -r name kind state target src slot; do
    [ -n "$name" ] || continue
    did="linked"
    case "$state" in
      missing) ;;
      wrong-target | dangling) did="repointed" ;;
      *) continue ;;
    esac
    case "$made" in
      *"$nl$slot$nl"*)
        sb_note "$did: $kind $name"
        continue
        ;;
    esac
    if [ "$did" = "repointed" ]; then
      [ -L "$slot" ] || continue
      sb_link_in_vault "$target" || continue
      sb_rmlink "$slot" || continue
      [ "$src" != "-" ] || sb_note "removed: $kind $name, a dangling link"
    fi
    [ "$src" != "-" ] || continue
    if [ -e "$slot" ] || [ -L "$slot" ]; then continue; fi
    sb_mklink "$src" "$slot" || continue
    made="$made$slot$nl"
    sb_note "$did: $kind $name"
  done <<EOF
$(sb_link_rows)
EOF
}

# Report the links, or create and repair them with --apply.
cmd_link() {
  local mode="check" rows
  local usage="usage: second-brain link [--check | --apply]"
  [ $# -le 1 ] || sb_die 5 "$usage"
  case "${1:-}" in
    '' | --check) mode="check" ;;
    --apply) mode="apply" ;;
    *) sb_die 5 "$usage" ;;
  esac
  sb_need_root
  [ "$mode" = "check" ] || sb_link_apply
  rows="$(sb_link_rows)"
  printf '%s\n' "$rows" | sb_link_format
  printf '%s\n' "$rows" | awk -F'\t' '$3 == "wrong-target" && $4 == "-" {
    held = $6; sub(/.*\//, "", held)
    held = (held == $1 || held == $1 ".md") ? "this name" : "the name " held
    print "note: " $1 ": a real file or folder holds " held " in the link directory; it is left alone"
  }' >&2
  printf '%s\n' "$rows" | sb_link_clean
}

# Print where the pointer leads, or create it: pointer set <DIR> [--replace].
cmd_pointer() {
  local usage="usage: second-brain pointer | pointer set <DIR> [--replace]"
  local ptr dir="" replace=0 leads
  ptr="$(sb_link_home)/second-brain-vault"
  if [ $# -eq 0 ]; then
    if [ ! -L "$ptr" ]; then
      [ ! -e "$ptr" ] || sb_die 2 "no pointer: a real file or folder holds its place: $(sb_path_out "$ptr")"
      sb_die 2 "no pointer: $(sb_path_out "$ptr") is missing (run vault-setup init)"
    fi
    if [ -d "$ptr" ]; then
      leads="$(cd -P "$ptr" 2>/dev/null && pwd -P)" || sb_die 2 "cannot open the folder the pointer leads to"
    else
      leads="$(sb_link_target "$ptr")"
      sb_note "the pointer leads to a folder that is missing"
    fi
    sb_path_out "$leads"
    return 0
  fi
  [ "$1" = "set" ] || sb_die 5 "$usage"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --replace) replace=1 ;;
      -*) sb_die 5 "$usage" ;;
      *)
        [ -z "$dir" ] || sb_die 5 "$usage"
        dir="$1"
        ;;
    esac
    shift
  done
  [ -n "$dir" ] || sb_die 5 "$usage"
  dir="$(sb_path_in "$dir")"
  [ -d "$dir/.obsidian" ] || sb_die 5 "not a vault, it has no .obsidian folder: $(sb_path_out "$dir")"
  dir="$(cd -P "$dir" 2>/dev/null && pwd -P)" || sb_die 5 "cannot open the folder: $(sb_path_out "$dir")"
  if [ -L "$ptr" ]; then
    if [ "$ptr" -ef "$dir" ]; then
      sb_path_out "$dir"
      return 0
    fi
    leads="$(sb_link_target "$ptr")"
    [ "$replace" -eq 1 ] || sb_die 6 "the pointer leads elsewhere: $(sb_path_out "$leads") (add --replace to repoint it)"
    sb_rmlink "$ptr" || sb_die 1 "cannot remove the pointer: $(sb_path_out "$ptr")"
  elif [ -e "$ptr" ]; then
    sb_die 6 "a real file or folder holds the pointer's place and is never replaced: $(sb_path_out "$ptr")"
  fi
  mkdir -p "${ptr%/*}" || sb_die 1 "cannot create the link directory: $(sb_path_out "${ptr%/*}")"
  sb_mklink "$dir" "$ptr" || sb_die 1 "cannot create the pointer: $(sb_path_out "$ptr")"
  sb_path_out "$dir"
}
