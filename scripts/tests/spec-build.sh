#!/usr/bin/env bash
# Area spec-build: the state of a spec build, spec status and spec issue, the packet built from
# it, and the --json forms of spec and validation.
# Usage: bash scripts/test.sh spec-build, or bash scripts/tests/spec-build.sh
. "$(dirname "$0")/lib.sh"

# The project Specs, its validation.md, RepoHome and the stories SP-2 to SP-6, as spec.sh
# leaves them.
sb scaffold vault
S="work/specs"
SPF="$vault/$S/claude/profile.md"
SPS="$vault/$S/claude/subprojects/infra.md"
VN="$vault/$S/claude/validation.md"
mkdir -p "$tmp/scode/spec-app" "$tmp/scode/spec-web"
sb scaffold project Specs --path "$S" --keys SP
edit "$SPF" "s|^repos: \\[\\]\$|repos: [spec-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/scode\"|"
sb scaffold subproject Specs infra --repos spec-infra
edit "$SPS" 's/^spec_home: ""$/spec_home: vault/; s/^delivery: ""$/delivery: spec/'
sb validation new Specs spec-app
echo "- npm test" >>"$VN"
edit "$SPS" 's/^validation_home: ""$/validation_home: repo/'
edit "$SPF" 's|^repos: \[spec-app\]$|repos: [spec-app, spec-web]|'
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$VN" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$VN"
sb validation new Specs spec-web
printf '\r\n## spec-gone\r\n' >>"$VN"
edit "$SPF" 's|^repos: \[spec-app, spec-web\]$|repos: [spec-app]|'
P4="work/repohome"
mkdir -p "$vault/$P4/claude"
printf -- '---\ntype: profile\nvalidation_home: repo\n---\n' >"$vault/$P4/claude/profile.md"
sb scaffold project RepoHome --path "$P4" --keys RH
for n in 2 3 4 5; do sb task new "SP-$n" --project Specs --title "Linked $n"; done
for n in 2 3 5; do sb task set "SP-$n" delivery=spec; sb spec new "SP-$n"; done
L2="$vault/$S/tasks/SP-2/README.md"
sb spec link SP-2
L3="$vault/$S/tasks/SP-3/README.md"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$L3" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$L3"
sb spec link SP-3
L5="$vault/$S/tasks/SP-5/README.md"
awk '{ print } /^## Approach \/ Key decisions$/ { getline; print; getline; print "- Keep this decision."; next }' "$L5" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$L5"
sb spec link SP-5
rm "$vault/$S/tasks/SP-5/spec/design.md"
edit "$SPF" 's/^spec_home: vault$/spec_home: repo/'
sb task new SP-6 --project Specs --title "Repo link"
sb task set SP-6 delivery=spec
sb spec new SP-6
sb spec link SP-6
edit "$SPF" 's/^spec_home: repo$/spec_home: vault/'

# ---------------------------------------------------------------- spec status and spec issue
sb help
out_has "help: lists spec status and spec issue" 'spec status <ID> [<task> <state> [--commit H]] | spec issue <ID> <task> "<issue>" --fix "<fix>"'
B2="$vault/$S/tasks/SP-2/build.json"
cp "$L2" "$tmp/sp2.readme"
sb spec status SP-2
rc_is "spec status: a story with no build exits 0" 0
out_is "spec status: and prints nothing" ""
absent "spec status: reading writes no build.json" "$B2"
SECOND_BRAIN_NOW="2026-10-08T09:30:00-05:00" sb spec status SP-2 t1 building --session s-1
rc_is "spec status: exit 0" 0
out_is "spec status: names the task and its state" "T1: building"
exists "spec status: build.json is in the task folder" "$B2"
if cmp -s "$L2" "$tmp/sp2.readme"; then pass "spec status: the README is byte-identical, no note and no section"; else fail "spec status: the README is byte-identical, no note and no section"; fi
OUT="$(cat "$B2")"
json_ok "spec status: build.json parses as JSON"
json_is "spec status: build.json names the story and the task" \
  'print(d["story"], d["tasks"][0]["id"], d["tasks"][0]["title"])' "SP-2 T1 <What the task builds.>"
