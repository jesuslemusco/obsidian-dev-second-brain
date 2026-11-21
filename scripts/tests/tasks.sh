#!/usr/bin/env bash
# Area tasks: task new, set, note, head, docs, tag, alias and dep, and an alias as the id.
# Usage: bash scripts/test.sh tasks, or bash scripts/tests/tasks.sh
. "$(dirname "$0")/lib.sh"

# Those projects as project.sh leaves them, and Three, a project with no profile.
fixture_profiles

# ---------------------------------------------------------------- task new
mkdir -p "$vault/$P/docs/billing/Invoices" "$vault/$P/docs/api"
sb task new EX-1 --project Example --title 'Fix: totals "rounded" twice' --topics billing/invoices
rc_is "task new: exit 0" 0
out_is "task new: prints the README path" "$P/tasks/EX-1/README.md"
T1="$vault/$P/tasks/EX-1/README.md"
is "task new: first alias is the folder name" "$(sb_fm_list "$T1" aliases | head -1)" "EX-1"
line_is "task new: title quoted and escaped" "$T1" 'title: "Fix: totals \"rounded\" twice"'
line_is "task new: status planned" "$T1" "status: planned"
line_is "task new: topic tag" "$T1" "  - billing/invoices"
line_is "task new: rollup tag" "$T1" "  - status/active"
line_is "task new: up-link carries the path" "$T1" "> Up: [[$P/tasks/README|Example Tasks Hub]]"
line_is "task new: heading" "$T1" '# EX-1 - Fix: totals "rounded" twice'
file_lacks "task new: never writes jira_id" "$T1" "jira_id"
file_lacks "task new: no sprint key in the backlog" "$T1" "sprint:"
is "task new: body sections in order" "$(grep '^## ' "$T1" | tr '\n' '|')" \
  "## Description|## Findings|## Acceptance criteria|## Approach / Key decisions|## Code verification (read-only)|## Changes|## Verification|## Status notes|## Discovery log|"
line_is "task new: the branch line names the canonical branch" "$T1" '**Branch:** `none yet` - <the branch; the canonical one when several carry the ticket id>'
line_is "task new: the description's context line" "$T1" "<Context: what is broken or missing, who asked, where in the system it lives.>"
line_is "task new: findings only from evidence, else the section goes" "$T1" "<Only when evidence exists: conclusion first, then the evidence. Otherwise delete the section.>"
line_is "task new: a criterion someone else can check" "$T1" "- [ ] <a condition someone else can check>"
line_is "task new: the ticket's top 4 criteria only" "$T1" "- [ ] <the top 4 only, as in the ticket>"
line_is "task new: what the code confirmed" "$T1" "<What the code confirmed: files, functions, behaviour, any mismatch with the ticket.>"
cp "$T1" "$tmp/t1.before"
sb task new EX-1 --project Example --title Again
rc_is "task new: existing folder gives exit 6" 6
is "task new: the existing README is untouched" "$(cmp -s "$tmp/t1.before" "$T1"; echo $?)" "0"
sb task new EX-2 --project Example --title Second --topics "docs/API, billing-old"
rc_is "task new: several topics" 0
err_has "task new: warns about a topic with no folder" "billing-old"
T2="$vault/$P/tasks/EX-2/README.md"
line_is "task new: topics root stripped, lowercased" "$T2" "  - api"
sb task new EX-3 --project Example
T3="$vault/$P/tasks/EX-3/README.md"
is "task new: no topics leaves no gap in tags" "$(grep -A1 '^tags:' "$T3" | tail -1)" "  - type/task"
line_is "task new: default title" "$T3" 'title: "Untitled"'
sb task new TWO-1 --title "Other project"
out_is "task new: project found from the key" "$P2/tasks/TWO-1/README.md"
sb task new EX-9
rc_is "task new: a shared key and no --project gives exit 5" 5
sb task new "bad/id" --project Example
rc_is "task new: an id with a slash gives exit 5" 5
sb task new
rc_is "task new: no id gives exit 5" 5
sb task new T-1 --project Three
rc_is "task new: a project with no profile gives exit 1" 1
sb task new EX-7 --project Example --envs
rc_is "task new --envs: no environments in the profile gives exit 5" 5
absent "task new --envs: nothing created on refusal" "$vault/$P/tasks/EX-7"
edit "$vault/$P/claude/profile.md" 's/^environments: \[\]$/environments: [dev, qa]/'
sb task new EX-7 --project Example --envs --title "Per environment"
rc_is "task new --envs: exit 0" 0
T7="$vault/$P/tasks/EX-7/README.md"
line_is "task new --envs: first environment holds the id" "$T7" "  dev: { id: EX-7, status: planned }"
file_lacks "task new --envs: later environments wait for their tickets" "$T7" "  qa:"
is "task new --envs: additions sit before the description" "$(($(lineno "$T7" '## Description') > $(lineno "$T7" '## Environments')))" "1"
file_has "task new --envs: the per-environment heading form" "$T7" '`### <ENV> - <ID> (<status>)`'
file_has "task new --envs: the first environment's heading, with its status" "$T7" '`### DEV - EX-7 (planned)`'
line_is "task new --envs: a later ticket is added as an alias" "$T7" "- Add a later environment's ticket to \`envs:\` and run \`second-brain task alias EX-7 add <ID>\`."
for t in EX-4 EX-5 EX-6; do sb task new "$t" --project Example --title "Task $t"; done

