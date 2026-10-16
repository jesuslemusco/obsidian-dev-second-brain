#!/usr/bin/env bash
# projects.sh - the index table, project resolution, the profile and the context block.

# Print one TSV row per project in the index: name, path, keys.
sb_projects_tsv() {
  sb_need_root
  [ -f "$SB_ROOT/CLAUDE.md" ] || return 1
  LC_ALL=C awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function cells(s, c,   n, i, ch, cur, len) {
      n = 0; cur = ""; len = length(s)
      for (i = 1; i <= len; i++) {
        ch = substr(s, i, 1)
        if (ch == "\\" && substr(s, i + 1, 1) == "|") { cur = cur "|"; i++; continue }
        if (ch == "|") { c[++n] = trim(cur); cur = ""; continue }
        cur = cur ch
      }
      c[++n] = trim(cur)
      return n
    }
    { sub(/\r$/, "") }
    /^#[#]? / { insec = (tolower($0) ~ /^##[ \t]+projects[ \t]*$/); hdr = 0; next }
    insec && /^[ \t]*\|/ {
      n = cells($0, c)
      if (n < 4) next
      if (!hdr) { if (tolower(c[2]) == "project") hdr = 1; next }
      if (c[2] ~ /^:?-+:?$/) next
      name = c[2]; path = c[3]; keys = c[4]
      gsub(/`/, "", path); sub(/^\.\//, "", path); sub(/^\/+/, "", path); sub(/\/+$/, "", path)
      gsub(/[` \t]/, "", keys)
      if (name == "" || path == "") next
      print name "\t" path "\t" keys
    }
  ' "$SB_ROOT/CLAUDE.md"
}

