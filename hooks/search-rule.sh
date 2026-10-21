#!/usr/bin/env bash
# search-rule.sh - the PreToolUse hook. When a Grep call, a Read of a whole task note, or a shell
# grep, cat or sed reaches into the vault, it adds a warning to Claude's context that names the
# helper commands to use. It reads the hook's JSON on stdin and prints nothing, or one JSON object
# with additionalContext and no permissionDecision, so the call goes on through the normal
# permission flow: it never blocks, never approves, and always exits 0.
# It runs on every Bash, Grep and Read call, so it loads no library and starts one awk.
set -u

# The vault as the helper finds it: the override, or the pointer in the link directory.
v="${SECOND_BRAIN_VAULT:-}"
if [ -z "$v" ]; then
  v="${SECOND_BRAIN_CLAUDE_HOME:-}"
  [ -n "$v" ] || v="${HOME:-}/.claude"
  v="${v%/}/second-brain-vault"
fi
if [ ! -d "$v/.obsidian" ] || ! cd -P "$v" 2>/dev/null; then exit 0; fi

SB_RULE_VAULT="$v" SB_RULE_ROOT="$PWD" LC_ALL=C awk '
# The last two parts of a path, in lower case with forward slashes. Every form of the path ends
# with them: through ~/ or $HOME/, in the drive form C:/ or in the Git Bash form /c/.
function tail2(p,   n, a) {
  p = tolower(p)
  gsub(/\\/, "/", p)
  sub(/\/+$/, "", p)
  n = split(p, a, "/")
  if (n == 0 || a[n] == "") return ""
  return (n > 1 ? a[n - 1] : "") "/" a[n]
}
# The string value of the first "<key>", with its escapes undone, every backslash made a slash and
# blanks for line breaks, in lower case; empty when there is none.
function str(k,   r) {
  if (!match(s, "\"" k "\"[ \t\r\n]*:[ \t\r\n]*\"")) return ""
  r = substr(s, RSTART + RLENGTH)
  r = substr(r, 1, index(r, "\"") - 1)
  gsub(/\\[nrt]/, " ", r)
  gsub(/\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/, "?", r)
  gsub(/\\/, "", r)
  gsub("\037", "\"", r)
  gsub("\036", "/", r)
  return tolower(r)
}
# A regex that matches the text itself: each character but a letter or a digit stands in brackets,
# or after a backslash where brackets would not hold it.
function lit(t,   i, c, r) {
  r = ""
  for (i = 1; i <= length(t); i++) {
    c = substr(t, i, 1)
    if (c ~ /[a-z0-9]/) r = r c
    else if (c == "^" || c == "[" || c == "]") r = r "\\" c
    else r = r "[" c "]"
  }
  return r
}
# 1 when the text holds a form of the vault path as whole names: after a slash, a quote, a blank or
# the start, and before the end or a character no file name goes on with. One regex match per form
# reads the text once, however many near misses it holds.
function hit(p,   k) {
  p = " " p " "
  for (k = 1; k <= nn; k++) if (p ~ re[k]) return 1
  return 0
}
{ s = s $0 "\n" }
END {
  # An escaped backslash, then an escaped quote, become one byte each, so a quote ends a string.
  gsub(/\\\\/, "\036", s)
  gsub(/\\"/, "\037", s)
  nn = 0
  if ((t = tail2(ENVIRON["SB_RULE_VAULT"])) != "") nd[++nn] = t
  if ((t = tail2(ENVIRON["SB_RULE_ROOT"])) != "" && t != nd[1]) nd[++nn] = t
  # A form that starts with a slash, the vault one folder below the root, has its boundary in it.
  for (k = 1; k <= nn; k++) re[k] = (substr(nd[k], 1, 1) == "/" ? "" : "[/\"\047 \t]") lit(nd[k]) "[^a-z0-9._-]"
  tool = str("tool_name")
  here = hit(str("cwd"))
  what = ""
  if (tool == "read") {
    p = str("file_path")
    if (hit(p) && p ~ /\/tasks\/(archive\/[0-9][0-9][0-9][0-9]\/)?[^\/]+\/readme\.md$/ && !match(s, /"(offset|limit)"[ \t\r\n]*:[ \t\r\n]*[0-9]/))
      what = "This Read takes a whole task note."
  } else if (tool == "grep") {
    p = str("path")
    if ((p == "" && here) || hit(p)) what = "This Grep call searches vault files."
  } else if (tool == "bash") {
    c = str("command")
    if (match(c, /(^|[^a-z0-9_.-])(grep|egrep|fgrep|rg|cat|sed)([ \t]|$)/) && (here || hit(c) || index(c, "second-brain root"))) {
      w = substr(c, RSTART, RLENGTH)
      gsub(/[^a-z]/, "", w)
      what = "This command runs " w " on vault files."
    }
  }
  if (what == "") exit
  printf "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"%s\"}}\n",
    "second-brain: " what " The vault rule finds notes with `second-brain find <ID-or-alias>` or `second-brain search <project> <text>`, reads a task with `second-brain task head <ID>`, then `second-brain outline <path>` and a ranged Read, and a whole note last. It never runs grep, cat or sed on vault files."
}'
exit 0
