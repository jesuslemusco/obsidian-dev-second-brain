#!/usr/bin/env bash
# spec.sh - spec-driven delivery: where a story's spec lives, and each repo's validation.md.

# Print a value in lower case when it is one of the allowed ones, else the default.
# Usage: sb_spec_pick <value> <default> <allowed>...
sb_spec_pick() {
  local v d="$2" a
  v="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  shift 2
  for a in "$@"; do
    if [ "$v" = "$a" ]; then
      printf '%s\n' "$v"
      return 0
    fi
  done
  printf '%s\n' "$d"
}

# Print the value of a key that holds: the first file given that has a value for it decides, and
# a value that is not allowed means the default. Files that are not there are skipped.
# Usage: sb_spec_value <delivery | spec_home | validation_home> <file>...
sb_spec_value() {
  local key="$1" f v def=vault other=repo
  shift
  if [ "$key" = "delivery" ]; then
    def=direct
    other=spec
  fi
  for f in "$@"; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    v="$(sb_fm_get "$f" "$key" 2>/dev/null)"
    if [ -n "$v" ]; then
      sb_spec_pick "$v" "$def" "$def" "$other"
      return 0
    fi
  done
  printf '%s\n' "$def"
}

# Print the row of one repo of the current project, matched exact first, then without letter case:
# name, path, state, as sb_repo_rows_at prints it. Returns 1 when it is not a repo of the project.
sb_spec_repo_row() {
  local row
  row="$(sb_repo_rows_at "$SB_P_PATH" | SB_W="$1" awk -F'\t' '
    BEGIN { w = ENVIRON["SB_W"] }
    $1 == w { exact = $0 }
    tolower($1) == tolower(w) && loose == "" { loose = $0 }
    END { print (exact != "" ? exact : loose) }')"
  [ -n "$row" ] || return 1
  printf '%s\n' "$row"
}

# Exit 1 unless a repo row has a folder that exists; the message says which case it is.
sb_spec_need_folder() {
  case "$3" in
    ok) ;;
    missing) sb_die 1 "the folder of $1 is missing: $(sb_path_out "$2")" ;;
    *) sb_die 1 "no location is recorded for $1: set repos_root or repo_paths in $SB_P_PATH/claude/profile.md" ;;
  esac
}

# Resolve the spec of the task in SB_T_FILE. Sets SB_SP_DELIVERY, SB_SP_HOME, SB_SP_REPO (or "-"),
# SB_SP_DIR (absolute) and SB_SP_SHOW (the folder as it is printed). Exits 1, with the reason, when
# the spec lives in a repo that cannot be reached.
sb_spec_resolve() {
  local sub="" subfile="" row name path state
  sub="$(sb_fm_get "$SB_T_FILE" subproject 2>/dev/null)"
  if [ -n "$sub" ] && sb_sub_resolve "$sub"; then subfile="$SB_S_FILE"; fi
  SB_SP_DELIVERY="$(sb_spec_value delivery "$SB_T_FILE" "$subfile" "$SB_P_PROFILE")"
  SB_SP_HOME="$(sb_spec_value spec_home "$subfile" "$SB_P_PROFILE")"
  # The story's repo: its subproject's first, else the project's first, as repo lists them.
  SB_SP_REPO=""
  [ -z "$subfile" ] || SB_SP_REPO="$(sb_fm_list "$subfile" repos 2>/dev/null | head -1)"
  [ -n "$SB_SP_REPO" ] || SB_SP_REPO="$(sb_repo_rows_at "$SB_P_PATH" | head -1 | cut -f1)"
  if [ "$SB_SP_HOME" = "vault" ]; then
    SB_SP_DIR="$(dirname "$SB_T_FILE")/spec"
    SB_SP_SHOW="$(sb_rel "$SB_SP_DIR")"
    [ -n "$SB_SP_REPO" ] || SB_SP_REPO="-"
    return 0
  fi
  [ -n "$SB_SP_REPO" ] || sb_die 1 "$SB_P_NAME lists no repo for the spec: add one to repos in $SB_P_PATH/claude/profile.md"
  row="$(sb_spec_repo_row "$SB_SP_REPO")" || sb_die 1 "$SB_SP_REPO is not in repos of $SB_P_NAME"
  IFS=$'\t' read -r name path state <<EOF
$row
EOF
  sb_spec_need_folder "$name" "$path" "$state"
  SB_SP_REPO="$name"
  SB_SP_DIR="$path/spec/$SB_T_ID"
  SB_SP_SHOW="$(sb_path_out "$SB_SP_DIR")"
}