# Print the index rows whose name matches, then whose path or folder name matches.
sb_project_rows_by_name() {
  local rows
  rows="$(sb_projects_tsv)"
  [ -n "$rows" ] || return 0
  printf '%s\n' "$rows" | SB_W="$1" awk -F'\t' '
    BEGIN { w = tolower(ENVIRON["SB_W"]); sub(/^\/+/, "", w); sub(/\/+$/, "", w) }
    { row[NR] = $0; nm[NR] = tolower($1); p[NR] = tolower($2); b[NR] = p[NR]; sub(/^.*\//, "", b[NR]) }
    END {
      for (i = 1; i <= NR; i++) if (nm[i] == w) { print row[i]; hit = 1 }
      if (hit) exit
      for (i = 1; i <= NR; i++) if (p[i] == w) { print row[i]; hit = 1 }
      if (hit) exit
      for (i = 1; i <= NR; i++) if (b[i] == w) print row[i]
    }'
}

# Print the index rows that list a ticket key; a full ticket id gives its prefix.
sb_project_rows_by_key() {
  local rows
  rows="$(sb_projects_tsv)"
  [ -n "$rows" ] || return 0
  printf '%s\n' "$rows" | SB_W="$1" awk -F'\t' '
    BEGIN { w = toupper(ENVIRON["SB_W"]); if (w ~ /-[0-9]+$/) sub(/-[0-9]+$/, "", w) }
    w != "" {
      n = split(toupper($3), k, ",")
      for (i = 1; i <= n; i++) if (k[i] == w) { print; break }
    }'
}

# Print the index rows that own a working directory: a project folder, or a repo named in a profile.
sb_project_rows_by_cwd() {
  local dir="$1" phys rows name path keys rel table="" r
  local rpath state rphys row best="" bestlen=0 nl=$'\n' tab=$'\t'
  phys="$(cd "$dir" 2>/dev/null && pwd -P)" || return 0
  rows="$(sb_projects_tsv)"
  [ -n "$rows" ] || return 0
  case "$phys/" in
    "$SB_ROOT"/*)
      rel="${phys#"$SB_ROOT"}"
      rel="${rel#/}"
      printf '%s\n' "$rows" | SB_REL="$rel" awk -F'\t' '
        BEGIN { rel = ENVIRON["SB_REL"] "/"; best = 0 }
        { p = $2 "/"; if (substr(rel, 1, length(p)) == p && length(p) > best) { best = length(p); row = $0 } }
        END { if (best) print row }'
      return 0
      ;;
  esac
  # A recorded repository folder that holds the directory decides; the deepest one wins.
  # The same pass keeps every repo name with its project, for the match by folder name below.
  while IFS=$'\t' read -r name path keys; do
    [ -n "$name" ] || continue
    row="$name$tab$path$tab$keys"
    while IFS=$'\t' read -r r rpath state; do
      [ -n "$r" ] || continue
      table="$table${r// /_}$tab$row$nl"
      [ "$state" = "ok" ] || continue
      rphys="$(cd -P "$rpath" 2>/dev/null && pwd -P)" || continue
      case "$phys/" in
        "$rphys"/*)
          if [ "${#rphys}" -gt "$bestlen" ]; then
            bestlen="${#rphys}"
            best="$row"
          elif [ "${#rphys}" -eq "$bestlen" ]; then
            case "$nl$best$nl" in *"$nl$row$nl"*) ;; *) best="$best$nl$row" ;; esac
          fi
          ;;
      esac
    done <<EOF2
$(sb_repo_rows_at "$path")
EOF2
  done <<EOF
$rows
EOF
  if [ -n "$best" ]; then
    printf '%s\n' "$best"
    return 0
  fi
  # Else a folder on the way up that carries a repo name from a profile.
  [ -n "$table" ] || return 0
  printf '%s' "$table" | SB_DIR="$phys" awk -F'\t' '
    BEGIN { n = split(ENVIRON["SB_DIR"], part, "/") }
    { repo[NR] = tolower($1); row[NR] = $2 "\t" $3 "\t" $4 }
    END {
      for (i = n; i >= 1; i--) {
        if (part[i] == "") continue
        c = tolower(part[i]); gsub(/ /, "_", c); hit = 0
        for (j = 1; j <= NR; j++) if (repo[j] == c && !(row[j] in seen)) { print row[j]; seen[row[j]] = 1; hit = 1 }
        if (hit) exit
      }
    }'
}

# Resolve a project by name; sets SB_P_NAME, SB_P_PATH, SB_P_KEYS. Returns 1 for none, 4 for several.
sb_project_resolve() {
  local rows count
  sb_need_root
  rows="$(sb_project_rows_by_name "$1")"
  [ -n "$rows" ] || return 1
  count="$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"
  if [ "$count" -gt 1 ]; then
    SB_P_ROWS="$rows"
    return 4
  fi
  IFS=$'\t' read -r SB_P_NAME SB_P_PATH SB_P_KEYS <<EOF
$rows
EOF
  return 0
}

# Print a project's vault-relative path, or return 1.
sb_project_path() {
  sb_project_resolve "$1" || return 1
  printf '%s\n' "$SB_P_PATH"
}

# Print the absolute path of a project's profile, or return 1.
sb_profile() {
  sb_project_resolve "$1" || return 1
  [ -f "$SB_ROOT/$SB_P_PATH/claude/profile.md" ] || return 1
  printf '%s\n' "$SB_ROOT/$SB_P_PATH/claude/profile.md"
}

# Print a profile setting for a project path, or the default.
sb_setting() {
  local v=""
  v="$(sb_fm_get "$SB_ROOT/$1/claude/profile.md" "$2" 2>/dev/null)"
  v="${v#/}"
  v="${v%/}"
  [ -n "$v" ] || v="$3"
  printf '%s\n' "$v"
}

# Return 0 when the project at a vault path uses sprints; only uses_sprints: false turns them off.
sb_uses_sprints() {
  [ "$(sb_setting "$1" uses_sprints true | tr '[:upper:]' '[:lower:]')" != "false" ]
}

# Exit 5 when the current project does not use sprints.
sb_need_sprints() {
  sb_uses_sprints "$SB_P_PATH" || sb_die 5 "$SB_P_NAME does not use sprints (uses_sprints: false in its profile)"
}

# Resolve a project argument or exit 1 or 4; sets the SB_P_ globals and its folders.
sb_need_project() {
  local rc=0
  sb_need_root
  sb_project_resolve "$1" || rc=$?
  case "$rc" in
    0) ;;
    4)
      printf '%s\n' "$SB_P_ROWS"
      sb_die 4 "several projects match: $1"
      ;;
    *) sb_die 1 "no project matches: $1 (list them with: second-brain projects)" ;;
  esac
  SB_P_DIR="$SB_ROOT/$SB_P_PATH"
  SB_P_PROFILE="$SB_P_DIR/claude/profile.md"
  SB_TASKS_ROOT="$(sb_setting "$SB_P_PATH" tasks_root tasks)"
  SB_TOPICS_ROOT="$(sb_setting "$SB_P_PATH" topics_root docs)"
  SB_SPRINTS_ROOT="$(sb_setting "$SB_P_PATH" sprints_root sprints)"
}

# Exit 1 with the adopt hint when the current project has no profile.
sb_need_profile() {
  [ -f "$SB_P_PROFILE" ] || sb_die 1 "no profile at $SB_P_PATH/claude/profile.md (run vault-setup adopt $SB_P_PATH)"
}

# Print name<TAB>path for each repo of a profile file, then for each repo of the subproject notes
# given after it that the profile does not list; the path is "-" when no location is recorded.
# repos_root comes from the profile; a repo_paths entry of a note wins over the profile's.
# A location comes out in the shell's own form; one that is not absolute is left for the caller to drop.
sb_repo_paths() {
  local name path
  [ -f "$1" ] || return 1
  LC_ALL=C awk "$(sb_awk_lib)"'
    function add(k, v,   j) {
      if (v == "") return
      if (k == "repos") {
        if (fileno > 1 && (tolower(v) in listed)) return
        repo[++nr] = v
        listed[tolower(v)] = 1
      }
      else { j = index(v, "="); if (j > 1) other[trim(substr(v, 1, j - 1))] = trim(substr(v, j + 1)) }
    }
    function expand(p,   home) {
      home = ENVIRON["HOME"]
      if (home != "" && p == "~") p = home
      else if (home != "" && substr(p, 1, 2) == "~/") p = home substr(p, 2)
      while (length(p) > 1 && substr(p, length(p)) == "/") p = substr(p, 1, length(p) - 1)
      return p
    }
    { sub(/\r$/, "") }
    # fileno is the place of the file among the arguments, so an empty file still counts.
    FNR == 1 { do fileno++; while (fileno < ARGC && ARGV[fileno] != FILENAME); key = ""; sub(/^\357\273\277/, ""); done = ($0 != "---"); next }
    done { next }
    $0 == "---" { done = 1; next }
    /^[A-Za-z0-9_][A-Za-z0-9_-]*:/ {
      i = index($0, ":"); key = substr($0, 1, i - 1); v = trim(substr($0, i + 1))
      if (key == "repos_root") { if (fileno == 1) root = unq(v) }
      else if (key == "repos" || key == "repo_paths") {
        if (substr(v, 1, 1) == "[") { n = split_inline(v, it); for (k = 1; k <= n; k++) add(key, it[k]) }
        else add(key, unq(v))
      }
      next
    }
    (key == "repos" || key == "repo_paths") && /^[ \t]*-([ \t]|$)/ { v = $0; sub(/^[ \t]*-[ \t]*/, "", v); add(key, unq(v)) }
    END {
      root = expand(root)
      for (r = 1; r <= nr; r++) {
        p = "-"
        if (repo[r] in other) p = expand(other[repo[r]])
        else if (root != "") p = (root == "/" ? "" : root) "/" repo[r]
        print repo[r] "\t" p
      }
    }
  ' "$@" | while IFS=$'\t' read -r name path; do
    printf '%s\t' "$name"
    sb_path_in "$path"
  done
}