json_is "spec status: the build state is set, the review not yet" \
  't = d["tasks"][0]; print(t["build"], t["review"], t["commits"], t["issues"])' "building - [] []"
json_is "spec status: the history holds the state, its time and session" \
  'print(d["tasks"][0]["history"])' \
  "[{'at': '2026-10-08T09:30:00-05:00', 'session': 's-1', 'field': 'build', 'state': 'building'}]"
sb spec status SP-2 T1 built --commit abc1234
sb spec status SP-2
out_is "spec status: one line per task, its build and review" 'T1 - build: built - review: - - fails 0 - commits abc1234 - fix - - <What the task builds.>'
sb spec status SP-2 T1 in-review
sb spec status SP-2 T1 failed --commit def5678
sb spec status SP-2 T1 built --commit abc1234
sb spec status SP-2
out_is "spec status: a review state goes in the review field, a second commit once" \
  'T1 - build: built - review: failed - fails 1 - commits abc1234, def5678 - fix abc1234 - <What the task builds.>'
sb spec issue SP-2 T1 "The form has one field." --fix "Add the password field." --session s-2
rc_is "spec issue: exit 0" 0
out_is "spec issue: names the task" "T1: issue"
sb spec status SP-2
out_is "spec issue: the issue sits under its task, with its fix" \
  'T1 - build: built - review: failed - fails 1 - commits abc1234, def5678 - fix abc1234 - <What the task builds.>
  - Issue 2026-10-08: The form has one field. Fix: Add the password field.'
OUT="$(cat "$B2")"
json_is "spec issue: build.json holds the issue, its fix, time and session" 'print(d["tasks"][0]["issues"])' \
  "[{'at': '2026-10-08T00:00:00+00:00', 'session': 's-2', 'issue': 'The form has one field.', 'fix': 'Add the password field.', 'round': 1}]"
json_is "spec status: every state set is in the history, oldest first" \
  'print(" ".join(h["field"] + ":" + h["state"] for h in d["tasks"][0]["history"]))' \
  "build:building build:built review:in-review review:failed build:built"
sb spec status SP-2 T1 in-review
sb spec status SP-2 T1 blocked
sb spec status SP-2
out_has "spec status: blocked during a review is the review's" "T1 - build: built - review: blocked - "
sb spec status SP-2 T1 building
sb spec status SP-2 T1 blocked
sb spec status SP-2
out_has "spec status: blocked otherwise is the build's" "T1 - build: blocked - review: blocked - "
if cmp -s "$L2" "$tmp/sp2.readme"; then pass "spec issue: the README is still byte-identical"; else fail "spec issue: the README is still byte-identical"; fi
printf '%s\n' '' '- [x] T2 - The second task' '  - Requirements: R1' >>"$vault/$S/tasks/SP-2/spec/tasks.md"
sb spec status SP-2
out_has "spec status: a ticked task build.json lacks starts built and passed" \
  'T2 - build: built - review: passed - fails 0 - commits - - fix - - The second task'
sb spec status SP-2 T1 done
rc_is "spec status: another state exits 5" 5
err_has "spec status: and names both kinds of state" "a review state is one of: in-review, passed, failed, blocked"
sb spec status SP-2 T1 built --commit xyz
rc_is "spec status: a commit that is not hex exits 5" 5
sb spec status SP-2 T9 built
rc_is "spec status: a task tasks.md lacks exits 1" 1
sb spec status SP-2 T1
rc_is "spec status: a task with no state exits 5" 5
sb spec issue SP-2 T1 "No fix given."
rc_is "spec issue: no --fix exits 5" 5
sb spec tick SP-2 T1 --commit abc
rc_is "spec tick: --commit is not its flag, exit 5" 5
cp "$B2" "$tmp/b2.good"
printf '%s\n' '{"story": "SP-2", "tasks": [' >"$B2"
sb spec status SP-2
rc_is "spec status: a build.json that is not JSON exits 1" 1
err_has "spec status: and names it" "$S/tasks/SP-2/build.json is not a JSON object with a tasks array"
sb spec status SP-2 T1 built
rc_is "spec status: a write on it exits 1 too" 1
is "spec status: and leaves it as it was" "$(cat "$B2")" '{"story": "SP-2", "tasks": ['
for bad in '' '   ' '{}' '[]' '{"tasks": {}}'; do
  printf '%s\n' "$bad" >"$B2"
  sb spec status SP-2
  rc_is "spec status: a build.json that holds '$bad' exits 1, never a fresh build" 1
  sb spec issue SP-2 T1 "Lost?" --fix "No."
  rc_is "spec issue: and a write on '$bad' exits 1" 1
