#!/usr/bin/env bash
# validation.sh - each repo's validation.md: where it lives, its sections, and the run of its checks.

# Print the validation_home that holds: the first file given that sets one decides, in any letter
# case, and a value that is not vault or repo means vault. Files that are not there are skipped.
# Usage: sb_val_home <file>...
sb_val_home() {
  local f v
  for f in "$@"; do
    [ -n "$f" ] && [ -f "$f" ] || continue
    v="$(sb_fm_get "$f" validation_home 2>/dev/null)"
    [ -n "$v" ] || continue
    sb_lc "$v"
    case "$SB_LC" in
      repo) printf 'repo\n' ;;
      *) printf 'vault\n' ;;
    esac
    return 0
  done
  printf 'vault\n'
}

# Print the row of one repo of the current project, matched exact first, then without letter case:
# name, path, state, as sb_repo_rows_at prints it. Returns 1 when it is not a repo of the project.
sb_val_repo_row() {
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
sb_val_need_folder() {
  case "$3" in
    ok) ;;
    missing) sb_die 1 "the folder of $1 is missing: $(sb_path_out "$2")" ;;
    *) sb_die 1 "no location is recorded for $1: set repos_root or repo_paths in $SB_P_PATH/claude/profile.md" ;;
  esac
}

# Read TSV rows on stdin; print them as a JSON array of objects, one key per column, in order.
# Usage: sb_val_json_rows <key>...
sb_val_json_rows() {
  LC_ALL=C SB_KEYS="$*" awk -F'\t' "$(sb_awk_lib)"'
    BEGIN { nk = split(ENVIRON["SB_KEYS"], k, " "); printf "[" }
    $0 == "" { next }
    {
      printf "%s\n  {", (rows++ ? "," : "")
      for (i = 1; i <= nk; i++) printf "%s%s: %s", (i > 1 ? ", " : ""), jstr(k[i]), jstr($i)
      printf "}"
    }
    END { print (rows ? "\n]" : "]") }'
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
  local only="${1:-}" name path rstate home file show phome
  phome="$(sb_val_home "$SB_P_PROFILE")"
  while IFS=$'\t' read -r name path rstate; do
    [ -n "$name" ] || continue
    [ -z "$only" ] || [ "$name" = "$only" ] || continue
    home="$phome"
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
# A retired placeholder, one an earlier version of the template held, counts too: the list in
# BEGIN is its one home.
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
      ph["<The steps that use the change as a user does, and what to look for.>"] = 1
      ph["<Each command that must pass, such as the tests, linter and build, and what it proves.>"] = 1
      ph["<One line per step that uses the change as a user does: its tool, then what to look for.>"] = 1
      ph["<Each line ends with when it runs: when: each task, when: each build, or when: release for one run only before a release or on the owner'"'"'s ask.>"] = 1
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

# Read a repo's section of a validation.md on stdin; print the bullets that the level takes under
# "### Checks", or under the headings a second argument names, such as "checks|check as a user
# would". One TSV row each: "run<TAB><command><TAB><globs>", the globs of its "paths:" joined by
# commas, or "skip<TAB><text><TAB><why>". Level 1 takes "each story", 2 "each merge" too, 3
# "release" too. A bullet with an unknown "when:" counts as "each merge", with a row
# "warn<TAB><text><TAB><value>" whatever the level. One with an old name, "each task" or "each
# build", reads as "each story" or "each merge", with a row "old<TAB><name><TAB>each-task" or
# "...<TAB>each-build" whatever the level: a check's name is its command, and a user step's, or a
# check's with none, its text before its keys. Prints "none" when the section has none of the
# headings.
# Usage: sb_val_checks <level> [<heading>|<heading>...]
sb_val_checks() {
  LC_ALL=C SB_LEVEL="$1" SB_HEADS="${2:-checks}" awk "$(sb_awk_lib)"'
    # Set CODE1 to the first code span of s and HASCODE to 1 when it has one, and SPAN[k] to the
    # text of its k-th span. Return s with span k replaced by the mark SO k SC, which unspan() reads
    # back. A run of backticks with no closing run of the same length is text.
    function spans(s,   out, i, k, after, rest, m, p, content, n) {
      out = ""; HASCODE = 0; CODE1 = ""; n = 0
      while ((i = index(s, "`")) > 0) {
        out = out substr(s, 1, i - 1); s = substr(s, i)
        match(s, /^`+/); k = RLENGTH; after = substr(s, k + 1)
        p = 0; m = 0; rest = after
        while (match(rest, /`+/)) {
          if (RLENGTH == k) { p = m + RSTART; break }
          m += RSTART + RLENGTH - 1; rest = substr(rest, RSTART + RLENGTH)
        }
        if (!p) { out = out substr(s, 1, k); s = after; continue }
        content = substr(after, 1, p - 1)
        if (content ~ /^ / && content ~ / $/ && content !~ /^ +$/) content = substr(content, 2, length(content) - 2)
        if (!HASCODE) { HASCODE = 1; CODE1 = content }
        SPAN[++n] = content
        out = out SO n SC; s = substr(after, p + k)
      }
      return out s
    }
    # s with the mark of each code span replaced by its text, or by a blank when blank is 1.
    function unspan(s, blank,   out, i, j) {
      out = ""
      while ((i = index(s, SO)) > 0) {
        j = index(substr(s, i + 1), SC)
        out = out substr(s, 1, i - 1) (blank ? " " : SPAN[substr(s, i + 1, j - 1) + 0])
        s = substr(s, i + j + 1)
      }
      return out s
    }
    # The position in l, a bullet in lower case, of the last key k that starts a word, or 0.
    function keyat(l, k,   i, pos, last) {
      pos = 0; last = 0
      while ((i = index(substr(l, pos + 1), k)) > 0) {
        pos += i
        if (pos == 1 || substr(l, pos - 1, 1) !~ /[a-z0-9_]/) last = pos
      }
      return last
    }
    # The text after the key at pos, n bytes long, in s: up to the other key at stop when it comes
    # after it, else to the end.
    function valat(s, pos, n, stop) {
      return (stop > pos ? substr(s, pos + n, stop - pos - n) : substr(s, pos + n))
    }
    function flush(   t, plain, l, wp, pp, raw, v, lvl, name, g, item, n, i, globs) {
      if (!have) return
      have = 0
      t = trim(txt); gsub(/\t/, " ", t)
      plain = spans(t)
      l = tolower(plain)
      wp = keyat(l, "when:"); pp = keyat(l, "paths:")
      lvl = 2
      if (wp) {
        raw = trim(unspan(valat(plain, wp, 5, pp), 1))
        v = tolower(raw); gsub(/-/, " ", v); sub(/\.$/, "", v); gsub(/[ \t]+/, " ", v); v = trim(v)
        if (v == "each story" || v == "each task") lvl = 1
        else if (v == "each merge" || v == "each build") lvl = 2
        else if (v == "release") lvl = 3
        else print "warn\t" t "\t" raw
        if (v == "each task" || v == "each build") {
          name = CODE1
          if (step || !HASCODE || trim(CODE1) == "") {
            name = trim(unspan(substr(plain, 1, (pp && pp < wp ? pp : wp) - 1), 0)); sub(/[ \t]*-$/, "", name)
          }
          name = trim(name)
          print "old\t" (name != "" ? name : t) "\t" (v == "each task" ? "each-task" : "each-build")
        }
      }
      if (lvl > LEVEL) return
      if (!HASCODE || trim(CODE1) == "") { print "skip\t" t "\tno command"; return }
      globs = ""
      if (pp) {
        g = trim(unspan(valat(plain, pp, 6, wp), 0)); sub(/[ \t]+-$/, "", g); sub(/\.$/, "", g)
        if (g == "-") g = ""
        n = split(g, item, ",")
        for (i = 1; i <= n; i++) if ((g = trim(item[i])) != "") globs = globs (globs == "" ? "" : ",") g
      }
      print "run\t" CODE1 "\t" globs
    }
    BEGIN {
      LEVEL = ENVIRON["SB_LEVEL"] + 0
      n = split(tolower(ENVIRON["SB_HEADS"]), hs, "|")
      for (i = 1; i <= n; i++) want[hs[i]] = 1
      SO = sprintf("%c", 1); SC = sprintf("%c", 2)
    }
    { sub(/\r$/, "") }
    /^[ \t]*(```|~~~)/ { flush(); fence = !fence; next }
    fence { next }
    /^#+([ \t]|$)/ {
      flush()
      match($0, /^#+/)
      if (RLENGTH <= 3) {
        h = $0; sub(/^#+[ \t]*/, "", h); sub(/[ \t#]+$/, "", h)
        inchk = (tolower(h) in want); if (inchk) seen = 1
        step = (tolower(h) == "check as a user would")
      }
      next
    }
    !inchk { next }
    /^[ \t]*$/ { flush(); next }
    /^ ?[-*+][ \t]/ { flush(); have = 1; nested = 0; txt = $0; sub(/^ ?[-*+][ \t]+/, "", txt); next }
    /^[ \t]+([-*+]|[0-9]+[.)])[ \t]/ { if (have) nested = 1; next }
    /^[ \t]/ { if (have && !nested) txt = txt " " trim($0); next }
    { flush() }
    END { flush(); if (!seen) print "none" }'
}

# Return 0 while the process group a command leads, or the command alone, is still running.
sb_val_alive() { kill -0 -- "-$1" 2>/dev/null || kill -0 "$1" 2>/dev/null; }

# Send a signal to the process group a command leads, or to the command alone when it leads none.
# On Windows a group reaches only the shell's own processes, so taskkill stops the Windows process
# tree under the command first, such as a node.exe that npm.cmd started.
sb_val_kill() {
  if sb_is_windows && [ -r "/proc/$1/winpid" ]; then
    taskkill //T //F //PID "$(cat "/proc/$1/winpid" 2>/dev/null)" >/dev/null 2>&1 || true
  fi
  kill -"$2" -- "-$1" 2>/dev/null || kill -"$2" "$1" 2>/dev/null
}

# Stop what a command that has exited left running in its process group: TERM, then KILL after 5
# seconds. Only the group is signalled: the command's own process id may be reused by now.
sb_val_reap() {
  local n=0
  kill -0 -- "-$1" 2>/dev/null || return 0
  kill -TERM -- "-$1" 2>/dev/null
  while [ "$n" -lt 5 ] && kill -0 -- "-$1" 2>/dev/null; do
    sleep 1
    n=$((n + 1))
  done
  kill -KILL -- "-$1" 2>/dev/null
  return 0
}

# Run one command through bash from a folder, stdin from /dev/null, its output and errors in a log;
# stop it, and what it started, after a number of seconds. What it leaves running when it exits is
# stopped too, so the next command runs alone. Usage: sb_val_exec <dir> <command> <seconds> <log>.
# Sets SB_VAL_RC (124 when it timed out), SB_VAL_SECS and SB_VAL_TIMED (1 or 0).
sb_val_exec() {
  local dir="$1" cmd="$2" limit="$3" log="$4" flag="$4.timeout" pid wpid start rc=0
  rm -f "$flag"
  start=$SECONDS
  # Job control gives the command a process group of its own, so a timeout stops all of it.
  set -m
  (cd "$dir" || exit 126; exec "${BASH:-bash}" -c "$cmd") </dev/null >"$log" 2>&1 &
  pid=$!
  set +m
  SB_VAL_PID="$pid"
  trap 'sb_val_kill "$SB_VAL_PID" KILL; rm -f "$flag" "${SB_VAL_ROWS:-}"; exit 130' INT TERM HUP
  (
    n=0
    while [ "$n" -lt "$limit" ]; do
      sleep 1
      sb_val_alive "$pid" || exit 0
      n=$((n + 1))
    done
    : >"$flag"
    sb_val_kill "$pid" TERM
    n=0
    while [ "$n" -lt 5 ]; do
      sleep 1
      sb_val_alive "$pid" || exit 0
      n=$((n + 1))
    done
    sb_val_kill "$pid" KILL
  ) </dev/null >/dev/null 2>&1 &
  wpid=$!
  wait "$pid" 2>/dev/null || rc=$?
  kill "$wpid" 2>/dev/null
  wait "$wpid" 2>/dev/null
  SB_VAL_SECS=$((SECONDS - start))
  sb_val_reap "$pid"
  trap - INT TERM HUP
  SB_VAL_TIMED=0
  if [ -f "$flag" ]; then
    SB_VAL_TIMED=1
    rc=124
    rm -f "$flag"
  fi
  SB_VAL_RC="$rc"
}

# Print the lines that show why a command failed: the first 10 lines of its log that hold "fail" or
# "error" in any letter case, else its last 10 lines, blank ones left out, each cut at 200 bytes.
sb_val_lines() {
  LC_ALL=C awk '
    { sub(/\r$/, ""); l = $0; if (length(l) > 200) l = substr(l, 1, 200) }
    l ~ /^[ \t]*$/ { next }
    { if (tolower(l) ~ /fail|error/ && n < 10) hit[++n] = l; last[++k % 10] = l }
    END {
      if (n) { for (i = 1; i <= n; i++) print hit[i]; exit }
      for (i = (k > 10 ? k - 9 : 1); i <= k; i++) print last[i % 10]
    }' "$1"
}

# Return 0 when the diff from a commit to the files in a folder touches a path that one of the
# globs matches, as git matches a ":(glob)" pathspec: a file moved counts at both its paths, and a
# new file git does not ignore counts too. Return 0 when git cannot tell, so that an error never
# drops a check. Usage: sb_val_touched <dir> <commit> <glob>[,<glob>...]
sb_val_touched() {
  local g globs=() specs=()
  IFS=',' read -r -a globs <<<"$3"
  for g in "${globs[@]}"; do specs+=(":(glob)$g"); done
  [ "${#specs[@]}" -gt 0 ] || return 0
  git -C "$1" diff --quiet --no-ext-diff --no-renames "$2" -- "${specs[@]}" >/dev/null 2>&1 || return 0
  [ -n "$(git -C "$1" ls-files --others --exclude-standard -- "${specs[@]}" 2>/dev/null)" ]
}

# second-brain validation run <project> <repo>: run the repo's checks that the level takes, from
# the repo's root, and print one row per check. With a base, a check with paths runs only when the
# diff from the base touches them. Usage: sb_val_run <repo> <validation.md> <shown path> <repo
# root> <level> <seconds> <json 0|1> [<base>]. Exits 0 when no check fails, else 1.
sb_val_run() {
  local name="$1" file="$2" show="$3" dir="$4" level="$5" limit="$6" json="$7" base="${8:-}"
  local checks kind a b logs="" rows="" n=0 bad=0 log result tab=$'\t' hash=""
  if [ -n "$base" ]; then
    hash="$(git -C "$dir" rev-parse --verify --quiet "$base^{commit}" 2>/dev/null)" ||
      sb_die 1 "--changed: no commit $base in $(sb_path_out "$dir")"
  fi
  checks="$(sb_section "$file" "$name" | sb_val_checks "$level")"
  if [ "$checks" = "none" ]; then
    sb_note "no ### Checks in $show"
    [ "$json" -eq 0 ] || printf '[]\n'
    return 0
  fi
  rows="$(mktemp "${TMPDIR:-/tmp}/sb-run-rows.XXXXXX")" || sb_die 1 "cannot write a temp file"
  SB_VAL_ROWS="$rows"
  while IFS="$tab" read -r kind a b; do
    [ -n "$kind" ] || continue
    case "$kind" in
      warn)
        sb_note "unknown when: $b, read as each merge: $a"
        continue
        ;;
      old) continue ;;
      run)
        if [ -n "$hash" ] && [ -n "$b" ] && ! sb_val_touched "$dir" "$hash" "$b"; then
          kind=skip
          b="no change to its paths since $base"
        fi
        ;;
    esac
    if [ "$kind" = "skip" ]; then
      printf 'R\t%s\tskipped\t-\t-\t-\nL\t%s\n' "$a" "$b" >>"$rows"
      [ "$json" -eq 1 ] || printf '%s\tskipped\t-\t-\t-\n  %s\n' "$a" "$b"
      continue
    fi
    if [ -z "$logs" ]; then
      logs="$(mktemp -d "${TMPDIR:-/tmp}/sb-run.XXXXXX")" || { rm -f "$rows"; sb_die 1 "cannot write a temp folder"; }
    fi
    n=$((n + 1))
    log="$logs/$n.log"
    sb_val_exec "$dir" "$a" "$limit" "$log"
    result=pass
    [ "$SB_VAL_RC" -eq 0 ] || { result=fail; bad=1; }
    printf 'R\t%s\t%s\t%s\t%s\t%s\n' "$a" "$result" "$SB_VAL_RC" "$SB_VAL_SECS" "$(sb_path_out "$log")" >>"$rows"
    if [ "$json" -eq 0 ]; then
      printf '%s\t%s\t%s\t%s\t%s\n' "$a" "$result" "$SB_VAL_RC" "$SB_VAL_SECS" "$(sb_path_out "$log")"
    fi
    if [ "$result" = "fail" ]; then
      {
        [ "$SB_VAL_TIMED" -eq 0 ] || printf 'stopped after %s seconds\n' "$limit"
        sb_val_lines "$log"
      } | while IFS= read -r b; do
        printf 'L\t%s\n' "$b" >>"$rows"
        [ "$json" -eq 1 ] || printf '  %s\n' "$b"
      done
    fi
  done <<EOF
$checks
EOF
  if [ "$json" -eq 1 ]; then
    LC_ALL=C awk -F'\t' "$(sb_awk_lib)"'
      function end_row() { if (open) printf "]}" }
      function num(v) { return (v == "-" ? "null" : v + 0) }
      BEGIN { printf "[" }
      $1 == "R" {
        end_row(); open = 1; nl = 0
        printf "%s\n  {\"command\": %s, \"result\": %s, \"exit\": %s, \"seconds\": %s, \"log\": %s, \"lines\": [", \
          (rows++ ? "," : ""), jstr($2), jstr($3), num($4), num($5), jstr($6)
        next
      }
      $1 == "L" { printf "%s%s", (nl++ ? ", " : ""), jstr(substr($0, 3)) }
      END { end_row(); print (rows ? "\n]" : "]") }' "$rows"
  fi
  rm -f "$rows"
  return "$bad"
}

# second-brain validation <project> [repo] [--path DIR] [--json] | validation new <project> <repo> |
# validation run <project> <repo> [--when W] [--changed BASE] [--timeout S] [--path DIR] [--json]
cmd_validation() {
  local new=0 run=0 a project="" repo="" row name home file show state rstate n=0 json=0
  local when=each-merge level=2 limit=1800 rpath rrow at="" hasat=0 changed=""
  local usage="usage: second-brain validation <project> [repo] [--path <dir>] [--json]"
  usage="$usage | validation new <project> <repo>"
  usage="$usage | validation run <project> <repo> [--when each-story|each-merge|release] [--changed <base>] [--timeout <seconds>] [--path <dir>] [--json]"
  case "${1:-}" in
    new) new=1; shift ;;
    run) run=1; shift ;;
  esac
  while [ $# -gt 0 ]; do
    a="$1"
    case "$a" in
      --json)
        [ "$new" -eq 0 ] || sb_die 5 "$usage"
        json=1
        shift
        continue
        ;;
      --when | --timeout)
        [ "$run" -eq 1 ] || sb_die 5 "$usage"
        [ $# -ge 2 ] || sb_die 5 "$a needs a value"
        if [ "$a" = "--when" ]; then when="$2"; else limit="$2"; fi
        shift 2
        continue
        ;;
      --changed)
        [ "$run" -eq 1 ] || sb_die 5 "$usage"
        case "${2:-}" in '' | -*) sb_die 5 "--changed needs a commit, such as the story's base" ;; esac
        changed="$2"
        shift 2
        continue
        ;;
      --path)
        [ "$new" -eq 0 ] || sb_die 5 "$usage"
        [ $# -ge 2 ] && [ -n "$2" ] || sb_die 5 "--path needs a folder"
        at="$2"
        hasat=1
        shift 2
        continue
        ;;
      -*) sb_die 5 "$usage" ;;
    esac
    n=$((n + 1))
    if [ "$n" -eq 1 ]; then project="$a"; else repo="$a"; fi
    shift
  done
  if [ "$new" -eq 1 ] || [ "$run" -eq 1 ]; then [ "$n" -eq 2 ] || sb_die 5 "$usage"; fi
  [ "$n" -ge 1 ] && [ "$n" -le 2 ] || sb_die 5 "$usage"
  [ "$hasat" -eq 0 ] || [ "$n" -eq 2 ] || sb_die 5 "$usage"
  if [ "$run" -eq 1 ]; then
    case "$when" in
      each-story | each-task) level=1 ;;
      each-merge | each-build) level=2 ;;
      release) level=3 ;;
      *) sb_die 5 "--when is one of: each-story, each-merge, release" ;;
    esac
    case "$limit" in
      '' | *[!0-9]*) sb_die 5 "--timeout takes a whole number of seconds above 0: $limit" ;;
    esac
    [ "$limit" -gt 0 ] 2>/dev/null || sb_die 5 "--timeout takes a whole number of seconds above 0: $limit"
  fi
  sb_need_project "$project"
  sb_need_profile
  if [ -z "$repo" ]; then
    if [ "$json" -eq 1 ]; then
      sb_val_rows | awk -F'\t' '{ print $1 "\t" $2 "\t" $4 "\t" $5 }' |
        sb_val_json_rows name home path state
    else
      sb_val_rows | awk -F'\t' '{ print $1 "\t" $2 "\t" $4 "\t" $5 }'
    fi
    return 0
  fi
  row="$(sb_val_repo_row "$repo")" || sb_die 1 "$repo is not in repos of $SB_P_NAME ($SB_P_PATH/claude/profile.md)"
  IFS=$'\t' read -r name file state <<EOF
$row
EOF
  row="$(sb_val_rows "$name")"
  IFS=$'\t' read -r name home file show state rstate <<EOF
$row
EOF
  # --path stands in for the repo's recorded folder, such as a git worktree of it: a repo home's
  # file is read from there, and the checks run there.
  if [ "$hasat" -eq 1 ]; then
    [ -d "$at" ] || sb_die 1 "the folder is missing: $(sb_path_out "$at")"
    at="$(cd "$at" && pwd)"
    if [ "$home" = "repo" ]; then
      file="$at/validation.md"
      show="$(sb_path_out "$file")"
      state="$(sb_val_state "$file" "$name")"
      rstate=ok
    fi
  fi
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
  if [ "$run" -eq 1 ]; then
    if [ "$hasat" -eq 1 ]; then
      rpath="$at"
    else
      rrow="$(sb_val_repo_row "$name")"
      IFS=$'\t' read -r name rpath rstate <<EOF
$rrow
EOF
      sb_val_need_folder "$name" "$rpath" "$rstate"
    fi
    sb_val_run "$name" "$file" "$show" "$rpath" "$level" "$limit" "$json" "$changed"
    return $?
  fi
  if [ "$json" -eq 1 ]; then
    SB_PATH="$show" SB_BODY="$(sb_section "$file" "$name")" LC_ALL=C awk "$(sb_awk_lib)"'
      BEGIN {
        printf "{\n  \"path\": %s,\n", jstr(ENVIRON["SB_PATH"])
        printf "  \"body\": %s\n}\n", jstr(ENVIRON["SB_BODY"])
      }'
    return 0
  fi
  printf 'path: %s\n' "$show"
  sb_section "$file" "$name" || true
}
