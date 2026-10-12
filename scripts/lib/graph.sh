#!/usr/bin/env bash
# graph.sh - the links between notes: headings, backlinks, unresolved links, move and rename.

# Print the awk functions that read a note's links and resolve them against the vault's files.
# Every awk that loads them runs with LC_ALL=C: paths and letter case are compared as bytes.
sb_graph_awk() {
  cat <<'AWK'
# Print the folder part of a path; nothing for a file at the vault root.
function folder(p) {
  if (sub(/\/[^\/]*$/, "", p) == 0) return ""
  return p
}
# Fold "." and ".." out of a path; "\001" when it climbs out of the vault or names a folder.
function fold(p,   q, n, i, m, seg, out) {
  q = "/" p "/"
  if (index(q, "/./") == 0 && index(q, "/../") == 0 && index(q, "//") == 0) return p
  if (substr(p, length(p)) == "/") return "\001"
  n = split(p, seg, "/"); m = 0
  for (i = 1; i <= n; i++) {
    if (seg[i] == "" || seg[i] == ".") continue
    if (seg[i] == "..") { if (m == 0) return "\001"; m--; continue }
    out[++m] = seg[i]
  }
  p = ""
  for (i = 1; i <= m; i++) p = p (i > 1 ? "/" : "") out[i]
  return p
}
# Add one file to a set: under its path, and under every tail of its path for the ends-with rule.
function addfile(set, p,   lp, s, d, i, k) {
  lp = tolower(p)
  k = set SUBSEP lp
  if (!(k in FILE) || p < FILE[k]) FILE[k] = p
  s = lp; d = 0
  while ((i = index(s, "/")) > 0) { s = substr(s, i + 1); d++ }
  NAMES[set, s]++
  s = lp
  while ((i = index(s, "/")) > 0) {
    s = substr(s, i + 1)
    k = set SUBSEP s
    if (!(k in TAIL) || d < DEPTH[k] || (d == DEPTH[k] && p < TAIL[k])) { TAIL[k] = p; DEPTH[k] = d }
  }
}
# Try one spelling of a target, in lower case, from a folder in lower case. RULE says how it was
# found: 1 the vault path, 2 the path from the note's folder, 3 the end of a path.
function lookup(set, t, dir,   a, b, c, name, own) {
  a = t; b = (dir == "" ? t : dir "/" t); own = 0
  if (index(t, "/") > 0) {
    if (substr(t, 1, 1) == "/") {
      sub(/^\/+/, "", t)
      a = fold(t)
      if ((set, a) in FILE) { RULE = 1; return FILE[set, a] }
      return ""
    }
    own = (substr(t, 1, 2) == "./" || substr(t, 1, 3) == "../")
    c = "/" t "/"
    if (index(c, "/./") > 0 || index(c, "/../") > 0 || index(c, "//") > 0) { a = fold(t); b = fold(b) }
  } else if (t == "." || t == "..") return ""
  if (!own && ((set, a) in FILE)) { RULE = 1; return FILE[set, a] }
  if ((set, b) in FILE) { RULE = 2; return FILE[set, b] }
  if (own || a == "\001") return ""
  if (index(a, "/") > 0) {
    name = a; sub(/^.*\//, "", name)
    c = (dir == "" ? "" : dir "/") name
    if (((set, c) in FILE) && length(c) > length(a) && substr(c, length(c) - length(a)) == "/" a) {
      RULE = 3; return FILE[set, c]
    }
  }
  if ((set, a) in TAIL) { RULE = 3; return TAIL[set, a] }
  return ""
}
# Resolve a target from a folder, given in lower case: as written, then with .md added.
# "" when no file answers.
function resolve(set, t, dir,   r) {
  RULE = 0
  t = tolower(t)
  r = lookup(set, t, dir)
  if (r == "") r = lookup(set, t ".md", dir)
  return r
}
# Print a run of spaces.
function blank(n) {
  while (length(BLANK) < n) BLANK = BLANK BLANK "        "
  return substr(BLANK, 1, n)
}
# Blank the inline code spans of a line; every other byte keeps its place.
function mask(s,   out, i, n, run, rest, off, j, k, hit) {
  out = ""
  while ((i = index(s, "`")) > 0) {
    n = 1
    while (substr(s, i + n, 1) == "`") n++
    run = substr(s, i, n); rest = substr(s, i + n); off = 0; hit = 0
    while ((j = index(rest, run)) > 0) {
      k = n
      while (substr(rest, j + k, 1) == "`") k++
      if (k == n) { hit = 1; break }
      off += j + k - 1; rest = substr(rest, j + k)
    }
    if (!hit) { out = out substr(s, 1, i + n - 1); s = substr(s, i + n); continue }
    k = n + off + j - 1 + n
    out = out substr(s, 1, i - 1) blank(k); s = substr(s, i + k)
  }
  return out s
}
# Return 1 when a line belongs to a fenced code block, its fences included. FENCE holds the state.
function fenced(line,   t, c, n) {
  if (FENCE == "" && index(line, "```") == 0 && index(line, "~~~") == 0) return 0
  t = line; sub(/^[ \t>]+/, "", t)
  c = substr(t, 1, 1); n = 0
  if (c == "`" || c == "~") { n = 1; while (substr(t, n + 1, 1) == c) n++ }
  if (FENCE == "") {
    if (n < 3 || (c == "`" && index(substr(t, n + 1), "`") > 0)) return 0
    FENCE = c; FLEN = n
    return 1
  }
  if (c == FENCE && n >= FLEN && substr(t, n + 1) ~ /^[ \t\r]*$/) FENCE = ""
  return 1
}
# Turn two hex digits into a number; 0 when they are not hex.
function hex2(x,   a, b) {
  a = index("0123456789abcdef", tolower(substr(x, 1, 1)))
  b = index("0123456789abcdef", tolower(substr(x, 2, 1)))
  return (length(x) == 2 && a && b) ? (a - 1) * 16 + b - 1 : 0
}
# Decode the percent-encoded bytes of a markdown target.
function unpct(s,   out, i, h) {
  out = ""
  while ((i = index(s, "%")) > 0) {
    h = hex2(substr(s, i + 1, 2))
    if (h == 0) { out = out substr(s, 1, i); s = substr(s, i + 1); continue }
    out = out substr(s, 1, i - 1) sprintf("%c", h); s = substr(s, i + 3)
  }
  return out s
}
# Percent-encode a path for a markdown target. how: 0 inside <>, 1 bare, 2 as an encoded link
# has it, 3 the same with the bytes above ASCII.
function pct(s, how,   out, i, n, c, esc) {
  if (how == 0 && s !~ /[<>#%]/) return s
  if (how == 1 && s !~ /[ \t()<>#%]/) return s
  if (!("%" in ORD)) for (i = 1; i < 256; i++) ORD[sprintf("%c", i)] = i
  out = ""; n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (how == 0) esc = (index("<>#%", c) > 0)
    else if (how == 1) esc = (index(" \t()<>#%", c) > 0)
    else esc = (c !~ /[A-Za-z0-9._~\/-]/ && (how == 3 || c < "\200"))
    out = out (esc ? sprintf("%%%02X", ORD[c]) : c)
  }
  return out
}
# Print the path that leads from a folder to a file.
function relpath(dir, w,   a, b, na, nb, i, j, out) {
  na = (dir == "" ? 0 : split(dir, a, "/")); nb = split(w, b, "/")
  i = 1
  while (i <= na && i < nb && (a[i] "") == (b[i] "")) i++
  out = ""
  for (j = i; j <= na; j++) out = out "../"
  for (j = i; j <= nb; j++) out = out b[j] (j < nb ? "/" : "")
  return out
}
# Record one wikilink: o is the line, a the place of "[[" and e the place of the last "]".
function addwiki(o, a, e,   inner, bar, h, t, lead, k) {
  inner = substr(o, a + 2, e - a - 3)
  bar = index(inner, "|")
  if (bar) {
    inner = substr(inner, 1, bar - 1)
    if (substr(inner, length(inner)) == "\\") inner = substr(inner, 1, length(inner) - 1)
  }
  h = index(inner, "#")
  if (h) inner = substr(inner, 1, h - 1)
  t = inner; sub(/^[ \t]+/, "", t); lead = length(inner) - length(t)
  sub(/[ \t]+$/, "", t)
  if (t == "") return
  k = ++NLK
  LS[k] = (a > 1 && substr(o, a - 1, 1) == "!" ? a - 1 : a); LE[k] = e
  TS[k] = a + 2 + lead; TL[k] = length(t); LT[k] = t
  LK[k] = "w"; LA[k] = 0; LP[k] = 0
}
# Find the links of one line and return how many. Per link: LS and LE are where the link as
# written starts and ends, TS and TL its target, LT the target to resolve, LK "w" for a wikilink
# or "m" for a markdown link, LA inside <>, LP percent-encoded (2 with bytes above ASCII).
# LX lists the links in reading order. A substring goes into a variable before match() reads it:
# one awk loses RSTART when the two calls are nested.
function scan(o,   s, len, rest, off, i, j, nw, p, k, m, a, c, depth, q, r, ds, dl, d, ang, h, e, inside, part) {
  NLK = 0
  if (index(o, "[[") == 0 && index(o, "](") == 0) return 0
  s = (index(o, "`") > 0 ? mask(o) : o); len = length(s)
  rest = s; off = 0
  while ((i = index(rest, "[[")) > 0) {
    j = index(substr(rest, i + 2), "]]")
    if (j == 0) break
    # a bracket in the target means the link opens further on
    d = substr(rest, i + 2, j - 1); h = index(d, "|")
    if (index((h ? substr(d, 1, h - 1) : d), "[") > 0) { off += i; rest = substr(rest, i + 1); continue }
    addwiki(o, off + i, off + i + j + 2)
    off += i + j + 2; rest = substr(rest, i + j + 3)
  }
  nw = NLK
  rest = s; off = 0
  while ((i = index(rest, "](")) > 0) {
    p = off + i
    off += i + 1; rest = substr(rest, i + 2)
    inside = 0
    for (k = 1; k <= nw; k++) if (p >= LS[k] && p <= LE[k]) inside = 1
    if (inside) continue
    # the text opens at the last "[" when it holds no bracket, else at the one that pairs
    part = substr(s, 1, p - 1)
    if (match(part, /\[[^][]*$/)) a = RSTART
    else {
      depth = 0
      for (a = p - 1; a >= 1; a--) {
        c = substr(s, a, 1)
        if (c == "]") depth++
        else if (c == "[") { if (depth == 0) break; depth-- }
      }
      if (a < 1) continue
    }
    q = p + 2; ang = 0
    if (substr(s, q, 1) == "<") {
      j = index(substr(s, q + 1), ">")
      if (j == 0) continue
      ds = q + 1; dl = j - 1; r = q + j + 1; ang = 1
    } else {
      # the target ends at a space or at the ")" that closes it; it may hold paired parentheses
      part = substr(s, q)
      match(part, /^[^ \t()]*/)
      r = q + RLENGTH; depth = 0
      for (; r <= len; r++) {
        c = substr(s, r, 1)
        if (c == "(") depth++
        else if (c == ")") { if (depth == 0) break; depth-- }
        else if (c == " " || c == "\t") break
      }
      if (r > len) continue
      ds = q; dl = r - q
    }
    part = substr(s, r)
    if (!match(part, /^[ \t]*("[^"]*"|\047[^\047]*\047|\([^)]*\))?[ \t]*\)/)) continue
    e = r + RLENGTH - 1
    d = substr(o, ds, dl)
    h = index(d, "#")
    if (h) d = substr(d, 1, h - 1)
    if (d == "" || d ~ /^[A-Za-z][A-Za-z0-9+.-]*:/ || substr(d, 1, 2) == "//") continue
    k = ++NLK
    LS[k] = (a > 1 && substr(o, a - 1, 1) == "!" ? a - 1 : a); LE[k] = e
    TS[k] = ds; TL[k] = length(d)
    LP[k] = (d ~ /%[0-9A-Fa-f][0-9A-Fa-f]/ ? (d ~ /%[89A-Fa-f][0-9A-Fa-f]/ ? 2 : 1) : 0)
    LT[k] = (LP[k] ? unpct(d) : d)
    LK[k] = "m"; LA[k] = ang
  }
  for (k = 1; k <= NLK; k++) {
    for (m = k; m > 1 && LS[LX[m - 1]] > LS[k]; m--) LX[m] = LX[m - 1]
    LX[m] = k
  }
  return NLK
}
# Read a whole file as one string, line endings and all. RS must be "\001" by now. PIECES says
# in how many records it came, one when awk kept every byte, and UNREAD is 1 when it did not open.
function slurp(p,   f, rec, out, rc) {
  f = "./" p; out = ""; PIECES = 0
  while ((rc = (getline rec < f)) > 0) out = (PIECES++ ? out "\001" rec : rec)
  close(f)
  UNREAD = (rc < 0)
  return out ""
}
# Return 1 when a character can be part of a file name: a letter, a digit, one of _ . / - or a
# byte above ASCII.
function inname(c) {
  return (c ~ /[A-Za-z0-9_.\/-]/ || c > "\177")
}
# Return 1 when a text names a vault path as a whole path, not as a part of a longer one. The
# path of a folder may go on with a slash: the third argument says that it is one.
function mentions(text, path, dir,   i, before, after) {
  before = ""
  while ((i = index(text, path)) > 0) {
    if (i > 1) before = substr(text, i - 1, 1)
    after = substr(text, i + length(path), 1)
    if (!inname(before) && (!inname(after) || (dir && after == "/"))) return 1
    before = substr(text, i, 1); text = substr(text, i + 1)
  }
  return 0
}
AWK
}

# Set SB_GRAPH_PATH to a vault path with "." folded out; exit 5 when it holds a backslash, leaves
# the vault or enters a dot folder. The vault root comes out empty. A vault path has forward
# slashes on every system; on Windows a drive letter opens an absolute path, which is not one.
sb_graph_path() {
  local rest="$1" out="" seg
  case "$rest" in
    /*) sb_die 5 "not a vault path, give it from the vault root: $1" ;;
    *\\*) sb_die 5 "not a vault path, give it from the vault root with forward slashes: $1" ;;
  esac
  if sb_is_windows; then
    case "$rest" in [A-Za-z]:*) sb_die 5 "not a vault path, give it from the vault root with forward slashes: $1" ;; esac
  fi
  while [ -n "$rest" ]; do
    seg="${rest%%/*}"
    case "$rest" in */*) rest="${rest#*/}" ;; *) rest="" ;; esac
    case "$seg" in
      '' | .) ;;
      ..) sb_die 5 "the path leaves the vault: $1" ;;
      .*) sb_die 5 "the path enters a dot folder: $1" ;;
      *) out="${out:+$out/}$seg" ;;
    esac
  done
  SB_GRAPH_PATH="$out"
}

# Exit 5 when a link could not spell a vault path: a segment of it holds one of # ^ | [ ] or a
# backslash, a control character such as a tab or a line break, or starts or ends with a blank.
# A note's name ends before its .md, which a link may leave out.
sb_graph_spell() {
  local rest="$1" seg
  while [ -n "$rest" ]; do
    seg="${rest%%/*}"
    case "$rest" in */*) rest="${rest#*/}" ;; *) rest="" ;; esac
    case "$seg" in
      *'#'* | *'^'* | *'|'* | *'['* | *']'* | *\\* | *[[:cntrl:]]*)
        sb_die 5 "no link can spell a name that holds # ^ | [ ] a backslash or a control character: $1"
        ;;
      ' '* | *' ' | *' '.[mM][dD])
        sb_die 5 "no link can spell a name that starts or ends with a blank: $1"
        ;;
    esac
  done
}

