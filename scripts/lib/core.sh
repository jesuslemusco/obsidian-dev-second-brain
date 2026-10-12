#!/usr/bin/env bash
# core.sh - errors, vault root, dates, frontmatter and template filling.

# Print a message to stderr and exit with a code.
sb_die() {
  local code="$1"
  shift
  printf 'second-brain: %s\n' "$*" >&2
  exit "$code"
}

# Print a side note to stderr.
sb_note() {
  printf 'note: %s\n' "$*" >&2
}

# Print the short usage text.
sb_usage() {
  cat <<'EOF'
usage: second-brain <command> [args]
lookups:  help | version | root | context [--cwd DIR] | projects
          conventions [section]   (default: The short version)
          project --name N | --key K | --cwd DIR
          profile <project> --keys | <section> | repo <project> [name]
          board <project> [view] | topic <project> <tag>
          find <ID-or-alias> [--project P] | search <project> "<text>" [--in SUBPATH]
notes:    outline <path> | backlinks <path> | unresolved [project]
          move <from> <to> [--dry-run] | rename <path> <name> [--dry-run]
          (<path> is a vault path: from the vault root, with forward slashes)
tasks:    task head <ID> | task set <ID> key=value... | task note <ID> "<text>" [--session S]
          task tag <ID> add|remove <tag> | task alias <ID> add <alias>
          task new <ID> [--project P] [--title T] [--topics a,b] [--envs]
          (<ID> is the folder id or any alias; every task command takes --project P)
sprints:  sprint current <project> | sprint next <project>
          sprint open <project> [--end YYYY-MM-DD] [--goal G]
          sprint set <project> goal=<text> committed=<n>
          sprint close <project> [--carry IDs] [--backlog IDs] [--abandon IDs]
setup:    scaffold vault [DIR]
          scaffold project <name> --path P [--keys K1,K2] [--use-when TEXT]
              [--tasks-root R] [--topics-root R] [--sprints-root R] [--no-sprints]
          pointer | pointer set <DIR> [--replace]
          link [--check | --apply] | doctor [project] [--json] [--fix]
          snapshot [name] | compare [name] | session-check
exit codes: 0 ok, 1 not found, 2 setup missing, 4 ambiguous, 5 bad usage,
            6 already exists
EOF
}

