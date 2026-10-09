#!/usr/bin/env bash
# scaffold.sh - create the vault files and a project tree from the templates; never overwrite.

# Fill a template into a file under SB_SCAF_ROOT unless it exists; print the path when created.
# A file that is already there is left alone and named on stderr as "exists: <path>".
sb_scaffold_file() {
  local tmpl="$1" dest="$2" rc=0
  shift 2
  sb_fill "$tmpl" "$SB_SCAF_ROOT/$dest" "$@" || rc=$?
  case "$rc" in
    0) printf '%s\n' "$dest" ;;
    6) printf 'exists: %s\n' "$dest" >&2 ;;
    *) sb_die 1 "cannot write $dest" ;;
  esac
}

# Print a root flag's value cleaned up, or exit 5; "." is allowed only where the second argument says so.
sb_scaffold_root() {
  local flag="$1" dot="$2" r="$3" nl=$'\n'
  [ "$r" != "./" ] || r="."
  if [ "$r" = "." ]; then
    [ "$dot" = "dot" ] || sb_die 5 "$flag takes a folder inside the project, not the project folder itself"
    printf '.\n'
    return 0
  fi
  r="${r#./}"
  r="${r#/}"
  r="${r%/}"
  [ -n "$r" ] || sb_die 5 "$flag takes a folder path inside the project"
  case "$r" in
    *'|'* | *'['* | *']'* | *'"'* | *'#'* | *'^'* | *'\'* | *"$nl"*)
      sb_die 5 "$flag cannot hold any of: | [ ] \" # ^, the backslash or a line break"
      ;;
  esac
  case "/$r/" in
    */../* | */./* | */.*) sb_die 5 "$flag takes a folder path inside the project, with no dot folders: $r" ;;
  esac
  printf '%s\n' "$r"
}

# Print one map line for the project README: a link to a hub, shown by the alias the hub has.
sb_scaffold_hub_line() {
  local path="$1" name="$2" root="$3" title="$4" text="$5" alias
  alias="$(sb_fm_list "$SB_ROOT/$path/$root/README.md" aliases 2>/dev/null | head -1)"
  [ -n "$alias" ] || alias="$name $title"
  printf -- '- [[%s/%s/README|%s]] - %s\n' "$path" "$root" "$alias" "$text"
}