# ---------------------------------------------------------------- task set
sb task set EX-1 status=in-progress
rc_is "task set: exit 0" 0
out_is "task set: prints the changed key" "status: in-progress"
sb task set EX-1 status=done
out_is "task set: status and tag reported together" "status: done
tags: status/done"
line_is "task set: status written" "$T1" "status: done"
line_is "task set: tag follows to status/done" "$T1" "  - status/done"
file_lacks "task set: old tag gone" "$T1" "status/active"
sb task set EX-1 status=in-review
line_is "task set: tag follows back to status/active" "$T1" "  - status/active"
file_lacks "task set: no stale status/done" "$T1" "status/done"
sb task set EX-1 status=abandoned
line_is "task set: abandoned rolls up to status/done" "$T1" "  - status/done"
sb task set EX-1 status=in-review
cp "$T1" "$tmp/t1.before"
sb task set EX-1 "next=Check: the #1 thing"
line_is "task set: a value that needs quotes" "$T1" 'next: "Check: the #1 thing"'
is "task set: only that line changed" "$(diff "$tmp/t1.before" "$T1" | grep -c '^[<>]')" "2"
sb task set EX-1 sprint=2026-10-14 branch=feature/EX-1-fix epic=-
out_is "task set: several keys at once" "sprint: 2026-10-14
branch: feature/EX-1-fix"
line_is "task set: sprint id quoted" "$T1" 'sprint: "2026-10-14"'
line_is "task set: plain value unquoted" "$T1" "branch: feature/EX-1-fix"
line_is "task set: lone dash stays quoted" "$T1" 'epic: "-"'
is "task set: a new sprint key lands after epic" "$(($(lineno "$T1" 'sprint:') - $(lineno "$T1" 'epic:')))" "1"
sb task set EX-1 epic=
out_is "task set: key= removes the key" "epic: (removed)"
file_lacks "task set: key removed from the file" "$T1" "epic:"
sb task set EX-1 status=in-review
out_is "task set: nothing to change" "no change"
sb task set EX-1 status=active
rc_is "task set: a non-standard status gives exit 5" 5
line_is "task set: refused status not written" "$T1" "status: in-review"
sb task set EX-1 jira_id=EX-1
rc_is "task set: jira_id gives exit 5" 5
file_lacks "task set: jira_id never written" "$T1" "jira_id"
sb task set EX-1 tags=x
rc_is "task set: a list key gives exit 5" 5
sb task set EX-1 sprint=next-week
rc_is "task set: a sprint id that is not a date gives exit 5" 5
sb task set EX-1
rc_is "task set: no pair gives exit 5" 5
sb task set EX-404 status=done
rc_is "task set: unknown task gives exit 1" 1
sb task set EX-2 status=planned next="Draft the API change"
sb task set EX-3 status=done
sb task set EX-4 status=abandoned
sb task set EX-5 status=in-progress
T6="$vault/$P/tasks/EX-6/README.md"
awk '{ printf "%s\r\n", $0 }' "$T6" >"$tmp/crlf.tmp" && cat "$tmp/crlf.tmp" >"$T6"
sb task set EX-6 status=in-review "next=a: b" sprint=2026-10-14 epic=
rc_is "task set: CRLF file, exit 0" 0
is "task set: every line still ends in CRLF" "$(grep -c "$CR\$" "$T6")" "$(grep -c '' "$T6")"
line_is "task set: CRLF value written" "$T6" "next: \"a: b\"$CR"
line_is "task set: CRLF status written" "$T6" "status: in-review$CR"
line_is "task set: CRLF new key written" "$T6" "sprint: \"2026-10-14\"$CR"
sb task note EX-6 "Note on a CRLF file" --session s9
is "task note: CRLF kept" "$(grep -c "$CR\$" "$T6")" "$(grep -c '' "$T6")"
is "sb_fm_get: reads a CRLF file" "$(SB_ROOT="$vault"; sb_fm_get "$T6" status)" "in-review"