# Print the plugin repo root.
sb_plugin_root() {
  if [ -n "${SB_PLUGIN_ROOT:-}" ]; then
    printf '%s\n' "$SB_PLUGIN_ROOT"
  else
    (cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
  fi
}

# Print the physical vault root, or exit 2. The pointer is second-brain-vault in the link directory.
sb_root() {
  local v="${SECOND_BRAIN_VAULT:-}"
  if [ -n "$v" ]; then v="$(sb_path_in "$v")"; else v="$(sb_link_home)/second-brain-vault"; fi
  [ -d "$v" ] || sb_die 2 "no vault found: the pointer second-brain-vault is missing from the link directory (run vault-setup init)"
  [ -d "$v/.obsidian" ] || sb_die 2 "not a vault, it has no .obsidian folder: $(sb_path_out "$v")"
  (cd -P "$v" 2>/dev/null && pwd -P) || sb_die 2 "cannot open the vault: $(sb_path_out "$v")"
}

# Set SB_ROOT once, or exit 2.
sb_need_root() {
  [ -n "${SB_ROOT:-}" ] && return 0
  SB_ROOT="$(sb_root)" || exit 2
}

# Print a path relative to the vault root.
sb_rel() {
  printf '%s\n' "${1#"$SB_ROOT"/}"
}

# Print today's date; SECOND_BRAIN_TODAY overrides it.
sb_today() {
  if [ -n "${SECOND_BRAIN_TODAY:-}" ]; then
    printf '%s\n' "$SECOND_BRAIN_TODAY"
  else
    date +%Y-%m-%d
  fi
}

# Print the awk functions shared by the awk programs in this plugin.
# Every awk that loads them runs with LC_ALL=C: cut() matches bytes, and gawk refuses that
# pattern in a UTF-8 locale, which stops the whole program.
sb_awk_lib() {
  cat <<'AWK'
function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
function unq(s,   q, i, c, out, n) {
  s = trim(s)
  q = substr(s, 1, 1)
  n = length(s)
  if (q == "\"") {
    out = ""
    for (i = 2; i <= n; i++) {
      c = substr(s, i, 1)
      if (c == "\\" && i < n) { i++; out = out substr(s, i, 1); continue }
      if (c == "\"") return out
      out = out c
    }
    return out
  }
  if (q == "'") {
    out = ""
    for (i = 2; i <= n; i++) {
      c = substr(s, i, 1)
      if (c == "'") {
        if (substr(s, i + 1, 1) == "'") { out = out "'"; i++; continue }
        return out
      }
      out = out c
    }
    return out
  }
  if (q == "#") return ""
  i = match(s, /[ \t]#/)
  if (i > 0) s = trim(substr(s, 1, i - 1))
  return s
}
function split_inline(s, items,   n, i, c, cur, q, len, k) {
  s = trim(s)
  sub(/^\[/, "", s)
  k = 0
  for (i = length(s); i >= 1; i--) if (substr(s, i, 1) == "]") { k = i; break }
  if (k > 0) s = substr(s, 1, k - 1)
  n = 0; cur = ""; q = ""; len = length(s)
  for (i = 1; i <= len; i++) {
    c = substr(s, i, 1)
    if (q != "") {
      cur = cur c
      if (c == "\\" && q == "\"" && i < len) { i++; cur = cur substr(s, i, 1) }
      else if (c == q) q = ""
      continue
    }
    if ((c == "\"" || c == "'") && trim(cur) == "") { q = c; cur = cur c; continue }
    if (c == ",") { cur = trim(cur); if (cur != "") items[++n] = unq(cur); cur = ""; continue }
    cur = cur c
  }
  cur = trim(cur)
  if (cur != "") items[++n] = unq(cur)
  return n
}
function dq(s,   i, c, out, n) {
  out = ""; n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (c == "\\" || c == "\"") out = out "\\"
    out = out c
  }
  return "\"" out "\""
}
function yq(s, force,   need, l) {
  need = force ? 1 : 0
  l = tolower(s)
  if (s == "") need = 1
  else if (s ~ /^[ \t]/ || s ~ /[ \t]$/ || s ~ /:$/) need = 1
  else if (index(s, ": ") > 0 || index(s, "#") > 0) need = 1
  else if (index("-[]{}!&*|>@%?,\"'`", substr(s, 1, 1)) > 0) need = 1
  else if (s ~ /^[+.]?[0-9]/) need = 1
  else if (l == "true" || l == "false" || l == "null" || l == "yes" || l == "no" || l == "on" || l == "off" || l == "~") need = 1
  return need ? dq(s) : s
}
function mapfield(s, name,   v) {
  if (!match(s, name ":[ \t]*[^,}]*")) return ""
  v = unq(substr(s, RSTART + length(name) + 1, RLENGTH - length(name) - 1))
  return (v == "" ? "-" : v)
}
function cut(s, max) {
  if (length(s) <= max) return s
  s = substr(s, 1, max)
  sub(/[\300-\367][\200-\277]*$/, "", s)
  return s "..."
}
function days_from_civil(y, m, d,   era, yoe, doy, doe) {
  if (m <= 2) y -= 1
  era = int((y >= 0 ? y : y - 399) / 400)
  yoe = y - era * 400
  doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
  doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
  return era * 146097 + doe - 719468
}
function civil_from_days(z,   era, doe, yoe, y, doy, mp, d, m) {
  z += 719468
  era = int((z >= 0 ? z : z - 146096) / 146097)
  doe = z - era * 146097
  yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365)
  y = yoe + era * 400
  doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100))
  mp = int((5 * doy + 2) / 153)
  d = doy - int((153 * mp + 2) / 5) + 1
  m = mp + (mp < 10 ? 3 : -9)
  if (m <= 2) y += 1
  return sprintf("%04d-%02d-%02d", y, m, d)
}
function date_days(s) {
  return days_from_civil(substr(s, 1, 4) + 0, substr(s, 6, 2) + 0, substr(s, 9, 2) + 0)
}
function date_ok(s) {
  if (s !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) return 0
  return civil_from_days(date_days(s)) == s
}
AWK
}

# Return 0 when the argument is a real YYYY-MM-DD date.
sb_date_ok() {
  LC_ALL=C SB_D="$1" awk "$(sb_awk_lib)"'BEGIN { exit(date_ok(ENVIRON["SB_D"]) ? 0 : 1) }'
}

