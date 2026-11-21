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
    case "/$path/" in */../* | *\\*) continue ;; esac
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

# Create missing links; repoint or remove only links that lead into the vault. With a kind and a
# name, only the rows of that skill or agent.
sb_link_apply() {
  local only_kind="${1:-}" only_name="${2:-}" home name kind state target src slot did nl=$'\n'
  local made="$nl"
  home="$(sb_link_home)"
  mkdir -p "$home/skills" "$home/agents" || sb_die 1 "cannot create the skills and agents folders in $(sb_path_out "$home")"
  while IFS=$'\t' read -r name kind state target src slot; do
    [ -n "$name" ] || continue
    if [ -n "$only_kind" ]; then
      [ "$kind" = "$only_kind" ] && [ "$name" = "$only_name" ] || continue
    fi
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

# Print where a link leads, its folders made physical: the whole path when it leads to a folder.
# Return 1 when the path is no link or cannot be read.
sb_link_leads() {
  local t
  [ -L "$1" ] || return 1
  t="$(readlink "$1")" || return 1
  case "$t" in /*) ;; *) t="${1%/*}/$t" ;; esac
  if [ -d "$t" ]; then
    t="$(cd -P "$t" 2>/dev/null && pwd -P)" || return 1
  elif [ -d "${t%/*}" ]; then
    t="$(cd -P "${t%/*}" 2>/dev/null && pwd -P)/${t##*/}"
  fi
  printf '%s\n' "$t"
}

# Return 0 when a link leads inside the plugin.
sb_link_in_plugin() {
  local root t
  root="$(cd -P "$(sb_plugin_root)" 2>/dev/null && pwd -P)" || return 1
  [ -n "$root" ] || return 1
  t="$(sb_link_leads "$1")" || return 1
  case "$t/" in "$root"/*) return 0 ;; esac
  return 1
}

# Print TSV rows for the foreign skills and agents: name, kind, what (folder, file or link),
# target (where a link leads, else -), place in the link directory. A skill is a folder that
# holds SKILL.md, an agent a .md file, or a link to one. A link into the plugin is left out.
sb_link_foreign() {
  local name kind state target src slot what
  while IFS=$'\t' read -r name kind state target src slot; do
    [ "$state" = "foreign" ] || continue
    if [ "$kind" = "skill" ]; then
      [ -d "$slot" ] && [ -f "$slot/SKILL.md" ] || continue
      what="folder"
    else
      case "$slot" in *.md) ;; *) continue ;; esac
      [ -f "$slot" ] || continue
      what="file"
    fi
    if [ -L "$slot" ]; then
      ! sb_link_in_plugin "$slot" || continue
      what="link"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$kind" "$what" "${target:--}" "$slot"
  done <<EOF
$(sb_link_rows)
EOF
}

# Add a row to the table under the heading of a skill (## Skills) or an agent (## Agents) in a
# README.md, after its last row; keeps line endings. With no table under the heading, a new table
# ends the section; with no heading, the heading and the table end the file. Return 1 when a row
# names the item already, 2 when the file is missing, 3 when it cannot be written.
sb_link_list() {
  local file="$1" kind="$2" name="$3" row="$4" head="## Skills" top="| Skill | Use when |" tmp eofnl=1 rc=0
  [ -f "$file" ] || return 2
  if [ "$kind" = "agent" ]; then
    head="## Agents"
    top="| Agent | Use when |"
  fi
  if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then eofnl=0; fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/sb-list.XXXXXX")" || return 3
  LC_ALL=C SB_H="$head" SB_TOP="$top" SB_ROW="$row" SB_N="$name" SB_EOFNL="$eofnl" awk '
    # The name in the first cell of a table row: the alias of a link, with no backticks.
    function first(s,   c, i) {
      gsub(/\\\|/, "\001", s)
      sub(/^[ \t]*\|/, "", s)
      c = s; sub(/\|.*/, "", c)
      if ((i = index(c, "\001")) > 0) c = substr(c, i + 1)
      gsub(/\[\[|\]\]|`/, "", c); sub(/^[ \t]+/, "", c); sub(/[ \t]+$/, "", c)
      return c
    }
    { raw[NR] = $0; t = $0; sub(/\r$/, "", t); line[NR] = t; if (NR == 1 && t != $0) eol = "\r" }
    END {
      n = NR; want = tolower(ENVIRON["SB_H"]); s = 0; e = n + 1; fence = 0
      for (i = 1; i <= n; i++) {
        t = line[i]
        if (t ~ /^[ \t]*(```|~~~)/) { fence = !fence; continue }
        if (fence) continue
        if (!s) { h = tolower(t); sub(/[ \t]+$/, "", h); if (h == want) s = i; continue }
        if (t ~ /^##?[ \t]/) { e = i; break }
      }
      ta = 0; tb = 0
      for (i = s + 1; s && i < e; i++) {
        if (line[i] ~ /^[ \t]*\|/) { if (!ta) ta = i; tb = i } else if (ta) break
      }
      for (i = ta + 1; ta && i <= tb; i++) if (first(line[i]) == ENVIRON["SB_N"]) exit 1
      na = 0
      if (ta) {
        at = tb
      } else if (s) {
        at = s
        for (i = s + 1; i < e; i++) if (line[i] !~ /^[ \t]*$/) at = i
        add[++na] = ""
      } else {
        at = n
        if (n > 0 && line[n] !~ /^[ \t]*$/) add[++na] = ""
        add[++na] = ENVIRON["SB_H"]; add[++na] = ""
      }
      if (!ta) { add[++na] = ENVIRON["SB_TOP"]; add[++na] = "|---|---|" }
      add[++na] = ENVIRON["SB_ROW"]
      sep = ""
      for (i = 0; i <= n; i++) {
        if (i > 0) { printf "%s%s", sep, raw[i]; sep = "\n" }
        if (i == at) for (j = 1; j <= na; j++) { printf "%s%s", sep, add[j] eol; sep = "\n" }
      }
      if (ENVIRON["SB_EOFNL"] + 0 || at == n) printf "\n"
    }' "$file" >"$tmp" || rc=$?
  if [ "$rc" -eq 0 ]; then cat "$tmp" >"$file" || rc=3; fi
  rm -f "$tmp"
  return "$rc"
}