done
: >"$B2"
sb spec status SP-2 --json
rc_is "spec status --json: an empty build.json exits 1" 1
out_is "spec status --json: and prints nothing" ""
cp "$tmp/b2.good" "$B2"
tr -d '\n' <"$tmp/b2.good" >"$B2"
sb spec status SP-2
text="$OUT"
cp "$tmp/b2.good" "$B2"
sb spec status SP-2
is "spec status: a build.json on one line reads the same" "$text" "$OUT"
sb spec status SP-2 T1 built
is "spec status: a write leaves no temp file in the task folder" \
  "$(cd "$vault/$S/tasks/SP-2" && ls -A | grep -v '^README.md$' | grep -v '^spec$' || true)" "build.json"
sb spec issue SP-2 T1 "Line one.${NL}Line two." --fix "Fix it${CR}${NL}now."
sb spec status SP-2
out_has "spec status: a line break in an issue prints as a blank" \
  "  - Issue 2026-10-08: Line one. Line two. Fix: Fix it now."
is "spec status: and every issue stays one line" "$(printf '%s\n' "$OUT" | grep -c '^  - Issue ')" "2"
is "spec status: and no line is left over" "$(printf '%s\n' "$OUT" | grep -vc '^T[0-9]* - build: \|^  - Issue ' || true)" "0"
OUT="$(cat "$B2")"
json_is "spec issue: build.json keeps the line break" 'print(d["tasks"][0]["issues"][-1]["issue"] == "Line one.\nLine two.")' "True"
sb spec status SP-2 --json
json_is "spec status --json: the issue line has no line break" 'print(d[0]["issues"][-1])' \
  "Issue 2026-10-08: Line one. Line two. Fix: Fix it now."
cp "$tmp/b2.good" "$B2"
sb spec status SP-3 T1 todo
rc_is "spec status: a CRLF README takes a write" 0
is "spec status: every line keeps its CRLF" "$(grep -vc "$CR\$" "$L3" || true)" "0"
# A README Build section, as versions before 0.7.0 wrote it: read as it is, moved on the next write.
B5="$vault/$S/tasks/SP-5/build.json"
L5T="$vault/$S/tasks/SP-5/spec/tasks.md"
printf '%s\n' '# SP-5 - Tasks' '' '- [ ] T1 - First' '  - Requirements: R1' '- [x] T2 - Second' '  - Requirements: R1' \
  '- [ ] T3 - Third' '  - Requirements: R1' '- [ ] T4 - Fourth' '  - Requirements: R1' '- [ ] T5 - Fifth' '  - Requirements: R1' >"$L5T"
cp "$L5" "$tmp/sp5.without"
awk '/^## Status notes$/ {
    print "## Build"; print ""
    print "- T1 - failed - commits `abc1234`, `def5678` - First"
    print "  - Issue 2026-10-01: The form has one field. Fix: Add the password field."
    print "- T2 - passed - commits `0a1b2c3` - Second"
    print "- T3 - blocked - commits - - Third"
    print "- T4 - blocked - commits `1111aaa` - Fourth"
    print "- T9 - in-review - commits `2222bbb` - Gone - with a dash"
    print ""
  } { print }' "$tmp/sp5.without" >"$L5"
cp "$L5" "$tmp/sp5.with"
sb spec status SP-5
out_is "spec status: an old Build section is read, each state in its field" \
  'T1 - build: built - review: failed - fails 0 - commits abc1234, def5678 - fix - - First
  - Issue 2026-10-01: The form has one field. Fix: Add the password field.