# Print a date shifted by a number of days.
sb_date_add() {
  LC_ALL=C SB_D="$1" SB_N="$2" awk "$(sb_awk_lib)"'BEGIN { print civil_from_days(date_days(ENVIRON["SB_D"]) + ENVIRON["SB_N"]) }'
}

# Print the number of days from the second date to the first.
sb_date_diff() {
  LC_ALL=C SB_A="$1" SB_B="$2" awk "$(sb_awk_lib)"'BEGIN { print date_days(ENVIRON["SB_A"]) - date_days(ENVIRON["SB_B"]) }'
}

# Print a value as a YAML scalar, quoted when it needs it; a second argument forces quotes.
sb_yaml_quote() {
  LC_ALL=C SB_V="$1" SB_F="${2:-}" awk "$(sb_awk_lib)"'BEGIN { print yq(ENVIRON["SB_V"], ENVIRON["SB_F"] != "") }'
}

# Return 0 when two files hold the same bytes.
sb_same_file() {
  if command -v cmp >/dev/null 2>&1; then
    cmp -s "$1" "$2"
  else
    [ "$(cat "$1"; printf x)" = "$(cat "$2"; printf x)" ]
  fi
}

# Print a scalar frontmatter value, unquoted; return 1 when the key is absent.
sb_fm_get() {
  [ -f "$1" ] || return 1
  LC_ALL=C SB_KEY="$2" awk "$(sb_awk_lib)"'
    BEGIN { key = ENVIRON["SB_KEY"] ":"; klen = length(key); found = 0 }
    { sub(/\r$/, "") }
    NR == 1 { sub(/^\357\273\277/, ""); if ($0 != "---") exit; next }
    $0 == "---" { exit }
    substr($0, 1, klen) == key { print unq(substr($0, klen + 1)); found = 1; exit }
    END { exit(found ? 0 : 1) }
  ' "$1"
}

