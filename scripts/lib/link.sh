#!/usr/bin/env bash
# link.sh - register the vault's own skills and agents in the link directory by symlink.

# Print the link directory: SECOND_BRAIN_CLAUDE_HOME, else the .claude folder in the home.
sb_link_home() {
  local d="${SECOND_BRAIN_CLAUDE_HOME:-}"
  [ -n "$d" ] || d="${HOME:-}/.claude"
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

# Print the absolute path a symlink points at; a relative target starts at the link's folder.
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

# Print TSV rows: name, kind, state, target, source, place in the link directory.
sb_link_rows() {
  local home pre kind name src fm slot state target nl=$'\n'
  local seen="$nl"
  home="$(sb_link_home)"
  while IFS=$'\t' read -r pre kind name src fm; do
    [ -n "$kind" ] || continue
    slot="$home/${kind}s/${src##*/}"
    if [ "$pre" != "ok" ]; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$kind" "$pre" "$src" "$src" "$slot"
      continue
    fi
    seen="$seen$slot$nl"
    sb_link_slot "$slot" "$src"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$kind" "$SB_LINK_STATE" "${SB_LINK_TARGET:--}" "$src" "$slot"
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
      case "$seen" in *"$nl$slot$nl"*) continue ;; esac
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
  awk -F'\t' '$1 != "" { print $1 " | " $2 " | " $3 " | " $4 }'
}

# Read TSV rows on stdin; return 1 when a row is neither linked nor foreign.
sb_link_clean() {
  awk -F'\t' '$1 != "" && $3 != "linked" && $3 != "foreign" { bad = 1 } END { exit bad }'
}

# Create missing links; repoint or remove only symlinks that lead into the vault.
sb_link_apply() {
  local home name kind state target src slot did
  home="$(sb_link_home)"
  mkdir -p "$home/skills" "$home/agents" || sb_die 1 "cannot create the skills and agents folders in $home"
  while IFS=$'\t' read -r name kind state target src slot; do
    [ -n "$name" ] || continue
    did="linked"
    case "$state" in
      missing) ;;
      wrong-target | dangling)
        [ -L "$slot" ] || continue
        sb_link_in_vault "$target" || continue
        rm -f "$slot" || continue
        did="repointed"
        [ "$src" != "-" ] || sb_note "removed: $kind $name, a dangling link"
        ;;
      *) continue ;;
    esac
    [ "$src" != "-" ] || continue
    if [ -e "$slot" ] || [ -L "$slot" ]; then continue; fi
    ln -s "$src" "$slot" && sb_note "$did: $kind $name"
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
    print "note: " $1 ": a real file or folder holds this name in the link directory; it is left alone"
  }' >&2
  printf '%s\n' "$rows" | sb_link_clean
}