# ---------------------------------------------------------------- task note
sb task note EX-1 "First note" --session abc123
rc_is "task note: exit 0" 0
out_is "task note: prints the line it added" '**2026-10-08 (session `abc123`) - First note**'
sb task note EX-1 "Second note" --session abc123
is "task note: newest first" "$(($(lineno "$T1" 'Second note') < $(lineno "$T1" 'First note')))" "1"
is "task note: under the status notes heading" "$(($(lineno "$T1" 'Second note') > $(lineno "$T1" '## Status notes')))" "1"
is "task note: above the discovery log" "$(($(lineno "$T1" 'First note') < $(lineno "$T1" '## Discovery log')))" "1"
sb task note EX-2 "No session here"
out_is "task note: no session id, no session part" '**2026-10-08 - No session here**'
sb task note EX-1
rc_is "task note: no text gives exit 5" 5
sb task note EX-404 "x"
rc_is "task note: unknown task gives exit 1" 1
mkdir -p "$vault/$P/tasks/legacy-task"
printf '# Legacy task\n\nNo frontmatter and no sections.\n' >"$vault/$P/tasks/legacy-task/README.md"
sb task note legacy-task "Picked up again" --project Example
rc_is "task note: a note with no status notes section" 0
file_has "task note: adds the section" "$vault/$P/tasks/legacy-task/README.md" "## Status notes"

# ---------------------------------------------------------------- task head
edit "$T1" 's/^\*\*Summary:\*\* .*$/**Summary:** Totals are rounded per line and again per invoice,\
so large invoices drift by a cent./'
sb task head EX-1
rc_is "task head: exit 0" 0
if [ "$(lines "$OUT")" -le 15 ]; then pass "task head: at most 15 lines"; else fail "task head: at most 15 lines" "$OUT"; fi
out_has "task head: id" "id: EX-1"
out_has "task head: title" 'title: Fix: totals "rounded" twice'
out_has "task head: status" "status: in-review"
out_has "task head: next" "next: Check: the #1 thing"
out_has "task head: sprint" "sprint: 2026-10-14"
out_has "task head: branch" "branch: feature/EX-1-fix"
out_has "task head: topics" "topics: billing/invoices"
out_has "task head: summary joined over its wrapped line" "summary: Totals are rounded per line and again per invoice, so large invoices drift by a cent."
out_has "task head: newest status note" 'last_note: **2026-10-08 (session `abc123`) - Second note**'
out_has "task head: no environment set prints a dash" "envs: -"
sb task head EX-7
out_has "task head: environment set" "envs: dev:EX-7:planned"
sb task head legacy-task --project Example
out_has "task head: a note with no frontmatter" "status: -"
out_has "task head: title from the heading" "title: Legacy task"
edit "$T7" 's/^  - EX-7$/  - EX-7\
  - EX-70/'
edit "$T7" 's/^  dev: .*$/  dev:  { id: EX-7, status: done }\
  qa:   { id: EX-70, status: planned }/'
sb task head EX-7
out_has "task head: every environment of the set, in the note's order" "envs: dev:EX-7:done,qa:EX-70:planned"
sb task head EX-70
out_has "task head: an alias id finds the set" "id: EX-7"
if [ "$(lines "$OUT")" -le 15 ]; then pass "task head: an environment set still fits 15 lines"; else fail "task head: an environment set still fits 15 lines" "$OUT"; fi
sb task head EX-404
rc_is "task head: unknown task gives exit 1" 1
sb task head
rc_is "task head: no id gives exit 5" 5