# Exit 5 when a vault path lies behind a symlink, which the helper does not follow. The folders
# on the way are looked at, and the path itself when a second argument is given.
sb_graph_nolink() {
  local rest="$1" at="" seg
  while [ -n "$rest" ]; do
    seg="${rest%%/*}"
    case "$rest" in */*) rest="${rest#*/}" ;; *) rest="" ;; esac
    at="${at:+$at/}$seg"
    if [ -n "$rest" ] || [ -n "${2:-}" ]; then
      [ ! -L "$SB_ROOT/$at" ] || sb_die 5 "$at is a symlink, and the helper does not look behind one: $1"
    fi
  done
}

# Read the vault's file list and its notes in one awk pass. Modes: unresolved [folder],
# backlinks <path>, move <from> <to> <plan file> <exact> <folder>. Move prints the "links:" lines
# and names on stderr the canvas and base files left to edit. For each note to rewrite it writes
# to the plan a row "N<TAB>bytes read<TAB>records read<TAB>old path<TAB>new path", then one row
# "L<TAB>line<TAB>new text" per changed line. It fails when a note or a folder cannot be read.
sb_graph_scan() {
  (
    cd "$SB_ROOT" || exit 1
    # A folder that find cannot open hides its notes: for a move that is a failure too.
    [ "$1" != "move" ] || set -o pipefail
    find . -type d -name '.?*' -prune -o -type f -print | LC_ALL=C sort |
      LC_ALL=C SB_MODE="$1" SB_A1="${2:-}" SB_A2="${3:-}" SB_PLAN="${4:-}" SB_EXACT="${5:-}" SB_DIR="${6:-}" awk "$(sb_graph_awk)"'
      # Print where a file is after the move.
      function newof(p,   lp) {
        lp = (exact ? p : tolower(p))
        if (lp == from) return a2
        if (substr(lp, 1, n1 + 1) == from "/") return a2 substr(p, n1 + 1)
        return p
      }
      # Print a target without its .md when the link it replaces had none.
      function bare(k, t) {
        if (tolower(t) ~ /\.md$/ && tolower(LT[k]) !~ /\.md$/) return substr(t, 1, length(t) - 3)
        return t
      }
      # Build the target that leads link k to file w from a note in folder dir, in the form it had.
      function retarget(k, w, dir, rule,   ldir, t, name, lead, how) {
        ldir = tolower(dir)
        if (LK[k] == "w") {
          name = w; sub(/^.*\//, "", name)
          if (index(LT[k], "/") == 0 && NAMES["n", tolower(name)] == 1) {
            t = bare(k, name)
            if (resolve("n", t, ldir) == w) return t
          }
          t = bare(k, w)
          return (resolve("n", t, ldir) == w ? t : w)
        }
        how = (LP[k] ? LP[k] + 1 : (LA[k] ? 0 : 1))
        if (rule == 2) {
          t = relpath(dir, w)
          lead = (substr(LT[k], 1, 2) == "./" && substr(t, 1, 3) != "../" ? "./" : "")
          if (resolve("n", lead bare(k, t), ldir) == w) return pct(lead bare(k, t), how)
          if (resolve("n", lead t, ldir) == w) return pct(lead t, how)
          return pct((substr(t, 1, 3) == "../" ? "" : "./") t, how)
        }
        lead = (substr(LT[k], 1, 1) == "/" ? "/" : "")
        t = bare(k, w)
        return pct(lead (resolve("n", lead t, ldir) == w ? t : w), how)
      }
      # Read one note and act on each of its links.
      function note(i,   p, dir, np, ndir, lndir, text, pieces, cr, nl, ln, line, body, n, x, k, r, rule, w, t, did, cnt, m, last) {
        p = F[i]; dir = tolower(folder(p))
        if (mode == "move") { np = N[i]; ndir = folder(np); lndir = tolower(ndir) }
        text = slurp(p); pieces = PIECES
        if (UNREAD) {
          # a move that cannot see a note would leave its links behind
          if (mode == "move") { print "note: " p " cannot be read" >"/dev/stderr"; unread++ }
          return
        }
        cr = index(text, "\r"); nl = split(text, L, "\n")
        line = L[1]; sub(/\r$/, "", line); sub(/^\357\273\277/, "", line)
        body = (line != "---"); FENCE = ""; cnt = 0
        for (ln = (body ? 1 : 2); ln <= nl; ln++) {
          line = L[ln]
          if (body) {
            if ((FENCE != "" || index(line, "```") > 0 || index(line, "~~~") > 0) && fenced(line)) continue
            if (index(line, "[") == 0) continue
            if (cr) sub(/\r$/, "", line)
          } else {
            if (cr) sub(/\r$/, "", line)
            if (line == "---") { body = 1; continue }
          }
          n = scan(line); did = 0
          for (x = 1; x <= n; x++) {
            k = LX[x]; NEW[k] = ""
            r = resolve("o", LT[k], dir); rule = RULE
            if (mode == "unresolved") {
              if (r == "") print p ":" ln ": " substr(line, LS[k], LE[k] - LS[k] + 1)
            } else if (mode == "backlinks") {
              if (r != "" && tolower(r) == from) print p ":" ln ": " substr(line, LS[k], LE[k] - LS[k] + 1)
            } else if (r != "") {
              w = newof(r)
              if (resolve("n", LT[k], lndir) == w) continue
              t = retarget(k, w, ndir, rule)
              if (LK[k] == "w" && (index(t, "#") || index(t, "|") || index(t, "[") || index(t, "]") || t ~ /^[ \t]/ || t ~ /[ \t]$/)) {
                # written out, this target would be read as another one
                print "note: " p ":" ln " would need a link to " w ", a path no wikilink can spell" >"/dev/stderr"
                unspelled++
                continue
              }
              if (t != substr(line, TS[k], TL[k])) { NEW[k] = t; did++ }
            }
          }
          if (!did) continue
          for (m = 1; m <= did; m++) {
            last = 0
            for (k = 1; k <= n; k++) if (NEW[k] != "" && (!last || TS[k] > TS[last])) last = k
            line = substr(line, 1, TS[last] - 1) NEW[last] substr(line, TS[last] + TL[last])
            NEW[last] = ""
          }
          if (!cnt) print "N\t" length(text) "\t" pieces "\t" p "\t" np >plan
          print "L\t" ln "\t" line >plan
          cnt += did
        }
        if (cnt) print "links: " np " | " cnt
      }
      BEGIN {
        mode = ENVIRON["SB_MODE"]; a1 = ENVIRON["SB_A1"] ""; a2 = ENVIRON["SB_A2"] ""; plan = ENVIRON["SB_PLAN"]
        # a move names its files as they are spelled, unless the file system finds them in any case
        exact = (mode == "move" && ENVIRON["SB_EXACT"] == "1")
        from = (exact ? a1 : tolower(a1)); n1 = length(a1); nf = 0
      }
      { p = $0; sub(/^\.\//, "", p); if (p != "") F[++nf] = p }
      END {
        for (i = 1; i <= nf; i++) addfile("o", F[i])
        if (mode == "move") for (i = 1; i <= nf; i++) { N[i] = newof(F[i]); addfile("n", N[i]) }
        RS = "\001"
        for (i = 1; i <= nf; i++) {
          lp = tolower(F[i])
          if (lp ~ /\.md$/) {
            if (mode != "unresolved" || a1 == "" || substr(lp, 1, n1 + 1) == from "/") note(i)
          } else if (mode == "move" && lp ~ /\.(canvas|base)$/ && mentions(tolower(slurp(F[i])), tolower(a1), ENVIRON["SB_DIR"] == "1")) {
            print "note: " N[i] " mentions " a1 >"/dev/stderr"
          }
        }
        if (unread) exit 3
        if (unspelled) exit 4
      }'
  )
}

# Print the unresolved rows, "path:line: <link as written>", for the vault or for one vault folder.
sb_graph_unresolved() {
  sb_need_root
  sb_graph_scan unresolved "${1:-}"
}

# Print the notes of a plan that awk did not read whole: one that came in several records, or
# whose byte count differs from the file's. One wc call counts them all.
sb_graph_partial() {
  (
    cd "$SB_ROOT" || exit 1
    LC_ALL=C awk -F'\t' '$1 == "N" { print "./" $4 }' "$1" | tr '\n' '\0' | xargs -0 wc -c 2>/dev/null |
      LC_ALL=C awk -F'\t' '
        FNR == NR { if ($1 == "N") { name = "./" $4; order[++n] = name; want[name] = $2 + 0; pieces[name] = $3 + 0 } next }
        {
          line = $0; sub(/^[ \t]+/, "", line)
          i = index(line, " "); name = substr(line, i + 1)
          if (name in want) got[name] = substr(line, 1, i - 1) + 0
        }
        END {
          for (k = 1; k <= n; k++) {
            name = order[k]
            if (!(name in got) || got[name] != want[name] || pieces[name] != 1) print substr(name, 3)
          }
        }' "$1" -
  )
}

# Put the changed lines of a plan in place, one note after another, and keep every other byte.
# A note is read back once it is written. When awk stops on a note, the notes after it are still
# done. Sets SB_GRAPH_LEFT to the notes that still hold an old link, one per line; returns 1
# when a note is left.
sb_graph_apply() {
  local plan="$1" total="$2" skip=0 out kind path trying nl=$'\n'
  SB_GRAPH_LEFT=""
  while [ "$skip" -lt "$total" ]; do
    out="$(cd "$SB_ROOT" && LC_ALL=C SB_SKIP="$skip" awk "$(sb_graph_awk)"'
      {
        i = index($0, "\t"); rest = substr($0, i + 1); j = index(rest, "\t")
        if (substr($0, 1, i - 1) == "N") { n++; P[n] = $0; sub(/^N\t[^\t]*\t[^\t]*\t[^\t]*\t/, "", P[n]); FIRST[n] = ne + 1; LAST[n] = ne }
        else { ne++; LN[ne] = substr(rest, 1, j - 1) + 0; T[ne] = substr(rest, j + 1); LAST[n] = ne }
      }
      END {
        RS = "\001"
        for (k = ENVIRON["SB_SKIP"] + 1; k <= n; k++) {
          print "T\t" P[k]; fflush()
          nl = split(slurp(P[k]), L, "\n")
          ok = (!UNREAD && nl > 0)
          for (e = FIRST[k]; e <= LAST[k] && ok; e++) {
            if (LN[e] > nl) ok = 0
            else L[LN[e]] = T[e] (L[LN[e]] ~ /\r$/ ? "\r" : "")
          }
          if (ok) {
            f = "./" P[k]
            for (m = 1; m <= nl; m++) printf "%s%s", L[m], (m < nl ? "\n" : "") >f
            close(f)
            ok = (split(slurp(P[k]), B, "\n") == nl && !UNREAD)
            for (m = 1; m <= nl && ok; m++) ok = ((B[m] "") == (L[m] ""))
          }
          print (ok ? "K" : "F") "\t" P[k]; fflush()
        }
      }' "$plan" 2>/dev/null)"
    trying=""
    [ -n "$out" ] || break
    while IFS=$'\t' read -r kind path; do
      case "$kind" in
        T) trying="$path" ;;
        K)
          skip=$((skip + 1))
          trying=""
          ;;
        F)
          skip=$((skip + 1))
          trying=""
          SB_GRAPH_LEFT="$SB_GRAPH_LEFT$path$nl"
          ;;
      esac
    done <<EOF
$out
EOF
    [ -n "$trying" ] || break
    SB_GRAPH_LEFT="$SB_GRAPH_LEFT$trying$nl"
    skip=$((skip + 1))
  done
  [ "$skip" -ge "$total" ] && [ -z "$SB_GRAPH_LEFT" ]
}