# Create the index, the conventions note and the vault Claude hub.
sb_scaffold_vault() {
  local dir="${1:-}"
  [ $# -le 1 ] || sb_die 5 "usage: second-brain scaffold vault [DIR]"
  if [ -n "$dir" ]; then
    [ -d "$dir/.obsidian" ] || sb_die 2 "not a vault, it has no .obsidian folder: $dir (open it in Obsidian once)"
    SB_SCAF_ROOT="$(cd -P "$dir" && pwd -P)" || sb_die 2 "cannot open $dir"
  else
    sb_need_root
    SB_SCAF_ROOT="$SB_ROOT"
  fi
  sb_scaffold_file vault-index.md.tmpl CLAUDE.md
  sb_scaffold_file obsidian-conventions.md.tmpl obsidian-conventions.md
  sb_scaffold_file vault-claude-hub.md.tmpl claude/README.md
  return 0
}

# Add one project row to the index table, creating the table when it is missing.
sb_index_add_row() {
  local file="$1" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/sb-index.XXXXXX")" || return 1
  LC_ALL=C SB_NAME="$2" SB_PATH="$3" SB_KEYS="$4" SB_USE="$5" awk '
    function esc(s,   i, c, out) {
      out = ""
      for (i = 1; i <= length(s); i++) { c = substr(s, i, 1); out = out (c == "|" ? "\\|" : c) }
      return out
    }
    function bare(i,   l) { l = raw[i]; sub(/\r$/, "", l); return l }
    BEGIN {
      row = "| " ENVIRON["SB_NAME"] " | " ENVIRON["SB_PATH"] " | " ENVIRON["SB_KEYS"] " | " esc(ENVIRON["SB_USE"]) " |"
      head = "| Project | Path | Keys | Use when |"; rule = "|---|---|---|---|"
    }
    { raw[NR] = $0 }
    END {
      n = NR; eol = (n > 0 && raw[1] ~ /\r$/) ? "\r" : ""
      sec = 0; hdr = 0; last = 0; insec = 0; closed = 0
      for (i = 1; i <= n; i++) {
        l = bare(i)
        if (l ~ /^#[#]? /) {
          insec = 0
          if (!sec && tolower(l) ~ /^##[ \t]+projects[ \t]*$/) { sec = i; insec = 1 }
          continue
        }
        if (!insec || closed) continue
        if (l ~ /^[ \t]*\|/) {
          if (!hdr && tolower(l) ~ /^[ \t]*\|[ \t]*project[ \t]*\|/) hdr = i
          if (hdr) last = i
        } else if (hdr) closed = 1
      }
      if (last) {
        for (i = 1; i <= last; i++) print raw[i]
        print row eol
        for (i = last + 1; i <= n; i++) print raw[i]
      } else if (sec) {
        for (i = 1; i <= sec; i++) print raw[i]
        print eol; print head eol; print rule eol; print row eol
        if (sec < n && bare(sec + 1) !~ /^[ \t]*$/) print eol
        for (i = sec + 1; i <= n; i++) print raw[i]
      } else {
        for (i = 1; i <= n; i++) print raw[i]
        if (n > 0 && bare(n) !~ /^[ \t]*$/) print eol
        print "## Projects" eol; print eol; print head eol; print rule eol; print row eol
      }
    }
  ' "$file" >"$tmp" || { rm -f "$tmp"; return 1; }
  cat "$tmp" >"$file"
  rm -f "$tmp"
  return 0
}

# Create a project tree on the standard layout and list it in the index.
sb_scaffold_project() {
  local name="" path="" keys="" use="" rows hit troot topics sroot depth cur intro k keylist
  local f_tasks="" f_topics="" f_sprints="" profile had_profile=0 line_tasks line_topics="" line_sprints q hit2
  local nl=$'\n' cr=$'\r' tab=$'\t'
  local usage="usage: second-brain scaffold project <name> --path P [--keys K1,K2] [--use-when TEXT] [--tasks-root R] [--topics-root R] [--sprints-root R]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --path | --keys | --use-when | --tasks-root | --topics-root | --sprints-root)
        [ $# -ge 2 ] || sb_die 5 "$1 needs a value"
        case "$1" in
          --path) path="$2" ;;
          --keys) keys="$2" ;;
          --use-when) use="$2" ;;
          --tasks-root) f_tasks="$(sb_scaffold_root "$1" nodot "$2")" || exit 5 ;;
          --topics-root) f_topics="$(sb_scaffold_root "$1" dot "$2")" || exit 5 ;;
          --sprints-root) f_sprints="$(sb_scaffold_root "$1" nodot "$2")" || exit 5 ;;
        esac
        shift 2
        ;;
      -*) sb_die 5 "$usage" ;;
      *)
        [ -z "$name" ] || sb_die 5 "$usage"
        name="$1"
        shift
        ;;
    esac
  done
  if [ -z "$name" ] || [ -z "$path" ]; then sb_die 5 "$usage"; fi
  case "$name$path$use" in
    *"$nl"* | *"$cr"* | *"$tab"*) sb_die 5 "the name, the path and the use-when text are one line each" ;;
  esac
  case "$name$path" in
    *'|'* | *'['* | *']'* | *'"'* | *'#'* | *'^'* | *'\'*)
      sb_die 5 "the name and the path cannot hold any of: | [ ] \" # ^ and the backslash"
      ;;
  esac
  path="${path#./}"
  path="${path#/}"
  path="${path%/}"
  case "/$path/" in
    // | */../* | */./* | */.*) sb_die 5 "--path is a folder path inside the vault, with no dot folders: $path" ;;
  esac
  keylist=""
  for k in $(printf '%s' "$keys" | tr ',\t' '  '); do
    case "$k" in *[!A-Za-z0-9_-]*) sb_die 5 "not a ticket key prefix: $k" ;; esac
    keylist="${keylist:+$keylist, }$k"
  done
  keys="$keylist"
  sb_need_root
  SB_SCAF_ROOT="$SB_ROOT"
  [ -f "$SB_ROOT/CLAUDE.md" ] || sb_die 2 "no index at CLAUDE.md in the vault (run: second-brain scaffold vault)"
  rows="$(sb_projects_tsv)"
  hit="$(printf '%s\n' "$rows" | SB_N="$name" SB_P="$path" awk -F'\t' '
    BEGIN { n = tolower(ENVIRON["SB_N"]); p = ENVIRON["SB_P"] }
    $1 == "" { next }
    tolower($1) == n && $2 == p { print "same"; exit }
    tolower($1) == n { print "the name " $1 " is already in the index at " $2; exit }
    $2 == p { print "the path " $2 " is already in the index as " $1; exit }')"
  case "$hit" in
    '' | same) ;;
    *) sb_die 6 "$hit" ;;
  esac
  hit2="$(printf '%s\n' "$rows" | SB_N="$name" SB_K="$keys" awk -F'\t' '
    BEGIN { n = tolower(ENVIRON["SB_N"]); nk = split(toupper(ENVIRON["SB_K"]), want, /, */) }
    $1 == "" || tolower($1) == n { next }
    {
      m = split(toupper($3), have, ",")
      for (i = 1; i <= nk; i++) for (j = 1; j <= m; j++) if (want[i] != "" && want[i] == have[j]) {
        print "the key " want[i] " already belongs to the project " $1
        exit
      }
    }')"
  [ -z "$hit2" ] || sb_die 6 "$hit2"
  [ -n "$use" ] || use="Anything about $name."
  # The roots: an existing profile decides; a new one takes the flags, then the defaults.
  profile="$SB_ROOT/$path/claude/profile.md"
  if [ -f "$profile" ]; then
    had_profile=1
    [ -z "$f_tasks$f_topics$f_sprints" ] || sb_note "the profile exists: its roots are used and the root flags are ignored"
    troot="$(sb_setting "$path" tasks_root tasks)"
    topics="$(sb_setting "$path" topics_root docs)"
    sroot="$(sb_setting "$path" sprints_root sprints)"
  else
    troot="${f_tasks:-tasks}"
    topics="${f_topics:-docs}"
    sroot="${f_sprints:-sprints}"
    if [ "$troot" = "$sroot" ] || [ "$troot" = "$topics" ] || [ "$topics" = "$sroot" ]; then
      sb_die 5 "the tasks, topics and sprints roots are three different folders"
    fi
    case "$sroot/" in "$troot"/*) sb_die 5 "the sprints root cannot sit inside the tasks root" ;; esac
    case "$topics/" in "$troot"/*) sb_die 5 "the topics root cannot sit inside the tasks root" ;; esac
  fi
  line_tasks="$(sb_scaffold_hub_line "$path" "$name" "$troot" "Tasks Hub" "one folder per task, and the task board")"
  [ "$topics" = "." ] || line_topics="$(sb_scaffold_hub_line "$path" "$name" "$topics" "Docs Hub" "the topics: one folder per subject")"
  line_sprints="$(sb_scaffold_hub_line "$path" "$name" "$sroot" "Sprints Hub" "one note per sprint")"
  sb_scaffold_file project-readme.md.tmpl "$path/README.md" "PROJECT=$name" "PROJECT_PATH=$path" \
    "TASKS_HUB_LINE=$line_tasks" "TOPICS_HUB_LINE=$line_topics" "SPRINTS_HUB_LINE=$line_sprints"
  sb_scaffold_file project-claude-hub.md.tmpl "$path/claude/README.md" "PROJECT=$name" "PROJECT_PATH=$path"
  sb_scaffold_file profile.md.tmpl "$path/claude/profile.md" "PROJECT=$name" "PROJECT_PATH=$path" "TICKET_KEYS=$keys" \
    "TASKS_ROOT=$troot" "TOPICS_ROOT=$topics" "SPRINTS_ROOT=$sroot"
  if [ "$had_profile" -eq 0 ]; then
    # Quote a root that needs it; "." is always quoted.
    for k in tasks_root topics_root sprints_root; do
      case "$k" in
        tasks_root) q="$troot" ;;
        topics_root) q="$topics" ;;
        *) q="$sroot" ;;
      esac
      if [ "$q" = "." ]; then
        sb_fm_set_raw "$profile" "$k" '"."'
      elif [ "$(sb_yaml_quote "$q")" != "$q" ]; then
        sb_fm_set_raw "$profile" "$k" "$(sb_yaml_quote "$q")"
      fi
    done
  fi
  intro="One folder per task: \`$troot/<TICKET-ID>/README.md\`, with its queries, notebooks and logs beside it.
A task is never filed under the topic it is about; it carries topic tags instead.

## Board

The live board over every task README. Its other views are \`Current sprint\`, \`By topic\`,
\`Needs a status\` and \`All\`. Nothing is added to it by hand.

![[$path/$troot/tasks.base#Active]]"
  sb_scaffold_file hub.md.tmpl "$path/$troot/README.md" "PROJECT=$name" "PROJECT_PATH=$path" \
    "HUB_NAME=$troot" "HUB_TITLE=Tasks Hub" "HUB_INTRO=$intro"
  depth="$(printf '%s\n' "$path/$troot" | awk -F/ '{ print NF + 1 }')"
  cur="$(sb_sprint_current_id "$path")"
  sb_scaffold_file tasks.base.tmpl "$path/$troot/tasks.base" "TASKS_PATH=$path/$troot" "TASK_DEPTH=$depth" "SPRINT_ID=${cur:-none}"
  if [ "$topics" != "." ]; then
    intro="The topics root. Each folder under \`$topics/\` is a topic, and its tag is the folder path below
\`$topics/\`, lowercased. Give each topic folder a \`README.md\` hub that links up to this note.

## Topics"
    sb_scaffold_file hub.md.tmpl "$path/$topics/README.md" "PROJECT=$name" "PROJECT_PATH=$path" \
      "HUB_NAME=$topics" "HUB_TITLE=Docs Hub" "HUB_INTRO=$intro"
  fi
  intro="One note per sprint, named by its end date: \`$sroot/<YYYY-MM-DD>.md\`. Opening a sprint adds
its link below, newest first.

## Sprints"
  sb_scaffold_file hub.md.tmpl "$path/$sroot/README.md" "PROJECT=$name" "PROJECT_PATH=$path" \
    "HUB_NAME=$sroot" "HUB_TITLE=Sprints Hub" "HUB_INTRO=$intro"
  if [ "$hit" != "same" ]; then
    sb_index_add_row "$SB_ROOT/CLAUDE.md" "$name" "$path" "$keys" "$use" || sb_die 1 "cannot edit CLAUDE.md"
    sb_note "index row added for $name"
  fi
  return 0
}

# Dispatch the scaffold subcommands.
cmd_scaffold() {
  local sub="${1:-}"
  [ $# -gt 0 ] && shift
  case "$sub" in
    vault) sb_scaffold_vault "$@" ;;
    project) sb_scaffold_project "$@" ;;
    *) sb_die 5 "usage: second-brain scaffold vault [DIR] | scaffold project <name> --path P [--keys K1,K2] ..." ;;
  esac
}
