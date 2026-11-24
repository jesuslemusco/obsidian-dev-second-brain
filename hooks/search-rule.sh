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
# blanks for line breaks, in lower case, or as written when keep is set; empty when there is none.
function str(k, keep,   r) {
  if (!match(s, "\"" k "\"[ \t\r\n]*:[ \t\r\n]*\"")) return ""
  r = substr(s, RSTART + RLENGTH)
  r = substr(r, 1, index(r, "\"") - 1)
  gsub(/\\[nrt]/, " ", r)
  gsub(/\\u[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/, "?", r)
  gsub(/\\/, "", r)
  gsub("\037", "\"", r)
  gsub("\036", "/", r)
  return keep ? r : tolower(r)
}
# 1 when g, a folder name in lower case, is a group folder: a status folder, backlog, or a folder
# with no README.md of its own, f, such as the folder of a sprint, looked up on disk in the letter
# case of the path. archive is no group folder.
function group(g, f,   line) {
  if (g == "archive") return 0
  if (g ~ /^(planned|in-progress|in-review|done|abandoned|backlog)$/) return 1
  if ((getline line < f) >= 0) { close(f); return 0 }
  return 1
}
# The value of a key in the frontmatter of a note, unquoted and in lower case; for aliases, each item
# with a newline before it. Empty when the note or the key is not there.
function front(f, k,   line, n, key, v, out, nv, it, j) {
  n = 0; key = ""; out = ""
  while ((getline line < f) > 0) {
    n++; sub(/\r$/, "", line)
    if (n == 1) { sub(/^\357\273\277/, "", line); if (line != "---") break; continue }
    if (line == "---") break
    if (line ~ /^[A-Za-z0-9_][A-Za-z0-9_-]*:/) {
      key = line; sub(/:.*$/, "", key); v = line; sub(/^[^:]*:[ \t]*/, "", v)
      if (key != k) continue
      if (k != "aliases") { out = bare(v); break }
      gsub(/^\[|\][ \t]*$/, "", v); nv = split(v, it, ",")
      for (j = 1; j <= nv; j++) if (bare(it[j]) != "") out = out "\n" bare(it[j])
    } else if (k == "aliases" && key == k && line ~ /^[ \t]*-([ \t]|$)/) {
      v = line; sub(/^[ \t]*-[ \t]*/, "", v); out = out "\n" bare(v)
    }
  }
  close(f)
  return out
}
# A YAML scalar in lower case, with its blanks and quotes taken off.
function bare(v) {
  sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
  if (v ~ /^".*"$/ || v ~ /^\047.*\047$/) v = substr(v, 2, length(v) - 2)
  return tolower(v)
}
# A path in single quotes, for the shell.
function shq(t) { gsub(/\047/, "\047\\\\\047\047", t); return "\047" t "\047" }
# A task found elsewhere in the tasks folder: its folder name counts at once, and its aliases once
# a folder with no README of its own needs them.
function found(f,   d) {
  d = f; sub(/\/[^\/]*$/, "", d); sub(/^.*\//, "", d)
  fname[tolower(d)] = 1; fsrc[++fns] = f
}
function fnamed(h,   i, k, m, it) {
  if (h in fname) return 1
  for (i = 1; i <= fns; i++) {
    if (fsrc[i] in floaded) continue
    floaded[fsrc[i]] = 1
    m = split(front(fsrc[i], "aliases"), it, "\n")
    for (k = 1; k <= m; k++) if (it[k] != "") falias[it[k]] = 1
  }
  return (h in falias)
}
# 1 when a folder g of the tasks folder is a group folder, as group() says, from the READMEs found.
function isgroup(g) {
  if (tolower(g) == "archive") return 0
  if (tolower(g) ~ /^(planned|in-progress|in-review|done|abandoned|backlog)$/) return 1
  return !((g "/README.md") in fhas)
}
# 1 when raw, a README one level deeper in a folder with no README of its own, is a task, as the
# helper finds it: when that folder is named for a task found elsewhere in the tasks folder, by its
# folder name or an alias, without letter case. A task found elsewhere is one directly under the
# tasks folder, in a group folder or in the archive, a child inside its parent folder, or one such a
# folder holds. One find lists the READMEs of the tasks folder.
function held(raw, p,   td, cmd, line, rel, n, a, i, nl, lst, row, okr, nr, e, more, want) {
  td = raw; sub(/\/[^\/]*\/[^\/]*\/[^\/]*\/[^\/]*$/, "", td)
  want = p; sub(/^.*\/tasks\//, "", want)
  cmd = "find " shq(td) " -mindepth 2 -maxdepth 4 -name README.md 2>/dev/null"
  nl = 0
  while ((cmd | getline line) > 0) {
    if (substr(line, 1, length(td) + 1) != td "/") continue
    rel = substr(line, length(td) + 2); lst[++nl] = rel; fhas[rel] = 1
  }
  close(cmd)
  nr = 0
  for (i = 1; i <= nl; i++) {
    rel = lst[i]; n = split(rel, a, "/")
    if (n == 2) {
      if (tolower(a[1]) !~ /^(archive|planned|in-progress|in-review|done|abandoned|backlog)$/) found(td "/" rel)
    } else if (n == 3) {
      if (isgroup(a[1])) found(td "/" rel)
    } else if (n == 4 && tolower(a[1]) == "archive") {
      if (a[2] ~ /^[0-9][0-9][0-9][0-9]$/) found(td "/" rel)
    } else if (n == 4 && isgroup(a[1])) {
      if ((a[1] "/" a[2] "/README.md") in fhas) {
        e = front(td "/" rel, "epic")
        if (e != "" && e != "-" && (e == tolower(a[2]) || index(front(td "/" a[1] "/" a[2] "/README.md", "aliases") "\n", "\n" e "\n"))) found(td "/" rel)
      } else row[++nr] = rel
    }
  }
  # A folder may lean on a task another such folder holds: go round until none is added.
  do {
    more = 0
    for (i = 1; i <= nr; i++) {
      if (i in okr) continue
      split(row[i], a, "/")
      if (fnamed(tolower(a[2]))) { okr[i] = 1; found(td "/" row[i]); more = 1 }
    }
  } while (more)
  for (i = 1; i <= nr; i++) if ((i in okr) && tolower(row[i]) == want) return 1
  return 0
}
# 1 when a README read as a task note, p in lower case and raw as written, is one: directly in a
# folder under tasks/ or under a year of the archive, or in a folder under a group folder. A folder
# with a README.md is a task, so a README in a folder inside it is no task note, but for a child
# task: one level deeper, in tasks/<group>/<parent>/<ID>/, a README whose epic names <parent>, by
# its folder name or an alias of <parent>/README.md. With no <parent>/README.md, held() decides.
function tasknote(p, raw,   a, n, f, e, al, line) {
  n = split(p, a, "/")
  if (a[n - 2] == "tasks") return 1
  if (a[n - 4] == "tasks" && a[n - 3] == "archive" && a[n - 2] ~ /^[0-9][0-9][0-9][0-9]$/) return 1
  if (a[n - 3] == "tasks") {
    f = raw
    sub(/\/[^\/]*\/[^\/]*$/, "/README.md", f)
    return group(a[n - 2], f)
  }
  if (a[n - 4] != "tasks") return 0
  f = raw
  sub(/\/[^\/]*\/[^\/]*\/[^\/]*$/, "/README.md", f)
  if (!group(a[n - 3], f)) return 0
  f = raw
  sub(/\/[^\/]*\/[^\/]*$/, "/README.md", f)
  if ((getline line < f) < 0) return held(raw, p)
  close(f)
  e = front(raw, "epic")
  if (e == "" || e == "-") return 0
  if (e == a[n - 2]) return 1
  al = front(f, "aliases") "\n"
  return (index(al, "\n" e "\n") > 0)
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
# 1 when the text holds a form of the vault path as whole names: after the start or a character no
# file name goes on with, and before the end or such a character. One regex match per form reads the
# text once, however many near misses it holds.
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
  for (k = 1; k <= nn; k++) re[k] = (substr(nd[k], 1, 1) == "/" ? "" : "[^a-z0-9._-]") lit(nd[k]) "[^a-z0-9._-]"
  tool = str("tool_name")
  here = hit(str("cwd"))
  what = ""
  if (tool == "read") {
    p = str("file_path")
    if (hit(p) && p ~ /\/readme\.md$/ && tasknote(p, str("file_path", 1)) && !match(s, /"(offset|limit)"[ \t\r\n]*:[ \t\r\n]*[0-9]/))
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