# Move a file or a folder to a vault path that is free, and rewrite the links; third argument 1
# for a dry run. Everything that can refuse the move is looked at before a file is touched.
sb_graph_move() {
  local from="$1" dest="$2" dry="$3" plan links why alt exact=1 isdir=0 kind bytes pieces old rest
  local total=0 stuck="" partial made="" d line p rc nl=$'\n'
  [ -e "$SB_ROOT/$from" ] || sb_die 1 "nothing at $from"
  [ ! -d "$SB_ROOT/$from" ] || isdir=1
  # The index, the conventions note and a profile are found at a fixed path: they stay there.
  why="$(sb_projects_tsv 2>/dev/null | LC_ALL=C SB_F="$from" awk -F'\t' '
    function fixed(path, what) {
      path = tolower(path)
      if (why != "") return
      if (path == f) why = "it is " what
      else if (substr(path, 1, n + 1) == f "/") why = "it holds " what
    }
    BEGIN {
      f = tolower(ENVIRON["SB_F"]); n = length(f)
      fixed("CLAUDE.md", "the index of the vault"); fixed("obsidian-conventions.md", "the conventions note")
    }
    $2 != "" { fixed($2 "/claude/profile.md", "the profile of the project " $1) }
    END { print why }')"
  [ -z "$why" ] || sb_die 5 "$from is not moved by this command: $why, which the helper finds at a fixed path"
  if [ -e "$SB_ROOT/$dest" ] || [ -L "$SB_ROOT/$dest" ]; then sb_die 6 "the destination exists: $dest"; fi
  case "$dest/" in "$from"/*) sb_die 5 "a folder cannot move into itself: $from" ;; esac
  # A file system that ignores letter case finds the typed path in any case; one that minds it does not.
  alt="$(printf '%s' "$from" | LC_ALL=C tr 'a-zA-Z' 'A-Za-z')"
  if [ "$alt" != "$from" ] && [ "$SB_ROOT/$alt" -ef "$SB_ROOT/$from" ]; then exact=0; fi
  plan="$(mktemp "${TMPDIR:-/tmp}/sb-graph.XXXXXX")" || sb_die 1 "cannot create a temp file"
  links="$(sb_graph_scan move "$from" "$dest" "$plan" "$exact" "$isdir")" || {
    rc=$?
    rm -f "$plan"
    [ "$rc" -ne 4 ] || sb_die 1 "a link would have to name a path that no wikilink can spell; nothing was moved"
    sb_die 1 "not every note of the vault could be read, so a link could be missed; nothing was moved"
  }
  # A note is rewritten only when awk read every byte of it and the file can be written.
  while IFS=$'\t' read -r kind bytes pieces old rest; do
    [ "$kind" = "N" ] || continue
    total=$((total + 1))
    [ -w "$SB_ROOT/$old" ] || stuck="$stuck$old$nl"
  done <"$plan"
  partial=""
  [ "$total" -eq 0 ] || partial="$(sb_graph_partial "$plan")"
  if [ -n "$partial$stuck" ]; then
    rm -f "$plan"
    while IFS= read -r p; do
      [ -z "$p" ] || sb_note "$p holds bytes that awk does not read back whole, so its links cannot be rewritten"
    done <<EOF
$partial
EOF
    while IFS= read -r p; do
      [ -z "$p" ] || sb_note "$p cannot be written, so its links cannot be rewritten"
    done <<EOF
$stuck
EOF
    sb_die 1 "a note with a link to rewrite cannot be rewritten safely; nothing was moved"
  fi
  if [ "$dry" -eq 1 ]; then
    rm -f "$plan"
    printf 'dry run\nmoved: %s -> %s\n' "$from" "$dest"
    [ -z "$links" ] || printf '%s\n' "$links"
    return 0
  fi
  # The vault was read since the destination was looked at: look again, and never overwrite.
  if [ -e "$SB_ROOT/$dest" ] || [ -L "$SB_ROOT/$dest" ]; then
    rm -f "$plan"
    sb_die 6 "the destination exists: $dest"
  fi
  d="$dest"
  while :; do
    case "$d" in */*) d="${d%/*}" ;; *) break ;; esac
    [ ! -d "$SB_ROOT/$d" ] || break
    made="$made$d$nl"
  done
  [ -z "$made" ] || mkdir -p "$SB_ROOT/${dest%/*}"
  mv -n "$SB_ROOT/$from" "$SB_ROOT/$dest"
  if [ -e "$SB_ROOT/$from" ] || [ -L "$SB_ROOT/$from" ] || { [ ! -e "$SB_ROOT/$dest" ] && [ ! -L "$SB_ROOT/$dest" ]; }; then
    rm -f "$plan"
    # Take back the folders made for the move, the deepest first.
    while IFS= read -r d; do
      [ -z "$d" ] || rmdir "$SB_ROOT/$d" 2>/dev/null
    done <<EOF