# ---------------------------------------------------------------- task head --json
sb task head EX-1
text="$OUT"
sb task head EX-1 --json
rc_is "task head --json: exit 0" 0
json_ok "task head --json: parses as JSON"
json_is "task head --json: the same fields as the text, in its order" "$HEAD_PY" "$text"
out_has "task head --json: one object, a key per line" \
  "{${NL}  \"id\": \"EX-1\",${NL}  \"path\": \"$P/tasks/EX-1/README.md\","
out_has "task head --json: quotes are escaped" '"title": "Fix: totals \"rounded\" twice"'
out_has "task head --json: topics is an array" '"topics": ["billing/invoices"]'
out_has "task head --json: no environment set is an empty array" '"envs": []'
out_has "task head --json: a missing value is a dash" '"epic": "-"'
is "task head --json: the object closes on the last line" "$(printf '%s\n' "$OUT" | tail -1)" "}"
sb task head EX-7 --json
out_has "task head --json: each environment is an item" \
  '"envs": ["dev:EX-7:done", "qa:EX-70:planned"]'
sb task head EX-7
text="$OUT"
sb task head --json EX-7
json_is "task head --json: the flag may come first" "$HEAD_PY" "$text"
sb task head EX-404 --json
rc_is "task head --json: unknown task gives exit 1" 1
out_is "task head --json: and prints nothing" ""
sb task bogus
rc_is "task: unknown subcommand gives exit 5" 5

# ---------------------------------------------------------------- task docs
cp "$T2" "$tmp/t2.saved"
cp "$T3" "$tmp/t3.saved"
edit "$T2" 's/^## Status notes$/## Docs to update\
\
- [ ] docs\/billing.md - say totals round once\
- [x] README.md - already done\
  - [ ] docs\/api.md - the rounding field\
\
```\
- [ ] docs\/example.md - only an example in a fence\
```\
\
## Status notes/'
edit "$T3" 's/^## Status notes$/## Docs to update\
\
- [x] docs\/billing.md - all ticked\
\
## Status notes/'
sb task docs EX-2,EX-3 EX-1
rc_is "task docs: exit 0" 0
out_is "task docs: only the task with unticked lines, its path, then those lines" "EX-2 $P/tasks/EX-2/README.md
- [ ] docs/billing.md - say totals round once
  - [ ] docs/api.md - the rounding field"
out_lacks "task docs: a line inside a fenced code block is skipped" "example.md"
sb task docs "EX-2 EX-3"
rc_is "task docs: an id is never split at a space" 1
sb task docs EX-3 --project Example
rc_is "task docs: every line ticked exits 0" 0
out_is "task docs: every line ticked prints nothing" ""
sb task docs EX-404
rc_is "task docs: unknown task gives exit 1" 1
sb task docs
rc_is "task docs: no id gives exit 5" 5
cp "$tmp/t2.saved" "$T2"
cp "$tmp/t3.saved" "$T3"

# ---------------------------------------------------------------- an alias as the id
sb task set EX-70 "next=Promote to qa"
rc_is "task set: a later environment's id finds the set" 0
line_is "task set: written to the set's README" "$T7" "next: Promote to qa"
sb task note EX-70 "qa: promotion started" --session s2
file_has "task note: an alias id writes to the set" "$T7" '**2026-10-08 (session `s2`) - qa: promotion started**'
sb task tag EX-70 add api
out_is "task tag: an alias id edits the set" "api"
sb task tag EX-70 remove api
out_is "task tag: removed again through the alias" "-"
sb task new EX-70 --project Example --title "A second folder"
rc_is "task new: an id that is an alias of a task gives exit 6" 6
absent "task new: no folder for an alias" "$vault/$P/tasks/EX-70"