# Print the repo rows of a project path, the repos of its subprojects included: name, path, state
# (ok, missing or unknown).
sb_repo_rows_at() {
  local name path f profile="$SB_ROOT/$1/claude/profile.md" subs
  subs=()
  for f in "$SB_ROOT/$1/claude/subprojects"/*.md; do
    [ -f "$f" ] && subs[${#subs[@]}]="$f"
  done
  sb_repo_paths "$profile" ${subs[@]+"${subs[@]}"} 2>/dev/null | while IFS=$'\t' read -r name path; do
    [ -n "$name" ] || continue
    case "$path" in /*) ;; *) path="-" ;; esac
    if [ "$path" = "-" ]; then
      printf '%s\t-\tunknown\n' "$name"
    elif [ -d "$path" ]; then
      printf '%s\t%s\tok\n' "$name" "$path"
    else
      printf '%s\t%s\tmissing\n' "$name" "$path"
    fi
  done
}

# Print the repo rows of a project by name: name, path, state. Returns 1 with no project or profile.
sb_repo_rows() {
  sb_project_resolve "$1" || return 1
  [ -f "$SB_ROOT/$SB_P_PATH/claude/profile.md" ] || return 1
  sb_repo_rows_at "$SB_P_PATH"
}

# Print where a project's repositories are stored, or the path of one of them.
cmd_repo() {
  local project="${1:-}" name="${2:-}" rows row rname path state
  if [ -z "$project" ] || [ $# -gt 2 ]; then sb_die 5 "usage: second-brain repo <project> [name]"; fi
  sb_need_project "$project"
  sb_need_profile
  rows="$(sb_repo_rows_at "$SB_P_PATH")"
  if [ -z "$name" ]; then
    while IFS=$'\t' read -r rname path state; do
      [ -n "$rname" ] || continue
      [ "$path" = "-" ] || path="$(sb_path_out "$path")"
      printf '%s\t%s\t%s\n' "$rname" "$path" "$state"
    done <<EOF
$rows
EOF
    return 0
  fi
  row="$(printf '%s\n' "$rows" | SB_W="$name" awk -F'\t' '
    BEGIN { w = ENVIRON["SB_W"] }
    $1 == w { exact = $0 }
    tolower($1) == tolower(w) && loose == "" { loose = $0 }
    END { print (exact != "" ? exact : loose) }')"
  [ -n "$row" ] || sb_die 1 "$name is not in repos of $SB_P_NAME ($SB_P_PATH/claude/profile.md)"
  IFS=$'\t' read -r rname path state <<EOF
$row
EOF
  case "$state" in
    ok) sb_path_out "$path" ;;
    missing) sb_die 1 "the folder of $rname is missing: $(sb_path_out "$path")" ;;
    *) sb_die 1 "no location is recorded for $rname: set repos_root or repo_paths in $SB_P_PATH/claude/profile.md" ;;
  esac
}

# Read index rows on stdin; print them with "-" in an empty keys cell.
sb_rows_out() {
  awk -F'\t' '$1 != "" { print $1 "\t" $2 "\t" ($3 == "" ? "-" : $3) }'
}

# Print the index rows as TSV.
cmd_projects() {
  sb_need_root
  [ -f "$SB_ROOT/CLAUDE.md" ] || sb_die 1 "no index at CLAUDE.md in the vault (run vault-setup init)"
  sb_projects_tsv | sb_rows_out
}

# Resolve one project by name, ticket key or working directory.
cmd_project() {
  local name="" key="" cwd="" given=0 rows="" count
  while [ $# -gt 0 ]; do
    case "$1" in
      --name | --key | --cwd)
        [ $# -ge 2 ] || sb_die 5 "$1 needs a value"
        case "$1" in
          --name) name="$2" ;;
          --key) key="$2" ;;
          --cwd) cwd="$(sb_path_in "$2")" ;;
        esac
        given=1
        shift 2
        ;;
      *) sb_die 5 "usage: second-brain project --name N | --key K | --cwd DIR" ;;
    esac
  done
  sb_need_root
  [ "$given" -eq 1 ] || cwd="$PWD"
  [ -z "$name" ] || rows="$(sb_project_rows_by_name "$name")"
  if [ -z "$rows" ] && [ -n "$key" ]; then rows="$(sb_project_rows_by_key "$key")"; fi
  if [ -z "$rows" ] && [ -n "$cwd" ]; then rows="$(sb_project_rows_by_cwd "$cwd")"; fi
  [ -n "$rows" ] || sb_die 1 "no project matches (list them with: second-brain projects)"
  count="$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"
  printf '%s\n' "$rows" | sb_rows_out
  [ "$count" -eq 1 ] || sb_die 4 "several projects match; name one with --name"
}

# Print the profile's frontmatter keys, or one of its level-2 sections.
cmd_profile() {
  local project="${1:-}" what=""
  [ $# -gt 0 ] && shift
  what="$*"
  if [ -z "$project" ] || [ -z "$what" ]; then
    sb_die 5 "usage: second-brain profile <project> --keys | <section>"
  fi
  sb_need_project "$project"
  sb_need_profile
  if [ "$what" = "--keys" ]; then
    sb_fm_keys "$SB_P_PROFILE" | sed 's/^\([^:]*\):$/\1: -/'
    return 0
  fi
  sb_section "$SB_P_PROFILE" "$what" || sb_die 1 "no section \"## $what\" in $SB_P_PATH/claude/profile.md"
}

# Print the context block: vault, project, project path and sprint.
cmd_context() {
  local cwd="$PWD" project="none" ppath="none" sprint="none" sub="" rows count
  while [ $# -gt 0 ]; do
    if [ "$1" = "--cwd" ] && [ $# -ge 2 ]; then
      cwd="$(sb_path_in "$2")"
      shift
    fi
    shift
  done
  SB_ROOT="$(sb_root 2>/dev/null)" || SB_ROOT=""
  printf 'vault: '
  if [ -n "$SB_ROOT" ]; then sb_path_out "$SB_ROOT"; else printf 'none\n'; fi
  if [ -n "$SB_ROOT" ]; then
    rows="$(sb_project_rows_by_cwd "$cwd" 2>/dev/null)"
    count="$(printf '%s' "$rows" | grep -c . || true)"
    if [ "$count" = "1" ]; then
      IFS=$'\t' read -r SB_P_NAME SB_P_PATH SB_P_KEYS <<EOF
$rows
EOF
      project="$SB_P_NAME"
      ppath="$SB_P_PATH"
      # A subproject line only when exactly one subproject's repository holds the directory.
      sub="$(sb_sub_by_cwd "$SB_P_PATH" "$cwd" 2>/dev/null)"
      case "$sub" in *$'\n'*) sub="" ;; esac
      if sb_uses_sprints "$SB_P_PATH"; then
        sprint="$(sb_sprint_current_id "$SB_P_PATH" 2>/dev/null)"
        [ -n "$sprint" ] || sprint="none"
      else
        sprint="off"
      fi
    fi
  fi
  printf 'project: %s\nproject_path: %s\n' "$project" "$ppath"
  [ -z "$sub" ] || printf 'subproject: %s\n' "$sub"
  printf 'sprint: %s\n' "$sprint"
  return 0
}