# Write one spec file unless it exists; print its path when created.
sb_spec_write() {
  local part="$1" label="$2" dest="$SB_SP_DIR/$1.md" show="$SB_SP_SHOW/$1.md" title text
  if [ -e "$dest" ]; then
    printf 'exists: %s\n' "$show" >&2
    return 0
  fi
  title="$(sb_fm_get "$SB_T_FILE" title 2>/dev/null)"
  [ -n "$title" ] || title="$SB_T_ID"
  text="$(sb_fill_text "spec-$part.md.tmpl" "ID=$SB_T_ID" "TITLE=$title")" || exit 2
  case "$text" in *'{{'*) sb_die 5 "a placeholder was left unfilled in spec-$part.md.tmpl, or the title contains {{" ;; esac
  mkdir -p "$SB_SP_DIR" || sb_die 1 "cannot create $SB_SP_SHOW"
  if [ "$SB_SP_HOME" = "vault" ]; then
    printf -- '---\naliases:\n  - "%s %s"\ntype: spec\ntags:\n  - type/spec\n---\n\n> Up: [[%s|%s]]\n\n%s\n' \
      "$SB_T_ID" "$label" "${SB_T_REL%.md}" "$SB_T_ID" "$text" >"$dest" || sb_die 1 "cannot write $show"
  else
    printf '%s\n' "$text" >"$dest" || sb_die 1 "cannot write $show"
  fi
  printf '%s\n' "$show"
}

# second-brain spec <ID> | spec new <ID>, each with [--project P].
cmd_spec() {
  local new=0 id="" project=""
  local usage="usage: second-brain spec <ID> [--project P] | spec new <ID> [--project P]"
  if [ "${1:-}" = "new" ]; then
    new=1
    shift
  fi
  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        [ $# -ge 2 ] || sb_die 5 "--project needs a value"
        project="$2"
        shift 2
        ;;
      -*) sb_die 5 "$usage" ;;
      *)
        [ -z "$id" ] || sb_die 5 "$usage"
        id="$1"
        shift
        ;;
    esac
  done
  [ -n "$id" ] || sb_die 5 "$usage"
  sb_need_task "$id" "$project"
  sb_need_profile
  sb_spec_resolve
  if [ "$new" -eq 1 ]; then
    sb_spec_write requirements Requirements
    sb_spec_write design Design
    sb_spec_write tasks Tasks
    return 0
  fi
  printf 'id: %s\ndelivery: %s\nspec_home: %s\nrepo: %s\ndir: %s\n' \
    "$SB_T_ID" "$SB_SP_DELIVERY" "$SB_SP_HOME" "$SB_SP_REPO" "$SB_SP_SHOW"
  printf 'requirements: %s/requirements.md\ndesign: %s/design.md\ntasks: %s/tasks.md\n' \
    "$SB_SP_SHOW" "$SB_SP_SHOW" "$SB_SP_SHOW"
}

# Print the state of a repo's section of a validation.md: missing (no file), no-section, empty (a
# heading with nothing under it) or ok.
sb_val_state() {
  local body
  [ -f "$1" ] || { printf 'missing\n'; return 0; }
  if ! body="$(sb_section "$1" "$2" 2>/dev/null)"; then
    printf 'no-section\n'
  elif [ -z "$body" ]; then
    printf 'empty\n'
  else
    printf 'ok\n'
  fi
}

# Print one validation row per repo of the current project, or of the one repo named exactly:
# name, home, absolute file (or "-"), shown path (or "-"), state, repo state. State is ok, missing,
# no-section, empty, or unknown for a repo home with no recorded location.
sb_val_rows() {
  local only="${1:-}" nl=$'\n' tab=$'\t' f h r rest lower name path rstate home file show
  local phome map="$nl"
  phome="$(sb_spec_value validation_home "$SB_P_PROFILE")"
  # Read each subproject note once: its repos, in lower case, with the home it sets.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    h="$(sb_fm_get "$f" validation_home 2>/dev/null)"
    [ -n "$h" ] || continue
    h="$(sb_spec_pick "$h" vault vault repo)"
    while IFS= read -r r; do
      [ -n "$r" ] && map="$map$r$tab$h$nl"
    done <<EOF2
$(sb_fm_list "$f" repos 2>/dev/null | tr '[:upper:]' '[:lower:]')
EOF2
  done <<EOF
$(sb_sub_files "$SB_P_PATH")
EOF
  while IFS=$'\t' read -r name path rstate; do
    [ -n "$name" ] || continue
    [ -z "$only" ] || [ "$name" = "$only" ] || continue
    home="$phome"
    lower="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
    case "$map" in
      *"$nl$lower$tab"*)
        rest="${map#*"$nl$lower$tab"}"
        home="${rest%%"$nl"*}"
        ;;
    esac
    if [ "$home" = "vault" ]; then
      file="$SB_P_DIR/claude/validation.md"
      show="$SB_P_PATH/claude/validation.md"
    elif [ "$path" = "-" ]; then
      printf '%s\trepo\t-\t-\tunknown\t%s\n' "$name" "$rstate"
      continue
    else
      file="$path/validation.md"
      show="$(sb_path_out "$file")"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$home" "$file" "$show" "$(sb_val_state "$file" "$name")" "$rstate"
  done <<EOF