# ---------------------------------------------------------------- task tag
T4="$vault/$P/tasks/EX-4/README.md"
sb task tag EX-4 add billing/invoices
rc_is "task tag add: exit 0" 0
out_is "task tag add: prints the resulting topic tags" "billing/invoices"
is "task tag add: the topic goes before the type and status tags" "$(grep -A1 '^tags:' "$T4" | tail -1)" "  - billing/invoices"
sb task tag EX-4 add "docs/API"
out_is "task tag add: topics root stripped, lowercased" "billing/invoices
api"
cp "$T4" "$tmp/t4.before"
sb task tag EX-4 add "#Billing/Invoices"
out_is "task tag add: a tag it has is not added twice" "billing/invoices
api"
is "task tag add: the file is untouched by a duplicate" "$(cmp -s "$tmp/t4.before" "$T4"; echo $?)" "0"
sb task tag EX-4 add "Ops Runbooks"
err_has "task tag add: warns about a topic with no folder" "ops-runbooks"
is "task tag add: one line added" "$(diff "$tmp/t4.before" "$T4" | grep -c '^[<>]')" "1"
sb task tag EX-4 add type/bug
rc_is "task tag: a type/ tag is refused, exit 5" 5
sb task tag EX-4 remove status/done
rc_is "task tag: a status/ tag is refused, exit 5" 5
line_is "task tag: the refused status tag is still there" "$T4" "  - status/done"
file_lacks "task tag: the refused type tag was not written" "$T4" "type/bug"
sb task tag EX-4 remove API
out_is "task tag remove: matches without case" "billing/invoices
ops-runbooks"
sb task tag EX-4 remove nothing-like-it
rc_is "task tag remove: a tag it lacks changes nothing" 0
sb task tag EX-4 remove ops-runbooks
sb task tag EX-4 remove billing/invoices
out_is "task tag remove: no topic left prints a dash" "-"
line_is "task tag remove: the type tag stays" "$T4" "  - type/task"
sb task tag EX-4 rename a
rc_is "task tag: unknown action gives exit 5" 5
sb task tag EX-4 add
rc_is "task tag: no tag gives exit 5" 5
sb task tag EX-404 add api
rc_is "task tag: unknown task gives exit 1" 1
sb task tag EX-6 add api
out_is "task tag: CRLF file, tag added" "api"
is "task tag: CRLF kept after add" "$(grep -c "$CR\$" "$T6")" "$(grep -c '' "$T6")"
line_is "task tag: CRLF line written" "$T6" "  - api$CR"
sb task tag EX-6 remove api
is "task tag: CRLF kept after remove" "$(grep -c "$CR\$" "$T6")" "$(grep -c '' "$T6")"
file_lacks "task tag: CRLF tag removed" "$T6" "  - api"

# ---------------------------------------------------------------- task alias
sb task alias EX-4 add "Totals: rounding"
rc_is "task alias add: exit 0" 0
out_is "task alias add: prints the resulting aliases" "EX-4
Totals: rounding"
line_is "task alias add: an alias with a colon and a space is quoted" "$T4" '  - "Totals: rounding"'
is "task alias add: the first alias never changes" "$(grep -A1 '^aliases:' "$T4" | tail -1)" "  - EX-4"
cp "$T4" "$tmp/t4.before"
sb task alias EX-4 add "totals: ROUNDING"
is "task alias add: no duplicate, whatever the case" "$(cmp -s "$tmp/t4.before" "$T4"; echo $?)" "0"
sb task alias EX-4 add Rounding twice
out_is "task alias add: unquoted words are one alias, appended last" "EX-4
Totals: rounding
Rounding twice"
line_is "task alias add: a plain alias is not quoted" "$T4" "  - Rounding twice"
sb task alias EX-4 add EX-1
rc_is "task alias add: another task's folder id gives exit 6" 6
sb task alias EX-4 add EX-70
rc_is "task alias add: another task's alias gives exit 6" 6
file_lacks "task alias add: a refused alias is not written" "$T4" "EX-70"
sb task alias EX-4 remove "Rounding twice"
rc_is "task alias: only add is known, exit 5" 5
sb task alias EX-4 add
rc_is "task alias: no alias gives exit 5" 5
sb task alias EX-404 add x
rc_is "task alias: unknown task gives exit 1" 1
sb task alias EX-5 add EX-55
sb task head EX-55
out_has "task alias: the new alias finds the task" "id: EX-5"
sb task alias EX-6 add "Lambda: node summary"
is "task alias: CRLF kept" "$(grep -c "$CR\$" "$T6")" "$(grep -c '' "$T6")"
line_is "task alias: CRLF line written, quoted" "$T6" "  - \"Lambda: node summary\"$CR"
mkdir -p "$vault/$P2/tasks/no-alias"
printf -- '---\nstatus: planned\n---\n\n# no-alias - a note with no aliases\n' >"$vault/$P2/tasks/no-alias/README.md"
sb task alias no-alias add "Other name" --project "Example Two"
out_is "task alias: a note with no aliases gets the folder id first" "no-alias
Other name"