# Move one foreign skill or agent into the vault's claude folder, or a project's, then link it
# and list it there: link move <skill|agent> <name> [--project P].
sb_link_move() {
  local usage="usage: second-brain link move <skill|agent> <name> [--project P]"
  local kind="" name="" project="" row rname rkind what target slot rel dest file fm from desc readme rows rc=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        [ $# -ge 2 ] && [ -n "$2" ] || sb_die 5 "$usage"
        project="$2"
        shift
        ;;
      -*) sb_die 5 "$usage" ;;
      *)
        if [ -z "$kind" ]; then
          kind="$1"
        elif [ -z "$name" ]; then
          name="$1"
        else
          sb_die 5 "$usage"
        fi
        ;;
    esac
    shift
  done
  if [ -z "$kind" ] || [ -z "$name" ]; then sb_die 5 "$usage"; fi
  case "$kind" in skill | agent) ;; *) sb_die 5 "$usage" ;; esac
  case "$name" in */* | .* | *\\*) sb_die 5 "not a skill or agent name: $name" ;; esac
  sb_need_root
  rel="claude"
  if [ -n "$project" ]; then
    sb_need_project "$project"
    sb_graph_path "$SB_P_PATH/claude"
    rel="$SB_GRAPH_PATH"
  fi
  row="$(sb_link_foreign | SB_K="$kind" SB_N="$name" awk -F'\t' '$1 == ENVIRON["SB_N"] && $2 == ENVIRON["SB_K"]')"
  [ -n "$row" ] || sb_die 1 "no foreign $kind named $name in $(sb_path_out "$(sb_link_home)/${kind}s") (list them with: second-brain link --foreign)"
  IFS=$'\t' read -r rname rkind what target slot <<EOF
$row
EOF
  # What moves: the entry itself, or what a link leads to.
  from="$slot"
  [ "$what" != "link" ] || from="$target"
  if [ "$kind" = "skill" ]; then
    file="$from/SKILL.md"
    dest="$rel/skills/$name"
  else
    file="$from"
    dest="$rel/agents/$name.md"
  fi
  fm="$(sb_fm_get "$file" name 2>/dev/null)"
  [ -n "$fm" ] || sb_die 5 "$rname has no name in its frontmatter: add name: $name first"
  [ "$fm" = "$name" ] || sb_die 5 "the name in its frontmatter is $fm, not $name: make them the same first"
  sb_graph_spell "$dest" ""
  if [ -e "$SB_ROOT/$dest" ] || [ -L "$SB_ROOT/$dest" ]; then sb_die 6 "the destination exists: $dest"; fi
  if [ "$what" = "link" ] && sb_link_in_vault "$target"; then
    # Inside the vault it moves as move moves it, so the links to it are rewritten. The link left
    # behind leads into the vault, and linking the item replaces it.
    sb_graph_path "${target#"$SB_ROOT"/}"
    from="$SB_GRAPH_PATH"
    if sb_graph_link "$from" itself || sb_graph_link "$dest"; then
      sb_die 5 "$SB_GRAPH_LINK is a symlink, and the helper does not look behind one"
    fi
    sb_graph_move "$from" "$dest" 0
  else
    mkdir -p "$SB_ROOT/${dest%/*}" || sb_die 1 "cannot create the folder $(sb_path_out "$SB_ROOT/${dest%/*}")"
    if [ "$what" = "link" ]; then
      # Out of the vault it is copied, so whatever else uses it there keeps it.
      if [ "$kind" = "skill" ]; then
        mkdir "$SB_ROOT/$dest" && cp -R "$from/." "$SB_ROOT/$dest/"
      else
        cp "$from" "$SB_ROOT/$dest"
      fi || {
        rm -rf "$SB_ROOT/$dest"
        sb_die 1 "cannot copy $(sb_path_out "$from") to $dest; nothing was changed"
      }
      sb_rmlink "$slot" || sb_die 1 "copied to $dest, but cannot remove the link $(sb_path_out "$slot")"
      printf 'copied: %s -> %s\n' "$(sb_path_out "$from")" "$dest"
      sb_note "the original stays where it was: $(sb_path_out "$from")"
    else
      mv "$slot" "$SB_ROOT/$dest" || sb_die 1 "cannot move $(sb_path_out "$slot") to $dest"
      printf 'moved: %s -> %s\n' "$(sb_path_out "$slot")" "$dest"
    fi
  fi
  sb_link_apply "$kind" "$name"
  if [ "$kind" = "skill" ]; then
    desc="$(sb_fm_get "$SB_ROOT/$dest/SKILL.md" description 2>/dev/null)"
    file="$dest/SKILL"
  else
    desc="$(sb_fm_get "$SB_ROOT/$dest" description 2>/dev/null)"
    file="${dest%.md}"
  fi
  # A block scalar's text is on the lines below the key, which a table cell cannot hold.
  case "$desc" in '>'* | '|'*) desc="" ;; esac
  desc="$(printf '%s' "$desc" | tr '\t\r\n' '   ')"
  desc="${desc//|/\\|}"
  readme="$rel/README.md"
  sb_link_list "$SB_ROOT/$readme" "$kind" "$name" "| [[$file\\|$name]] | ${desc:--} |" || rc=$?
  case "$rc" in
    0) printf 'listed: %s\n' "$readme" ;;
    1) sb_note "$readme lists $name already" ;;
    2) sb_note "no $readme, so $name is not listed: add its row by hand" ;;
    *) sb_note "cannot write $readme, so $name is not listed: add its row by hand" ;;
  esac
  rows="$(sb_link_rows | SB_K="$kind" SB_N="$name" awk -F'\t' '$1 == ENVIRON["SB_N"] && $2 == ENVIRON["SB_K"]')"
  printf '%s\n' "$rows" | sb_link_format
  printf '%s\n' "$rows" | awk -F'\t' '$1 != "" { n++; if ($3 != "linked") bad = 1 } END { exit (bad || !n) }'
}

# Report the links, create and repair them with --apply, list the foreign skills and agents with
# --foreign, or move one into the vault with move.
cmd_link() {
  local mode="check" rows
  local usage="usage: second-brain link [--check | --apply | --foreign] | link move <skill|agent> <name> [--project P]"
  if [ "${1:-}" = "move" ]; then
    shift
    sb_link_move "$@"
    return $?
  fi
  [ $# -le 1 ] || sb_die 5 "$usage"
  case "${1:-}" in
    '' | --check) mode="check" ;;
    --apply) mode="apply" ;;
    --foreign) mode="foreign" ;;
    *) sb_die 5 "$usage" ;;
  esac
  sb_need_root
  if [ "$mode" = "foreign" ]; then
    sb_link_foreign | sb_link_format
    return 0
  fi
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