$(sb_repo_rows_at "$SB_P_PATH")
EOF
}

# Return 0 when a repo's section of a validation.md still holds a placeholder of
# validation-repo.md.tmpl: text in angle brackets, as the doctor's placeholders check reads it.
sb_val_placeholders() {
  sb_section "$1" "$2" 2>/dev/null | LC_ALL=C SB_T="$(sb_plugin_root)/templates/validation-repo.md.tmpl" awk '
    function spans(s,   i, j, n, c, code, start) {
      n = 0; code = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "`") { code = !code; start = i + 1; continue }
        if (c != "<" || (code && i != start)) continue
        j = index(substr(s, i + 1), ">")
        if (j < 2 || substr(s, i + 1, 1) ~ /[ \t]/) continue
        sp[++n] = substr(s, i, j + 1); i += j
      }
      return n
    }
    BEGIN {
      t = ENVIRON["SB_T"]
      while ((getline line < t) > 0) { m = spans(line); for (k = 1; k <= m; k++) ph[sp[k]] = 1 }
      close(t)
    }
    { sub(/\r$/, ""); m = spans($0); for (k = 1; k <= m; k++) if (sp[k] in ph) { found = 1; exit } }
    END { exit(found ? 0 : 1) }'
}

# Add a repo's section to a validation.md, writing the file when it is missing. The section is
# added after one blank line, in the line endings the file has.
sb_val_write() {
  local name="$1" home="$2" file="$3" show="$4" text
  case "$(sb_val_state "$file" "$name")" in
    ok | empty)
      printf 'exists: %s\n' "$show" >&2
      return 0
      ;;
  esac
  text="$(sb_fill_text validation-repo.md.tmpl "REPO=$name")" || exit 2
  case "$text" in *'{{'*) sb_die 5 "a placeholder was left unfilled in validation-repo.md.tmpl" ;; esac
  if [ ! -f "$file" ]; then
    if [ "$home" = "vault" ]; then
      sb_fill validation.md.tmpl "$file" "PROJECT=$SB_P_NAME" "PROJECT_PATH=$SB_P_PATH" || sb_die 1 "cannot write $show"
    else
      printf '# %s validation\n\nHow to run and check %s. Agents read the section below before they build or\nreview a change.\n' \
        "$name" "$name" >"$file" || sb_die 1 "cannot write $show"
    fi
  fi
  sb_body_append "$file" "$text" || sb_die 1 "cannot write $show"
  printf '%s\n' "$show"
}

# second-brain validation <project> [repo] | validation new <project> <repo>
cmd_validation() {
  local new=0 a project="" repo="" row name home file show state rstate n=0
  local usage="usage: second-brain validation <project> [repo] | validation new <project> <repo>"
  if [ "${1:-}" = "new" ]; then
    new=1
    shift
  fi
  for a in "$@"; do
    case "$a" in -*) sb_die 5 "$usage" ;; esac
    n=$((n + 1))
  done
  if [ "$new" -eq 1 ]; then [ "$n" -eq 2 ] || sb_die 5 "$usage"; fi
  [ "$n" -ge 1 ] && [ "$n" -le 2 ] || sb_die 5 "$usage"
  project="$1"
  repo="${2:-}"
  sb_need_project "$project"
  sb_need_profile
  if [ -z "$repo" ]; then
    sb_val_rows | awk -F'\t' '{ print $1 "\t" $2 "\t" $4 "\t" $5 }'
    return 0
  fi
  row="$(sb_spec_repo_row "$repo")" || sb_die 1 "$repo is not in repos of $SB_P_NAME ($SB_P_PATH/claude/profile.md)"
  IFS=$'\t' read -r name file state <<EOF
$row
EOF
  row="$(sb_val_rows "$name")"
  IFS=$'\t' read -r name home file show state rstate <<EOF
$row
EOF
  [ "$state" != "unknown" ] || sb_die 1 "no location is recorded for $name: set repos_root or repo_paths in $SB_P_PATH/claude/profile.md"
  if [ "$home" = "repo" ] && [ "$rstate" != "ok" ]; then
    sb_die 1 "the folder of $name is missing: $(sb_path_out "${file%/validation.md}")"
  fi
  if [ "$new" -eq 1 ]; then
    sb_val_write "$name" "$home" "$file" "$show"
    return 0
  fi
  case "$state" in
    missing) sb_die 1 "no validation.md for $name: run second-brain validation new \"$SB_P_NAME\" $name" ;;
    no-section) sb_die 1 "$show has no ## $name section: run second-brain validation new \"$SB_P_NAME\" $name" ;;
  esac
  printf 'path: %s\n' "$show"
  sb_section "$file" "$name" || true
}