# ---------------------------------------------------------------- task dep
T5="$vault/$P/tasks/EX-5/README.md"
sb task dep EX-5 add EX-2
rc_is "task dep add: exit 0" 0
out_is "task dep add: prints the resulting links" "[[$P/tasks/EX-2/README|EX-2]]"
line_is "task dep add: the link is a quoted path link" "$T5" "  - \"[[$P/tasks/EX-2/README|EX-2]]\""
is "task dep add: depends_on lands after carried_from" "$(($(lineno "$T5" 'depends_on:') - $(lineno "$T5" 'carried_from:')))" "1"
cp "$T5" "$tmp/t5.before"
sb task dep EX-5 add EX-2
is "task dep add: a task it has is not added twice" "$(cmp -s "$tmp/t5.before" "$T5"; echo $?)" "0"
sb task dep EX-5 add EX-3
out_is "task dep add: appended last" "[[$P/tasks/EX-2/README|EX-2]]
[[$P/tasks/EX-3/README|EX-3]]"
sb task dep EX-5 add EX-70
out_has "task dep add: an alias links the task's folder" "[[$P/tasks/EX-7/README|EX-7]]"
sb task dep EX-5 remove EX-7
out_is "task dep remove: by folder id" "[[$P/tasks/EX-2/README|EX-2]]
[[$P/tasks/EX-3/README|EX-3]]"
cp "$T5" "$tmp/t5.before"
sb task dep EX-5 remove EX-1
rc_is "task dep remove: a task it lacks, exit 0" 0
is "task dep remove: a task it lacks changes nothing" "$(cmp -s "$tmp/t5.before" "$T5"; echo $?)" "0"
sb task dep EX-5 add EX-5
rc_is "task dep: the task itself gives exit 5" 5
sb task dep EX-5 add EX-55
rc_is "task dep: the task itself by an alias gives exit 5" 5
sb task dep EX-5 add EX-404
rc_is "task dep: an unknown task gives exit 1" 1
sb task dep EX-404 add EX-2
rc_is "task dep: an unknown task to edit gives exit 1" 1
is "task dep: nothing written on refusal" "$(cmp -s "$tmp/t5.before" "$T5"; echo $?)" "0"
sb task dep EX-5 block EX-2
rc_is "task dep: unknown action gives exit 5" 5
sb task dep EX-5 add
rc_is "task dep: no task named gives exit 5" 5
sb task set EX-5 depends_on=x
rc_is "task set: depends_on is a list, exit 5" 5
err_has "task set: depends_on points to task dep" "task dep"
sb task dep EX-2 add TWO-1
out_is "task dep add: a task of another project" "[[$P2/tasks/TWO-1/README|TWO-1]]"
sb task dep EX-2 remove TWO-1
out_is "task dep remove: the last one prints a dash" "-"
line_is "task dep remove: an empty list stays" "$T2" "depends_on: []"
edit "$T2" "s#^depends_on: \[\]\$#depends_on: [\"[[$P/tasks/EX-3/README.md|third]]\"]#"
file_has "task dep remove: the hand-written link is there first" "$T2" "README.md|third]]"
sb task dep EX-2 remove EX-3
out_is "task dep remove: matches a hand-written link by its path" "-"
edit "$T2" "s#^depends_on: \[\]\$#depends_on: [\"[[$P/tasks/EX-3/README|EX-3]]\"]#"
sb task dep EX-2 add EX-1
out_is "task dep add: to an inline list" "[[$P/tasks/EX-3/README|EX-3]]
[[$P/tasks/EX-1/README|EX-1]]"
line_is "task dep add: the inline item stays quoted" "$T2" "  - \"[[$P/tasks/EX-3/README|EX-3]]\""
line_is "task dep add: the new item after it" "$T2" "  - \"[[$P/tasks/EX-1/README|EX-1]]\""
file_lacks "task dep add: no inline list left" "$T2" "depends_on: ["
sb task dep EX-2 remove EX-3
sb task dep EX-2 remove EX-1
out_is "task dep remove: both gone" "-"
sb task dep EX-6 add EX-2
is "task dep: CRLF kept" "$(grep -c "$CR\$" "$T6")" "$(grep -c '' "$T6")"
line_is "task dep: CRLF line written" "$T6" "  - \"[[$P/tasks/EX-2/README|EX-2]]\"$CR"
sb task dep EX-6 remove EX-2

# ---------------------------------------------------------------- result
result