# Print a frontmatter list, one item per line (block or inline form).
sb_fm_list() {
  [ -f "$1" ] || return 1
  LC_ALL=C SB_KEY="$2" awk "$(sb_awk_lib)"'
    BEGIN { key = ENVIRON["SB_KEY"] ":"; klen = length(key); inlist = 0 }
    { sub(/\r$/, "") }
    NR == 1 { sub(/^\357\273\277/, ""); if ($0 != "---") exit; next }
    $0 == "---" { exit }
    inlist {
      if ($0 ~ /^[ \t]*-([ \t]|$)/) {
        v = $0; sub(/^[ \t]*-[ \t]*/, "", v); v = unq(v)
        if (v != "") print v
        next
      }
      if ($0 ~ /^[ \t]*(#.*)?$/) next
      exit
    }
    substr($0, 1, klen) == key {
      v = trim(substr($0, klen + 1))
      if (v == "" || substr(v, 1, 1) == "#") { inlist = 1; next }
      if (substr(v, 1, 1) == "[") {
        n = split_inline(v, items)
        for (i = 1; i <= n; i++) print items[i]
        exit
      }
      print unq(v)
      exit
    }
  ' "$1"
}

# Print the frontmatter as "key: value" lines, lists joined with ", ".
sb_fm_keys() {
  [ -f "$1" ] || return 1
  LC_ALL=C awk "$(sb_awk_lib)"'
    function flush() { if (key != "") print key ":" (val == "" ? "" : " " val); key = ""; val = "" }
    function add(v) { if (v != "") val = (val == "" ? v : val ", " v) }
    { sub(/\r$/, "") }
    NR == 1 { sub(/^\357\273\277/, ""); if ($0 != "---") exit; next }
    $0 == "---" { exit }
    /^[A-Za-z0-9_][A-Za-z0-9_-]*:/ {
      flush()
      i = index($0, ":"); key = substr($0, 1, i - 1); v = trim(substr($0, i + 1))
      if (substr(v, 1, 1) == "[") { n = split_inline(v, items); for (k = 1; k <= n; k++) add(items[k]) }
      else add(unq(v))
      next
    }
    key != "" && /^[ \t]*-([ \t]|$)/ { v = $0; sub(/^[ \t]*-[ \t]*/, "", v); add(unq(v)); next }
    key != "" && /^[ \t]+[^ \t#]/ { add(trim($0)) }
    END { flush() }
  ' "$1"
}

# Apply one frontmatter edit, keeping line endings; sets SB_FM_CHANGED.
# Ops: set <raw>, setblock <child lines>, del, listadd <item> [force], listswap <prefix> <item>,
# tagadd <item> (before the type/ and status/ items), listdel <item>. List items match without case.
sb_fm_edit() {
  local file="$1" op="$2" key="$3" a1="${4-}" a2="${5-}" tmp eofnl=1
  SB_FM_CHANGED=0
  [ -f "$file" ] || return 1
  if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then eofnl=0; fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/sb-fm.XXXXXX")" || return 1
  LC_ALL=C SB_OP="$op" SB_KEY="$key" SB_A1="$a1" SB_A2="$a2" SB_EOFNL="$eofnl" awk "$(sb_awk_lib)"'
    function put(s) { printf "%s%s", sep, s; sep = "\n" }
    function bare(i,   l) { l = fm[i]; sub(/\r$/, "", l); return l }
    function topkey(l,   i) {
      if (l !~ /^[A-Za-z0-9_][A-Za-z0-9_-]*:([ \t]|$)/) return ""
      i = index(l, ":")
      return substr(l, 1, i - 1)
    }
    function ischild(l) { return (l ~ /^[ \t]+[^ \t]/ || l ~ /^-([ \t]|$)/) }
    function scan(   i, l, k, cur) {
      cur = ""
      for (i = 1; i <= n; i++) {
        l = bare(i); k = topkey(l)
        if (k != "") {
          if (k in kstart) cur = ""
          else { cur = k; kstart[k] = i; kend[k] = i }
          continue
        }
        if (cur == "") continue
        if (l ~ /^[ \t]*$/ || l ~ /^[ \t]*#/) continue
        if (ischild(l)) kend[cur] = i
        else cur = ""
      }
    }
    function insert_at(   m, order, i, idx, j) {
      m = split("aliases title status next branch epic envs sprint carried_from type", order, " ")
      idx = 0
      for (i = 1; i <= m; i++) if (order[i] == key) idx = i
      if (idx) for (j = idx - 1; j >= 1; j--) if (order[j] in kend) return kend[order[j]] + 1
      if ("tags" in kstart) return kstart["tags"]
      return n + 1
    }
    function replace_key(   i) {
      if (has) { for (i = ks; i <= ke; i++) drop[i] = 1; ins_at = ks }
      else ins_at = insert_at()
    }
    function inline_text(cnt,   i, s) {
      s = ""
      for (i = 1; i <= cnt; i++) s = s (i > 1 ? ", " : "") yq(items[i], 0)
      return key ": [" s "]"
    }
    function plan(   l, v, i, cnt, form, indent, t, first, hit, m, keep, pos) {
      ni = 0; ins_at = 0
      has = (key in kstart)
      if (has) { ks = kstart[key]; ke = kend[key] }
      if (op == "del") { if (has) for (i = ks; i <= ke; i++) drop[i] = 1; return }
      if (op == "set") { replace_key(); ins[++ni] = key ": " a1; return }
      if (op == "setblock") {
        replace_key(); ins[++ni] = key ":"
        m = split(a1, keep, "\n")
        for (i = 1; i <= m; i++) if (keep[i] != "") ins[++ni] = keep[i]
        return
      }
      cnt = 0; indent = "  "; form = "none"
      if (has) {
        l = bare(ks); v = trim(substr(l, length(key) + 2))
        if (substr(v, 1, 1) == "#") v = ""
        if (v == "") {
          form = "block"; first = 1
          for (i = ks + 1; i <= ke; i++) {
            l = bare(i)
            if (l !~ /^[ \t]*-([ \t]|$)/) continue
            if (first) { indent = l; sub(/-.*$/, "", indent); first = 0 }
            t = l; sub(/^[ \t]*-[ \t]*/, "", t)
            items[++cnt] = unq(t); lineof[cnt] = i
          }
        } else if (substr(v, 1, 1) == "[") { form = "inline"; cnt = split_inline(v, items) }
        else { form = "scalar"; cnt = 1; items[1] = unq(v) }
      }
      if (op == "listadd") {
        for (i = 1; i <= cnt; i++) if (tolower(items[i]) == tolower(a1)) return
        if (form == "block") { ins_at = ke + 1; ins[++ni] = indent "- " yq(a1, a2 != ""); return }
        replace_key(); ins[++ni] = key ":"
        for (i = 1; i <= cnt; i++) ins[++ni] = indent "- " yq(items[i], a2 != "")
        ins[++ni] = indent "- " yq(a1, a2 != "")
        return
      }
      if (op == "tagadd") {
        pos = 0
        for (i = 1; i <= cnt; i++) {
          if (tolower(items[i]) == tolower(a1)) return
          if (!pos && (substr(items[i], 1, 5) == "type/" || substr(items[i], 1, 7) == "status/")) pos = i
        }
        if (form == "block") {
          if (pos) { t = bare(lineof[pos]); sub(/-.*$/, "", t); ins_at = lineof[pos]; ins[++ni] = t "- " yq(a1, 0) }
          else { ins_at = ke + 1; ins[++ni] = indent "- " yq(a1, 0) }
          return
        }
        m = 0
        for (i = 1; i <= cnt; i++) { if (i == pos) keep[++m] = a1; keep[++m] = items[i] }
        if (!pos) keep[++m] = a1
        for (i = 1; i <= m; i++) items[i] = keep[i]
        replace_key()
        if (form == "inline" && cnt > 0) { ins[++ni] = inline_text(m); return }
        ins[++ni] = key ":"
        for (i = 1; i <= m; i++) ins[++ni] = indent "- " yq(items[i], 0)
        return
      }
      if (op == "listdel") {
        hit = 0; m = 0
        for (i = 1; i <= cnt; i++) {
          if (tolower(items[i]) == tolower(a1)) { hit = 1; if (form == "block") drop[lineof[i]] = 1 }
          else keep[++m] = items[i]
        }
        if (!hit || (form == "block" && m > 0)) return
        for (i = 1; i <= m; i++) items[i] = keep[i]
        replace_key()
        ins[++ni] = (m == 0 ? key ": []" : inline_text(m))
        return
      }
      if (op == "listswap") {
        hit = 0
        if (form == "block") {
          for (i = 1; i <= cnt; i++) {
            if (substr(items[i], 1, length(a1)) != a1) continue
            if (!hit) { hit = 1; t = bare(lineof[i]); sub(/-.*$/, "", t); repl[lineof[i]] = t "- " yq(a2, 0) }
            else drop[lineof[i]] = 1
          }
          if (!hit) { ins_at = ke + 1; ins[++ni] = indent "- " yq(a2, 0) }
          return
        }
        m = 0
        for (i = 1; i <= cnt; i++) {
          if (substr(items[i], 1, length(a1)) == a1) { if (hit) continue; hit = 1; keep[++m] = a2 }
          else keep[++m] = items[i]
        }
        if (!hit) keep[++m] = a2
        for (i = 1; i <= m; i++) items[i] = keep[i]
        replace_key()
        if (form == "inline" && cnt > 0) { ins[++ni] = inline_text(m); return }
        ins[++ni] = key ":"
        for (i = 1; i <= m; i++) ins[++ni] = indent "- " yq(items[i], 0)
        return
      }
    }
    function flush_fm(   i, j) {
      scan(); plan()
      for (i = 1; i <= n + 1; i++) {
        if (i == ins_at) for (j = 1; j <= ni; j++) put(ins[j] eol)
        if (i <= n && !(i in drop)) put((i in repl) ? repl[i] eol : fm[i])
      }
    }
    BEGIN {
      op = ENVIRON["SB_OP"]; key = ENVIRON["SB_KEY"]; a1 = ENVIRON["SB_A1"]; a2 = ENVIRON["SB_A2"]
      eofnl = ENVIRON["SB_EOFNL"] + 0
      state = 0; n = 0; sep = ""
    }
    {
      raw = $0; line = raw; sub(/\r$/, "", line)
      if (NR == 1) {
        eol = (raw != line) ? "\r" : ""
        first_line = line; sub(/^\357\273\277/, "", first_line)
        if (first_line == "---") { state = 1; put(raw); next }
        scan(); plan()
        if (ni > 0) {
          put("---" eol)
          for (j = 1; j <= ni; j++) put(ins[j] eol)
          put("---" eol)
        }
        state = 2; put(raw); next
      }
      if (state == 1) {
        if (line == "---") { flush_fm(); put(raw); state = 2; next }
        fm[++n] = raw
        next
      }
      put(raw)
    }
    END {
      if (state == 1) for (i = 1; i <= n; i++) put(fm[i])
      if (eofnl && NR > 0) printf "\n"
    }
  ' "$file" >"$tmp" || { rm -f "$tmp"; return 1; }
  if ! sb_same_file "$tmp" "$file"; then
    cat "$tmp" >"$file"
    SB_FM_CHANGED=1
  fi
  rm -f "$tmp"
  return 0
}

# Write a scalar key with a raw, already formatted value.
sb_fm_set_raw() {
  sb_fm_edit "$1" set "$2" "$3"
}

# Set a scalar key, or remove it when the value is empty; keeps line endings.
sb_fm_set() {
  local file="$1" key="$2" value="${3-}" force=""
  value="$(printf '%s' "$value" | tr '\n\r\t' '   ')"
  if [ -z "$value" ]; then
    sb_fm_edit "$file" del "$key"
    return $?
  fi
  case "$key" in sprint | sprint_anchor_end) force=1 ;; esac
  sb_fm_edit "$file" set "$key" "$(sb_yaml_quote "$value" "$force")"
}

# Set the status/ tag that rolls a status up.
sb_fm_status_tag() {
  local rollup="status/active"
  case "$2" in done | abandoned) rollup="status/done" ;; esac
  sb_fm_edit "$1" listswap tags "status/" "$rollup"
}

# Print the body of a level-2 section; return 1 when the heading is absent.
sb_section() {
  [ -f "$1" ] || return 1
  LC_ALL=C SB_H="$2" awk "$(sb_awk_lib)"'
    BEGIN { want = tolower(trim(ENVIRON["SB_H"])); insec = 0; found = 0; fence = 0; nb = 0 }
    { line = $0; sub(/\r$/, "", line) }
    line ~ /^(```|~~~)/ { fence = !fence }
    !fence && line ~ /^## / {
      if (insec) exit
      h = line; sub(/^##[ \t]+/, "", h); sub(/[ \t#]+$/, "", h)
      if (tolower(h) == want) { insec = 1; found = 1 }
      next
    }
    !fence && line ~ /^# / && insec { exit }
    insec {
      if (line ~ /^[ \t]*$/) { nb++; next }
      if (started) for (; nb > 0; nb--) print ""
      nb = 0; started = 1
      print line
    }
    END { exit(found ? 0 : 1) }
  ' "$1"
}

# Print a template with its placeholders filled from KEY=VALUE pairs.
sb_fill_text() {
  local tmpl kv
  tmpl="$(sb_plugin_root)/templates/$1"
  shift
  [ -f "$tmpl" ] || sb_die 2 "template missing: $tmpl"
  local assigns
  assigns=("SBT__=1")
  for kv in "$@"; do assigns[${#assigns[@]}]="SBT_$kv"; done
  # The pairs are exported in a subshell, so that awk is called by its plain name.
  (export "${assigns[@]}" && LC_ALL=C awk '
    {
      line = $0; out = ""; whole = 0; emptied = 0
      t = line; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
      if (substr(t, 1, 2) == "{{" && index(substr(t, 3), "}}") == length(t) - 3) whole = 1
      while ((i = index(line, "{{")) > 0) {
        j = index(substr(line, i + 2), "}}")
        if (j == 0) break
        name = substr(line, i + 2, j - 1)
        if (name ~ /^[A-Z][A-Z0-9_]*$/ && (("SBT_" name) in ENVIRON)) {
          val = ENVIRON["SBT_" name]
          if (val == "") emptied = 1
          out = out substr(line, 1, i - 1) val
          line = substr(line, i + j + 3)
        } else {
          out = out substr(line, 1, i + 1)
          line = substr(line, i + 2)
        }
      }
      if (whole && emptied) next
      print out line
    }
  ' "$tmpl")
}

# Fill a template into a new file. Returns 6 when the file exists; never overwrites.
sb_fill() {
  local name="$1" dest="$2" tmp
  shift 2
  if [ -e "$dest" ]; then return 6; fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/sb-fill.XXXXXX")" || return 1
  sb_fill_text "$name" "$@" >"$tmp" || { rm -f "$tmp"; exit 2; }
  if grep -q '{{' "$tmp"; then
    rm -f "$tmp"
    sb_die 5 "a placeholder was left unfilled in $name, or a value contains {{"
  fi
  mkdir -p "$(dirname "$dest")" || { rm -f "$tmp"; return 1; }
  cat "$tmp" >"$dest"
  rm -f "$tmp"
  return 0
}

# Insert text before or after the first line equal to a heading; keeps line endings.
# Modes: before, after, list (after, with no blank line before a following list item).
# Returns 1, and writes nothing, when the heading is absent.
sb_body_insert() {
  local file="$1" heading="$2" mode="$3" text="$4" tmp eofnl=1 rc=0
  [ -f "$file" ] || return 1
  if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then eofnl=0; fi
  tmp="$(mktemp "${TMPDIR:-/tmp}/sb-body.XXXXXX")" || return 1
  LC_ALL=C SB_H="$heading" SB_MODE="$mode" SB_TEXT="$text" SB_EOFNL="$eofnl" awk '
    function put(s) { printf "%s%s", sep, s; sep = "\n" }
    function puttext(   i) { for (i = 1; i <= nt; i++) put(tl[i] eol) }
    BEGIN {
      want = tolower(ENVIRON["SB_H"]); mode = ENVIRON["SB_MODE"]; eofnl = ENVIRON["SB_EOFNL"] + 0
      nt = split(ENVIRON["SB_TEXT"], tl, "\n"); sep = ""; done = 0; skipping = 0; eol = ""
    }
    {
      raw = $0; line = raw; sub(/\r$/, "", line)
      if (NR == 1 && raw != line) eol = "\r"
      if (skipping) {
        if (line ~ /^[ \t]*$/) next
        skipping = 0
        if (!(mode == "list" && line ~ /^[-*] /)) put(eol)
      }
      t = line; sub(/[ \t]+$/, "", t)
      if (!done && tolower(t) == want) {
        done = 1
        if (mode == "before") { puttext(); put(eol); put(raw); next }
        put(raw); put(eol); puttext(); skipping = 1; next
      }
      put(raw)
    }
    END { if (NR > 0 && (eofnl || skipping)) printf "\n"; exit(done ? 0 : 1) }
  ' "$file" >"$tmp" || rc=1
  if [ "$rc" -eq 0 ]; then cat "$tmp" >"$file"; fi
  rm -f "$tmp"
  return "$rc"
}

# Append text at the end of a file after one blank line; keeps line endings.
sb_body_append() {
  local file="$1" text="$2" tmp
  [ -f "$file" ] || return 1
  tmp="$(mktemp "${TMPDIR:-/tmp}/sb-body.XXXXXX")" || return 1
  LC_ALL=C SB_TEXT="$text" awk '
    BEGIN { nt = split(ENVIRON["SB_TEXT"], tl, "\n"); eol = ""; blank = 1 }
    {
      raw = $0; line = raw; sub(/\r$/, "", line)
      if (NR == 1 && raw != line) eol = "\r"
      blank = (line ~ /^[ \t]*$/)
      print raw
    }
    END {
      if (!blank) print eol
      for (i = 1; i <= nt; i++) print tl[i] eol
    }
  ' "$file" >"$tmp" || { rm -f "$tmp"; return 1; }
  cat "$tmp" >"$file"
  rm -f "$tmp"
  return 0
}

# Print the plugin version.
cmd_version() {
  local f
  f="$(sb_plugin_root)/.claude-plugin/plugin.json"
  [ -f "$f" ] || sb_die 1 "plugin.json not found"
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$f" | head -1
}

# Print the vault root.
cmd_root() {
  sb_need_root
  sb_path_out "$SB_ROOT"
}

# Print one level-2 section of the vault's conventions note; the short version by default.
cmd_conventions() {
  local section="$*" file
  [ -n "$section" ] || section="The short version"
  sb_need_root
  file="$SB_ROOT/obsidian-conventions.md"
  [ -f "$file" ] || sb_die 1 "no conventions note at obsidian-conventions.md (run: second-brain scaffold vault)"
  sb_section "$file" "$section" || sb_die 1 "no section \"## $section\" in obsidian-conventions.md"
}