T2 - build: built - review: passed - fails 0 - commits 0a1b2c3 - fix - - Second
T3 - build: blocked - review: - - fails 0 - commits - - fix - - Third
T4 - build: built - review: blocked - fails 0 - commits 1111aaa - fix - - Fourth
T5 - build: todo - review: - - fails 0 - commits - - fix - - Fifth
T9 - build: built - review: in-review - fails 0 - commits 2222bbb - fix - - Gone - with a dash'
if cmp -s "$L5" "$tmp/sp5.with"; then pass "spec status: reading leaves the old section"; else fail "spec status: reading leaves the old section"; fi
sb spec status SP-5 T5 building
rc_is "spec status: a write on an old section exits 0" 0
err_has "spec status: says it moved the section" "note: moved ## Build of $S/tasks/SP-5/README.md into $S/tasks/SP-5/build.json"
if cmp -s "$L5" "$tmp/sp5.without"; then pass "spec status: the section is gone, the rest byte-identical"; else fail "spec status: the section is gone, the rest byte-identical" "$(diff "$tmp/sp5.without" "$L5")"; fi
sb spec status SP-5
out_has "spec status: the moved rows are in build.json" 'T1 - build: built - review: failed - fails 0 - commits abc1234, def5678 - fix - - First
  - Issue 2026-10-01: The form has one field. Fix: Add the password field.'
out_has "spec status: with the write applied" 'T5 - build: building - review: - - fails 0 - commits - - fix - - Fifth'
out_has "spec status: a moved row whose task left tasks.md stays at the end" \
  'T9 - build: built - review: in-review - fails 0 - commits 2222bbb - fix - - Gone - with a dash'
OUT="$(cat "$B5")"
json_is "spec status: a moved issue keeps its date, its fix split off" 'print(d["tasks"][0]["issues"])' \
  "[{'at': '2026-10-01', 'session': '-', 'issue': 'The form has one field.', 'fix': 'Add the password field.', 'round': 0}]"
json_is "spec status: a moved row has no history" 'print(d["tasks"][0]["history"])' "[]"
printf '%s\n' '' '## Build' '' '- T1 - todo - commits - - First' >>"$L5"
sb spec issue SP-5 T1 "Late." --fix "Fix it."
sb spec status SP-5
is "spec issue: build.json wins over a section written later" "$(printf '%s\n' "$OUT" | head -1)" \
  "T1 - build: built - review: failed - fails 0 - commits abc1234, def5678 - fix - - First"
if cmp -s "$L5" "$tmp/sp5.without"; then pass "spec issue: a section at the end goes with the blank lines before it"; else fail "spec issue: a section at the end goes with the blank lines before it" "$(diff "$tmp/sp5.without" "$L5")"; fi
awk '/^## Status notes/ { printf "## Build\r\n\r\n- T1 - built - commits `abc1234` - One\r\n\r\n" } { print }' "$L3" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$L3"
sb spec issue SP-3 T1 "CRLF." --fix "Keep it."
file_lacks "spec issue: the section leaves a CRLF README" "$L3" "## Build"
is "spec issue: and every line keeps its CRLF" "$(grep -vc "$CR\$" "$L3" || true)" "0"
# On Windows awk, grep and sed are shell functions that read in binary mode; env or command skips them.
is "libraries: awk, grep and sed are never run through env or command" \
  "$(grep -nE '(^|[^a-zA-Z_])(env|command) +[^-]' "$here"/scripts/lib/*.sh | grep -v '/platform\.sh:' | grep -E '(awk|grep|sed)' || true)" ""
# build.json sits in the vault even for a repo spec, so the repo's tree stays clean.
edit "$SPF" 's/^spec_home: vault$/spec_home: repo/'
printf '%s\n' '# SP-6 - Tasks' '' '- [ ] T1 - Repo task' '  - Requirements: R1' >"$tmp/scode/spec-app/spec/SP-6/tasks.md"
sb spec status SP-6 T1 building
rc_is "spec status: a repo spec takes a write" 0
exists "spec status: its build.json is in the vault's task folder" "$vault/$S/tasks/SP-6/build.json"
absent "spec status: and not in the repo" "$tmp/scode/spec-app/spec/SP-6/build.json"
edit "$SPF" 's/^spec_home: repo$/spec_home: vault/'