$made
EOF
    if [ -e "$SB_ROOT/$dest" ] || [ -L "$SB_ROOT/$dest" ]; then sb_die 6 "the destination exists: $dest; nothing was changed"; fi
    sb_die 1 "cannot move $from to $dest; nothing was changed"
  fi
  if [ "$total" -gt 0 ] && ! sb_graph_apply "$plan" "$total"; then
    rm -f "$plan"
    printf 'moved: %s -> %s\n' "$from" "$dest"
    while IFS= read -r line; do
      p="${line#links: }"
      case "$nl$SB_GRAPH_LEFT" in *"$nl${p% | *}$nl"*) continue ;; esac
      [ -z "$line" ] || printf '%s\n' "$line"
    done <<EOF
$links
EOF
    while IFS= read -r p; do
      [ -z "$p" ] || sb_note "$p still holds an old link"
    done <<EOF
$SB_GRAPH_LEFT
EOF
    sb_die 1 "moved $from to $dest, but not every note could be rewritten; second-brain unresolved lists the links that are left"
  fi
  rm -f "$plan"
  printf 'moved: %s -> %s\n' "$from" "$dest"
  [ -z "$links" ] || printf '%s\n' "$links"
}

# Print one row per heading of a note: "<line>: <hashes> <heading>".
cmd_outline() {
  [ $# -eq 1 ] || sb_die 5 "usage: second-brain outline <path>"
  sb_need_root
  sb_graph_path "$1"
  if [ -z "$SB_GRAPH_PATH" ] || [ ! -f "$SB_ROOT/$SB_GRAPH_PATH" ]; then sb_die 1 "no note at $1"; fi
  LC_ALL=C awk "$(sb_graph_awk)"'
    { line = $0; sub(/\r$/, "", line) }
    NR == 1 { sub(/^\357\273\277/, "", line); if (line == "---") { front = 1; next } }
    front { if (line == "---") front = 0; next }
    fenced(line) { next }
    line ~ /^#+ / {
      match(line, /^#+/)
      if (RLENGTH > 6) next
      h = substr(line, RLENGTH + 1); sub(/^[ \t]+/, "", h); sub(/[ \t]+$/, "", h)
      print NR ": " substr(line, 1, RLENGTH) (h == "" ? "" : " " h)
    }' "$SB_ROOT/$SB_GRAPH_PATH"
}

# Print the links, from every note of the vault, that resolve to one file.
cmd_backlinks() {
  [ $# -eq 1 ] || sb_die 5 "usage: second-brain backlinks <path>"
  sb_need_root
  sb_graph_path "$1"
  if [ -z "$SB_GRAPH_PATH" ] || [ ! -f "$SB_ROOT/$SB_GRAPH_PATH" ]; then sb_die 1 "no note at $1"; fi
  sb_graph_scan backlinks "$SB_GRAPH_PATH"
}

# Print the links that resolve to no file, in the vault or in the notes under one project.
cmd_unresolved() {
  [ $# -le 1 ] || sb_die 5 "usage: second-brain unresolved [project]"
  if [ $# -eq 0 ]; then
    sb_graph_unresolved
    return $?
  fi
  case "$1" in *\\*) sb_die 5 "a project is named, or given by its vault path with forward slashes: $1" ;; esac
  sb_need_project "$1"
  sb_graph_unresolved "$SB_P_PATH"
}

# Move a note, another file or a folder inside the vault, and rewrite the links.
cmd_move() {
  local from="" to="" dry=0 dest
  local usage="usage: second-brain move <from> <to> [--dry-run]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) dry=1 ;;
      -*) sb_die 5 "$usage" ;;
      *)
        if [ -z "$from" ]; then
          from="$1"
        elif [ -z "$to" ]; then
          to="$1"
        else
          sb_die 5 "$usage"
        fi
        ;;
    esac
    shift
  done
  if [ -z "$from" ] || [ -z "$to" ]; then sb_die 5 "$usage"; fi
  sb_need_root
  sb_graph_path "$from"
  from="$SB_GRAPH_PATH"
  [ -n "$from" ] || sb_die 5 "the vault root cannot be moved"
  sb_graph_path "$to"
  dest="$SB_GRAPH_PATH"
  # An existing folder, or a path that ends with a slash, takes the item under its own name.
  case "$to" in
    */) dest="${dest:+$dest/}${from##*/}" ;;
    *) [ ! -d "$SB_ROOT/$dest" ] || dest="${dest:+$dest/}${from##*/}" ;;
  esac
  sb_graph_spell "$dest"
  sb_graph_nolink "$from" itself
  sb_graph_nolink "$dest"
  sb_graph_move "$from" "$dest" "$dry"
}