# ---------------------------------------------------------------- spec packet: uses, issues and the diff
sb task new SP-10 --project Specs --title "Packet story"
sb task set SP-10 delivery=spec branch=feature/SP-10
sb spec new SP-10
D10="$vault/$S/tasks/SP-10/spec"
printf '%s\n' '# SP-10 - Requirements' '' '## R1 - One' '' 'WHEN a user signs in, THE app SHALL open a session.' >"$D10/requirements.md"
printf '%s\n' '# SP-10 - Tasks' '' '- [ ] T1 - The API' '  - Requirements: R1' \
  '  - Provides: `login(email, password) -> Session`' '  - Provides: `logout(session)`' \
  '- [ ] T2 - The page' '  - Requirements: R1' '  - Uses: T1' \
  '- [ ] T3 - A later one' '  - Requirements: R1' '  - Uses: T4' \
  '- [ ] T4 - Uses one with none' '  - Requirements: R1' '  - Uses: T2' \
  '- [ ] T5 - Unknown' '  - Requirements: R1' '  - Uses: T1, T9' \
  '- [ ] T6 - None named' '  - Requirements: R1' '  - Uses: none' \
  '- [ ] T7 - Comma' '  - Requirements: R1' '  - Uses: T1,' >"$D10/tasks.md"
ODIR="${TMPDIR:-}"
mkdir -p "$tmp/tmpd"
export TMPDIR="$tmp/tmpd"
sb spec packet SP-10 T1
rc_is "spec packet: exit 0 before any build" 0
out_has "spec packet: no commit yet, no diff" "commits: -
fails: 0
diff: none (no commit)"
out_lacks "spec packet: no Uses part when it names none" "## Uses"
out_lacks "spec packet: no Issues part when it has none" "## Issues"
sb spec packet SP-10 T2
rc_is "spec packet: a task that uses an earlier one exits 0" 0
out_has "spec packet: holds the Provides lines of the task it uses" "## Uses

### T1 - The API

- Provides: \`login(email, password) -> Session\`
- Provides: \`logout(session)\`"
sb spec packet SP-10 T3
rc_is "spec packet: a task that uses a later one exits 1" 1
err_has "spec packet: and says so" "T3 uses T4, which is not an earlier task"
sb spec packet SP-10 T4
rc_is "spec packet: a used task with no Provides line exits 1" 1
err_has "spec packet: and names it" "T4 uses T2, which has no - Provides: line"
sb spec packet SP-10 T5
rc_is "spec packet: a used task tasks.md lacks exits 1" 1
err_has "spec packet: and names it" "T5 uses T9, which $S/tasks/SP-10/spec/tasks.md has no item for"
sb spec packet SP-10 T6
rc_is "spec packet: Uses: none exits 0" 0
out_lacks "spec packet: and has no Uses part" "## Uses"
sb spec packet SP-10 T7
rc_is "spec packet: a Uses line that ends in a comma exits 1" 1
err_has "spec packet: and says to write it on one line" "write each field of a task on one line"
APP="$tmp/scode/spec-app"
git -C "$APP" -c init.defaultBranch=main init -q
printf 'one\n' >"$APP/login.txt"
git -C "$APP" add login.txt
git -C "$APP" -c user.name=Test -c user.email=test@example.com commit -qm "SP-10 T1: The API"
h1="$(git -C "$APP" rev-parse --short HEAD)"
sb spec status SP-10 T1 built --commit "$h1"
sb spec issue SP-10 T1 "Logout is missing, at login.txt:1." --fix "Add logout."
sb spec issue SP-10 T1 "Two${NL}lines." --fix "One${NL}line."
sb spec packet SP-10 T1
rc_is "spec packet: exit 0 with a commit" 0
out_has "spec packet: names the task's commits" "commits: $h1"
dline="$(printf '%s\n' "$OUT" | sed -n 's/^diff: //p')"
is "spec packet: the diff is a temp file, outside the repo and the vault" "${dline%/*}" "$(shown "$tmp/tmpd")"
file_has "spec packet: the diff file holds the commit's change" "$dline" "+one"
out_has "spec packet: holds the task's logged issues, each on one line" "## Issues

- Issue 2026-10-08: Logout is missing, at login.txt:1. Fix: Add logout.
- Issue 2026-10-08: Two lines. Fix: One line."
case "$OUT" in
  *"## Issues"*"## Checks"*"## Validation"*) pass "spec packet: the issues, then the checks, then the validation steps" ;;
  *) fail "spec packet: the issues, then the checks, then the validation steps" "in: $OUT" ;;
esac
printf 'two\n' >>"$APP/login.txt"
git -C "$APP" -c user.name=Test -c user.email=test@example.com commit -qam "SP-10 T1: The API"
h2="$(git -C "$APP" rev-parse --short HEAD)"
sb spec status SP-10 T1 built --commit "$h2"
sb spec packet SP-10 T1
dline="$(printf '%s\n' "$OUT" | sed -n 's/^diff: //p')"
out_has "spec packet: a retry's commits, in order" "commits: $h1, $h2"
file_has "spec packet: the diff holds the first commit" "$dline" "+one"
file_has "spec packet: and the second" "$dline" "+two"
is "spec packet: the repo's tree stays clean" "$(git -C "$APP" status --porcelain | grep -v ' spec/' || true)" ""
# A failed review: the next packet is a fix's, with only the findings of that review.
sb spec status SP-10 T1 in-review
sb spec issue SP-10 T1 "Round one: no logout." --fix "Add it."
sb spec status SP-10 T1 failed
sb spec packet SP-10 T1
out_has "spec packet: a fix names the failed reviews" "fails: 1"
out_has "spec packet: no fix commit yet, no diff" "diff: none (no fix commit)"
out_has "spec packet: a fix holds the findings of the failed review" "- Issue 2026-10-08: Round one: no logout. Fix: Add it."
out_lacks "spec packet: and not those logged before it" "Logout is missing"
printf 'three\n' >>"$APP/login.txt"
git -C "$APP" -c user.name=Test -c user.email=test@example.com commit -qam "SP-10 T1: The API"
h3="$(git -C "$APP" rev-parse --short HEAD)"
sb spec status SP-10 T1 building
sb spec status SP-10 T1 built --commit "$h3"
sb spec status SP-10
out_has "spec status: names the fix built since the last failed review" "fails 1 - commits $h1, $h2, $h3 - fix $h3 - The API"
sb spec status SP-10 --json
json_is "spec status --json: the fix is a list" 'print(d[0]["fix"])' "['$h3']"
sb spec packet SP-10 T1
out_has "spec packet: a fix still names every commit" "commits: $h1, $h2, $h3"
dline="$(printf '%s\n' "$OUT" | sed -n 's/^diff: //p')"
file_has "spec packet: a fix's diff holds the fix's commit" "$dline" "+three"
file_lacks "spec packet: and not the commits before the failed review" "$dline" "+one"
OUT="$(cat "$vault/$S/tasks/SP-10/build.json")"
json_is "spec status: build.json records the commit of a state set with --commit" \
  'print([h.get("commit", "-") for h in d["tasks"][0]["history"]])' "['$h1', '$h2', '-', '-', '-', '$h3']"
json_is "spec issue: each issue records its review round" 'print([i["round"] for i in d["tasks"][0]["issues"]])' "[0, 0, 1]"
sb spec status SP-10 T1 in-review
sb spec issue SP-10 T1 "Round two: logout leaks." --fix "Close it."
sb spec status SP-10 T1 failed
sb spec status SP-10
out_has "spec status: counts the failed reviews, with no fix since the last" "T1 - build: built - review: failed - fails 2 - commits $h1, $h2, $h3 - fix - - The API"
sb spec packet SP-10 T1
out_has "spec packet: a second fix holds only the second review's findings" "- Issue 2026-10-08: Round two: logout leaks. Fix: Close it."
out_lacks "spec packet: and not the first's" "Round one"
sb spec status SP-10 T1 in-review
sb spec status SP-10 T1 passed
sb spec issue SP-10 T1 "The build-wide run fails." --fix "Fix it."
sb spec status SP-10 T1 failed
sb spec packet SP-10 T1
out_has "spec packet: a passed task failed by the build-wide run counts it" "fails: 3"
out_has "spec packet: and its fix holds that finding" "- Issue 2026-10-08: The build-wide run fails. Fix: Fix it."
out_lacks "spec packet: alone" "Round two"
sb spec status SP-10 --json
json_is "spec status --json: fails is a count" 'print(d[0]["fails"] + 1)' "4"
sb spec status SP-10 T2 built --commit abcdef0
sb spec packet SP-10 T2
rc_is "spec packet: a commit git cannot show still exits 0" 0
out_has "spec packet: and has no diff" "diff: none (git show failed)"
err_has "spec packet: and names the commit" "note: git show abcdef0 failed in spec-app"
if [ -n "$ODIR" ]; then export TMPDIR="$ODIR"; else unset TMPDIR; fi

# ---------------------------------------------------------------- spec and validation --json
sb help
out_has "help: names the commands that take --json" \
  "json:     task head, spec tasks, spec status <ID>, validation <project> [repo] and validation run take --json"
sb task new SP-9 --project Specs --title "Json story"
sb task set SP-9 delivery=spec
sb spec tasks SP-9 --json
rc_is "spec tasks --json: no tasks.md exits 1" 1
out_is "spec tasks --json: and prints nothing" ""
sb spec new SP-9
L9="$vault/$S/tasks/SP-9/README.md"
printf '%s\n' '# SP-9 - Tasks' '' '- [ ] T1 - Say "hi" \ there' '  - Requirements: R1' \
  '- [x] T2 - Two - parts' '  - Requirements: R1' '- [ ] T3' >"$vault/$S/tasks/SP-9/spec/tasks.md"
sb spec tasks SP-9 --json
rc_is "spec tasks --json: exit 0" 0
json_ok "spec tasks --json: parses as JSON"
out_is "spec tasks --json: one object per row, quotes and backslashes escaped" '[
  {"id": "T1", "state": "todo", "title": "Say \"hi\" \\ there", "bundle": "-"},
  {"id": "T2", "state": "done", "title": "Two - parts", "bundle": "-"},
  {"id": "T3", "state": "todo", "title": "-", "bundle": "-"}
]'
sb spec tasks SP-9
text="$OUT"
sb spec tasks SP-9 --json
json_is "spec tasks --json: the same fields as the text" \
  'for r in d: print("\t".join([r["id"], r["state"], r["title"], r["bundle"]]))' "$text"
sb spec status SP-9 --json
rc_is "spec status --json: a story with no build exits 0" 0
out_is "spec status --json: and prints an empty array" "[]"
B9="$vault/$S/tasks/SP-9/build.json"
sb spec status SP-9 T1 built --commit abc1234
sb spec status SP-9 T1 in-review --commit def5678
sb spec status SP-9
out_has "spec status: a task with no commit prints commits -" 'T2 - build: built - review: passed - fails 0 - commits - - fix - - Two - parts'
out_has "spec status: and one with no title prints -" 'T3 - build: todo - review: - - fails 0 - commits - - fix - - -'
sb spec issue SP-9 T1 'Say "hi" \ there.' --fix "Tab${TAB}here."
sb spec status SP-9 T2 passed --commit 0a1b2c3
sb spec status SP-9 T3 todo --commit 1234abc
sb spec status SP-9 --json
rc_is "spec status --json: exit 0" 0
json_ok "spec status --json: parses as JSON"
row1='{"id": "T1", "build": "built", "review": "in-review", "fails": 0, "commits": ["abc1234", "def5678"], "fix": [], '
row1="$row1"'"title": "Say \"hi\" \\ there", '
row1="$row1"'"issues": ["Issue 2026-10-08: Say \"hi\" \\ there. Fix: Tab\there."]}'
out_is "spec status --json: one object per task, commits and issues as arrays" "[
  $row1,
  "'{"id": "T2", "build": "built", "review": "passed", "fails": 0, "commits": ["0a1b2c3"], "fix": [], "title": "Two - parts", "issues": []},
  {"id": "T3", "build": "todo", "review": "-", "fails": 0, "commits": ["1234abc"], "fix": [], "title": "-", "issues": []}
]'
sb spec status SP-9
text="$OUT"
sb spec status SP-9 --json
json_is "spec status --json: the same fields as the text" 'for r in d:
    c = ", ".join(r["commits"]) or "-"
    x = ", ".join(r["fix"]) or "-"
    print("%s - build: %s - review: %s - fails %d - commits %s - fix %s - %s" % (r["id"], r["build"], r["review"], r["fails"], c, x, r["title"]))
    for i in r["issues"]: print("  - " + i)' "$text"
OUT="$(cat "$B9")"
json_ok "spec issue: build.json with quotes, a backslash and a tab parses as JSON"
json_is "spec issue: and reads back as written" 'i = d["tasks"][0]["issues"][0]; print(i["issue"] == "Say \"hi\" \\ there." and i["fix"] == "Tab\there.")' "True"
cp "$B9" "$tmp/b9.before"
sb spec status SP-9 T1 built --json
rc_is "spec status --json: a task and a state exit 5" 5
if cmp -s "$B9" "$tmp/b9.before"; then pass "spec status --json: and nothing is written"; else fail "spec status --json: and nothing is written"; fi
printf '%s\n' '# SP-9 - Tasks' '' '- [ ] T1 - Say "hi" \ there' '  - Requirements: R1' '- [ ] T3' \
  >"$vault/$S/tasks/SP-9/spec/tasks.md"
sb spec status SP-9 T1 built
sb spec status SP-9 T1 built
sb spec status SP-9
is "spec status: a task that left tasks.md keeps its title over two writes, at the end" "$(printf '%s\n' "$OUT" | tail -1)" \
  'T2 - build: built - review: passed - fails 0 - commits 0a1b2c3 - fix - - Two - parts'
printf '%s\n' "- [ ] T4 - $(printf 'Caf\303\251 \001') a${CR}b" >>"$vault/$S/tasks/SP-9/spec/tasks.md"
sb spec tasks SP-9 --json
json_ok "spec tasks --json: a title with UTF-8, a control character and a CR parses as JSON"
out_has "spec tasks --json: UTF-8 bytes are kept, \\u0001 and \\r are escaped" \
  "$(printf '{"id": "T4", "state": "todo", "title": "Caf\303\251 \\u0001 a\\rb", "bundle": "-"}')"
json_is "spec tasks --json: and the title reads back as written" \
  'print(d[-1]["title"] == "Caf\u00e9 \x01 a\rb")' "True"
sb spec SP-9 --json
rc_is "spec --json: the spec form takes no --json, exit 5" 5
sb spec tick SP-9 T1 --json
rc_is "spec tick --json: exit 5" 5
sb validation Specs
text="$OUT"
sb validation Specs --json
rc_is "validation --json: exit 0" 0
json_ok "validation --json: parses as JSON"
json_is "validation --json: the same fields as the text" \
  'for r in d: print("\t".join([r["name"], r["home"], r["path"], r["state"]]))' "$text"
vrow="{\"name\": \"spec-app\", \"home\": \"vault\", "
vrow="$vrow\"path\": \"$S/claude/validation.md\", \"state\": \"ok\"}"
out_has "validation --json: one object per repo" "$vrow"
sb validation RepoHome --json
rc_is "validation --json: a project with no repo exits 0" 0
out_is "validation --json: and prints an empty array" "[]"
sb validation Specs spec-app
text="$OUT"
sb validation Specs spec-app --json
rc_is "validation <repo> --json: exit 0" 0
json_ok "validation <repo> --json: parses as JSON"
json_is "validation <repo> --json: the same fields as the text" 'print("path: " + d["path"])
if d["body"]: print(d["body"])' "$text"
out_has "validation <repo> --json: one object, the path first" \
  "{${NL}  \"path\": \"$S/claude/validation.md\",${NL}  \"body\": \""
out_has "validation <repo> --json: the body's lines are escaped" '\n\n### Checks'
sb validation Specs nope --json
rc_is "validation <repo> --json: an unknown repo exits 1" 1
out_is "validation <repo> --json: and prints nothing" ""
sb validation new Specs spec-app --json
rc_is "validation new --json: exit 5" 5

# ---------------------------------------------------------------- result
result