# Give a note, another file or a folder a new name in its folder, and rewrite the links.
cmd_rename() {
  local path="" name="" dry=0 dest base ext
  local usage="usage: second-brain rename <path> <name> [--dry-run]"
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) dry=1 ;;
      -*) sb_die 5 "$usage" ;;
      *)
        if [ -z "$path" ]; then
          path="$1"
        elif [ -z "$name" ]; then
          name="$1"
        else
          sb_die 5 "$usage"
        fi
        ;;
    esac
    shift
  done
  if [ -z "$path" ] || [ -z "$name" ]; then sb_die 5 "$usage"; fi
  case "$name" in */*) sb_die 5 "a name holds no slash: $name (move takes a path)" ;; esac
  sb_need_root
  sb_graph_path "$name"
  [ -n "$SB_GRAPH_PATH" ] || sb_die 5 "$usage"
  sb_graph_path "$path"
  path="$SB_GRAPH_PATH"
  [ -n "$path" ] || sb_die 5 "the vault root cannot be renamed"
  # A file keeps its extension: the name may repeat it, in any letter case, or leave it out.
  base="${path##*/}"
  if [ -f "$SB_ROOT/$path" ]; then
    case "$base" in
      *.*)
        ext="${base##*.}"
        shopt -s nocasematch
        case "$name" in *".$ext") name="${name%.*}" ;; esac
        shopt -u nocasematch
        name="$name.$ext"
        ;;
    esac
  fi
  dest="$name"
  case "$path" in */*) dest="${path%/*}/$name" ;; esac
  sb_graph_spell "$dest"
  sb_graph_nolink "$path" itself
  sb_graph_move "$path" "$dest" "$dry"
}
