#!/usr/bin/env bash
# Area spec: spec, spec new, validation and validation new, spec tasks, tick, packet and link, and
# a project's own templates.
# Usage: bash scripts/test.sh spec, or bash scripts/tests/spec.sh
. "$(dirname "$0")/lib.sh"

sb scaffold vault
# The build step of the spec skill, which docs.sh reads too.
BM="$here/skills/spec/build.md"

# ---------------------------------------------------------------- spec-driven delivery
sb help
out_has "help: lists spec" "spec <ID> | spec new <ID> | spec tasks <ID>   (each takes --project P)"
out_has "help: lists spec tick and packet" "spec tick <ID> <task> | spec packet <ID> <task>"
out_has "help: lists validation" "validation <project> [repo] [--path DIR] | validation new <project> <repo>"
S="work/specs"
SPF="$vault/$S/claude/profile.md"
mkdir -p "$tmp/scode/spec-app" "$tmp/scode/spec-infra"
sb scaffold project Specs --path "$S" --keys SP
out_has "validation: scaffold project writes claude/validation.md" "$S/claude/validation.md"
line_is "validation: the note is typed" "$vault/$S/claude/validation.md" "type: validation"
line_is "validation: the note links up to the Claude hub" "$vault/$S/claude/validation.md" "> Up: [[$S/claude/README|Specs Claude Hub]]"
file_has "validation: the note holds one section per repo" "$vault/$S/claude/validation.md" 'code, in one `## <repo>` section per repo.'
line_is "validation: the note names the command agents read it with" "$vault/$S/claude/validation.md" 'section with `second-brain validation "Specs" <repo>` before they build or review a change.'
line_is "validation: the note names validation new" "$vault/$S/claude/validation.md" '`second-brain validation new "Specs" <repo>` adds a missing section.'
file_has "validation: the Claude hub links to it" "$vault/$S/claude/README.md" "[[$S/claude/validation|Specs Validation]]"
for k in "delivery: direct" "spec_home: vault" "validation_home: vault"; do
  line_is "profile template: $k" "$SPF" "$k"
done
sb validation Specs
rc_is "validation: a project with no repo exits 0" 0
out_is "validation: and prints no row" ""
edit "$SPF" "s|^repos: \\[\\]\$|repos: [spec-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/scode\"|"
sb task new SP-1 --project Specs --title "First spec"
sb spec SP-1
rc_is "spec: exit 0" 0
out_is "spec: the vault home by default, in the task's folder" "id: SP-1
delivery: direct
spec_home: vault
repo: spec-app
dir: $S/tasks/SP-1/spec
requirements: $S/tasks/SP-1/spec/requirements.md
design: $S/tasks/SP-1/spec/design.md
tasks: $S/tasks/SP-1/spec/tasks.md"
sb spec new SP-1
rc_is "spec new: exit 0" 0
out_is "spec new: names the three files it wrote" "$S/tasks/SP-1/spec/requirements.md
$S/tasks/SP-1/spec/design.md
$S/tasks/SP-1/spec/tasks.md"
SPR="$vault/$S/tasks/SP-1/spec/requirements.md"
line_is "spec new: a vault spec file has its alias" "$SPR" '  - "SP-1 Requirements"'
line_is "spec new: and the spec type" "$SPR" "type: spec"
line_is "spec new: and links up to the task" "$SPR" "> Up: [[$S/tasks/SP-1/README|SP-1]]"
file_has "spec new: the task's title is filled in" "$SPR" "What First spec must do."
line_is "spec new: requirements open at R1" "$SPR" "## R1 - <short name>"
SERVES="- Serves: <AC1, AC3: the story's criteria it meets>"
is "spec new: the Serves line is the first under R1" "$(section_of "$SPR" "R1 - <short name>" | head -1)" "$SERVES"
line_is "spec new: the requirement is in the WHEN form" "$SPR" "<WHEN a trigger, THE part of the system SHALL respond so.>"
line_is "spec new: the tasks file has the task line" "$vault/$S/tasks/SP-1/spec/tasks.md" "- [ ] T1 - <What the task builds.>"
line_is "spec new: and its requirements line" "$vault/$S/tasks/SP-1/spec/tasks.md" "  - Requirements: <R1, R2>"
SPD="$vault/$S/tasks/SP-1/spec/design.md"
line_is "spec new: the design keeps the headings a task names" "$SPD" "How First spec is built. Keep each heading short, and never rename or remove one a task names."
for h in "## Context" "## Approach" "## Components" "## Errors and edge cases" "## Testing"; do
  line_is "spec new: the design has $h" "$SPD" "$h"
done
line_is "spec new: the design asks for each part's job" "$SPD" "<Each part added or changed, and its job.>"
echo "kept" >>"$SPR"
sb spec new SP-1
rc_is "spec new again: exit 0" 0
out_is "spec new again: writes nothing" ""
err_has "spec new again: names what exists" "exists: $S/tasks/SP-1/spec/requirements.md"
line_is "spec new again: never overwrites" "$SPR" "kept"
sb unresolved Specs
out_is "spec: the vault spec files' links resolve" ""
sb find SP-1 --project Specs
out_is "spec: the task is still one task" "$S/tasks/SP-1/README.md"
sb task set SP-1 delivery=maybe
rc_is "delivery: task set refuses another value" 5
sb task set SP-1 delivery=spec
rc_is "delivery: task set writes spec" 0
sb spec SP-1
out_has "delivery: the task's own value wins" "delivery: spec"
edit "$SPF" 's/^delivery: direct$/delivery: SPEC/'
sb task set SP-1 delivery=
sb spec SP-1
out_has "delivery: removed, the profile's holds, in any letter case" "delivery: spec"
edit "$SPF" 's/^delivery: SPEC$/delivery: maybe/'
sb spec SP-1
out_has "delivery: a value that is not allowed means direct" "delivery: direct"
edit "$SPF" 's/^delivery: maybe$/delivery: direct/; s/^spec_home: vault$/spec_home: repo/'
sb spec SP-1
out_has "spec_home repo: the folder is spec/<ID> in the repo" "dir: $oT/scode/spec-app/spec/SP-1"
out_has "spec_home repo: the tasks file is in it" "tasks: $oT/scode/spec-app/spec/SP-1/tasks.md"
sb spec new SP-1
out_has "spec_home repo: spec new writes in the repo" "$oT/scode/spec-app/spec/SP-1/requirements.md"
is "spec_home repo: a repo spec file has no frontmatter" "$(head -1 "$tmp/scode/spec-app/spec/SP-1/requirements.md")" "# SP-1 - Requirements"
is "spec_home repo: the Serves line is the first under R1" "$(section_of "$tmp/scode/spec-app/spec/SP-1/requirements.md" "R1 - <short name>" | head -1)" "$SERVES"
file_lacks "spec_home repo: and no up link" "$tmp/scode/spec-app/spec/SP-1/requirements.md" "> Up:"
edit "$SPF" "s|^repos_root: \"$tmp/scode\"\$|repos_root: \"$tmp/nowhere\"|"
sb spec SP-1
rc_is "spec_home repo: a missing repo folder exits 1" 1
err_has "spec_home repo: and says so" "the folder of spec-app is missing"
edit "$SPF" "s|^repos_root: \"$tmp/nowhere\"\$|repos_root: \"\"|"
sb spec SP-1
rc_is "spec_home repo: no recorded location exits 1" 1
err_has "spec_home repo: and says so" "no location is recorded for spec-app"
edit "$SPF" 's|^repos: \[spec-app\]$|repos: []|'
sb spec SP-1
rc_is "spec_home repo: no repo exits 1" 1
err_has "spec_home repo: and says so" "Specs lists no repo for the spec"
edit "$SPF" "s|^repos: \\[\\]\$|repos: [spec-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/scode\"|"
sb scaffold subproject Specs infra --repos spec-infra
SPS="$vault/$S/claude/subprojects/infra.md"
edit "$SPS" 's/^spec_home: ""$/spec_home: vault/; s/^delivery: ""$/delivery: spec/'
sb task set SP-1 subproject=infra
sb spec SP-1
out_has "subproject: its spec_home wins over the profile's" "spec_home: vault"
out_has "subproject: its delivery wins over the profile's" "delivery: spec"
out_has "subproject: the story's repo is the subproject's first" "repo: spec-infra"
sb subproject Specs infra
out_has "subproject: shows the delivery that holds" "delivery: spec"
out_has "subproject: and the validation home, the profile's" "validation_home: vault"
sb spec
rc_is "spec: no id exits 5" 5
sb spec SP-1 SP-2
rc_is "spec: two ids exit 5" 5
sb spec SP-404 --project Specs
rc_is "spec: an unknown task exits 1" 1

# ---------------------------------------------------------------- validation.md
sb validation Specs
out_is "validation: one row per repo, the vault home, no section yet" "spec-app${TAB}vault${TAB}$S/claude/validation.md${TAB}no-section
spec-infra${TAB}vault${TAB}$S/claude/validation.md${TAB}no-section"
sb validation Specs spec-app
rc_is "validation: a repo with no section exits 1" 1
err_has "validation: and names validation new" "has no ## spec-app section: run second-brain validation new"
sb validation new Specs spec-app
rc_is "validation new: exit 0" 0
out_is "validation new: names the file" "$S/claude/validation.md"
line_is "validation new: adds the repo's section" "$vault/$S/claude/validation.md" "## spec-app"
line_is "validation new: with the check as a user would" "$vault/$S/claude/validation.md" "### Check as a user would"
is "validation new: the section holds the template's four parts, word for word" "$(section_of "$vault/$S/claude/validation.md" spec-app)" \
  "### Set up and start
- <The commands that install, build and start it from a fresh clone, in order.>
### Checks
- <One line per command that must pass, such as the tests, linter and build: the command in backticks, then what it proves.>
- <Each line ends with when it runs: when: each task, when: each build, or when: release for one run only before a release or on the owner's ask.>
### Check as a user would
- <One line per step that uses the change as a user does: its tool, then what to look for, then when it runs.>
- <A tool is a skill by name, such as a browser-testing skill, a command, an API call or a query.>
### A pass
- <What a pass needs: every check above passes, the user steps work, nothing else broke.>"
echo "- npm test" >>"$vault/$S/claude/validation.md"
sb validation new Specs SPEC-APP
rc_is "validation new again: exit 0" 0
out_is "validation new again: writes nothing" ""
err_has "validation new again: names what exists" "exists: $S/claude/validation.md"
sb validation Specs Spec-App
rc_is "validation: the repo is matched without letter case" 0
is "validation: the path comes first" "$(printf '%s\n' "$OUT" | head -1)" "path: $S/claude/validation.md"
out_has "validation: then the repo's steps" "### Set up and start"
out_has "validation: to the end of its section" "- npm test"
sb validation Specs nope
rc_is "validation: a repo that is not the project's exits 1" 1
sb validation Specs spec-app extra
rc_is "validation: too many arguments exit 5" 5
sb validation new Specs
rc_is "validation new: no repo exits 5" 5
edit "$SPS" 's/^validation_home: ""$/validation_home: repo/'
sb validation Specs
out_has "validation: a subproject's home wins for its repos" "spec-infra${TAB}repo${TAB}$oT/scode/spec-infra/validation.md${TAB}missing"
out_has "validation: the profile's holds for the others" "spec-app${TAB}vault${TAB}$S/claude/validation.md${TAB}ok"
sb validation new Specs spec-infra
out_is "validation new: a repo home writes at the repo's root" "$oT/scode/spec-infra/validation.md"
is "validation new: a repo file opens with its title" "$(head -1 "$tmp/scode/spec-infra/validation.md")" "# spec-infra validation"
line_is "validation new: then the repo's section" "$tmp/scode/spec-infra/validation.md" "## spec-infra"
file_lacks "validation new: a repo file has no frontmatter" "$tmp/scode/spec-infra/validation.md" "type: validation"
sb validation Specs
out_has "validation: the repo file is ok" "spec-infra${TAB}repo${TAB}$oT/scode/spec-infra/validation.md${TAB}ok"
rm -rf "$tmp/scode/spec-infra"
sb validation Specs spec-infra
rc_is "validation: a repo home whose folder is missing exits 1" 1
err_has "validation: and says so" "the folder of spec-infra is missing"
sb scaffold project Specs --path "$S" --keys SP
err_has "validation: a second scaffold leaves the note alone" "exists: $S/claude/validation.md"
VS="$here/skills/vault-setup/SKILL.md"
file_has "vault-setup: lists the validation mode" "$VS" '| validation <project> | link]'
file_has "vault-setup: asks for delivery, a fallback" "$VS" \
  '| `delivery` | what a story with no `delivery` of its own falls back to, as `### Profile'
file_has "vault-setup subproject: delivery is a fallback" "$here/skills/vault-setup/subproject.md" \
  '- `delivery` is a fallback, as `### Profile frontmatter` in `docs/contract.md` says.'
file_has "vault-setup: asks for spec_home" "$VS" '| `spec_home` | with `spec`:'
file_has "vault-setup: asks for validation_home" "$VS" '| `validation_home` | whether `validation.md`'
file_has "vault-setup: project mode ends with the validation steps" "$VS" "10. Write each repo's validation steps as"
file_has "vault-setup validation: never invents a step" "$here/skills/vault-setup/validation.md" "Never invent a step."
file_has "vault-setup validation: writes only what the user confirms" "$here/skills/vault-setup/validation.md" "Write only what they confirm"
file_has "vault-setup repo: a new repo gets its validation steps" "$here/skills/vault-setup/repo.md" "Write the repository's validation steps"

# ---------------------------------------------------------------- spec and validation edge cases
sb validation Specs nope
rc_is "validation: an unknown repo exits 1" 1
out_is "validation: and prints nothing" ""
sb validation new Specs nope
rc_is "validation new: an unknown repo exits 1" 1
out_is "validation new: and writes nothing" ""
sb validation Specs --x
rc_is "validation: a flag as the second argument exits 5" 5
sb validation new Specs -h
rc_is "validation new: a flag exits 5" 5
sb task set SP-1 delivery=Spec
rc_is "delivery: task set takes any letter case" 0
line_is "delivery: and writes it in lower case" "$vault/$S/tasks/SP-1/README.md" "delivery: spec"
sb task set SP-1 delivery=
# The vault note in CRLF: a new section keeps the line endings, after one blank line.
VN="$vault/$S/claude/validation.md"
edit "$SPF" 's|^repos: \[spec-app\]$|repos: [spec-app, spec-web]|'
mkdir -p "$tmp/scode/spec-web"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$VN" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$VN"
sb validation new Specs spec-web
rc_is "validation new: a CRLF note takes a new section" 0
is "validation new: every line keeps its CRLF" "$(grep -vc "$CR\$" "$VN" || true)" "0"
is "validation new: one blank line before the new section" \
  "$(awk '{ sub(/\r$/, "") } $0 == "## spec-web" { print prev } { prev = $0 }' "$VN")" ""
is "validation new: and not two" \
  "$(awk '{ sub(/\r$/, "") } $0 == "## spec-web" { print p2 } { p2 = prev; prev = $0 }' "$VN" | grep -c . || true)" "1"
# A section with nothing under its heading is empty, not written.
edit "$SPF" 's|^repos: \[spec-app, spec-web\]$|repos: [spec-app, spec-web, spec-gone]|'
printf '\r\n## spec-gone\r\n' >>"$VN"
sb validation Specs
out_has "validation: a section with nothing under it is empty" "spec-gone${TAB}vault${TAB}$S/claude/validation.md${TAB}empty"
sb validation new Specs spec-gone
err_has "validation new: an empty section is left alone" "exists: $S/claude/validation.md"
edit "$SPF" 's|^repos: \[spec-app, spec-web, spec-gone\]$|repos: [spec-app]|'
# The story's repo: with no repo in the profile, the project's first repo, a subproject's.
P3="work/subonly"
mkdir -p "$tmp/socode/so-api"
sb scaffold project SubOnly --path "$P3" --keys SO
edit "$vault/$P3/claude/profile.md" "s|^repos_root: \"\"\$|repos_root: \"$tmp/socode\"|; s|^spec_home: vault\$|spec_home: repo|"
sb scaffold subproject SubOnly api --repos so-api
sb task new SO-1 --project SubOnly --title "No subproject"
sb spec SO-1
rc_is "spec: a project whose only repo is a subproject's exits 0" 0
out_has "spec: and the story's repo is that repo" "repo: so-api"
# A repo home in the profile: no hub link, and no vault note.
P4="work/repohome"
mkdir -p "$vault/$P4/claude"
printf -- '---\ntype: profile\nvalidation_home: repo\n---\n' >"$vault/$P4/claude/profile.md"
sb scaffold project RepoHome --path "$P4" --keys RH
out_lacks "validation: a repo home writes no vault note" "$P4/claude/validation.md"
file_lacks "validation: and the Claude hub does not link to one" "$vault/$P4/claude/README.md" "claude/validation|"
sb unresolved RepoHome
out_is "validation: so the hub's links resolve" ""

# ---------------------------------------------------------------- spec tasks, tick and packet
SD="$vault/$S/tasks/SP-1/spec"
edit "$SPF" 's/^spec_home: repo$/spec_home: vault/'
sb task set SP-1 subproject= branch=feature/SP-1-first
printf '%s\n' '# SP-1 - Requirements' '' '## R1 - Login form' '' 'WHEN a user opens the page, THE app SHALL show a form.' '' \
  '- [ ] The form has two fields.' '' '## R2 - Bad password' '' 'IF the password is wrong, THEN the app SHALL say so.' '' '## R3 - Unused' '' 'Left out.' >"$SD/requirements.md"
printf '%s\n' '# SP-1 - Design' '' '## Approach' '' 'A new route.' '' '## Components' '' 'The form.' '' '## Testing' '' 'A browser check.' >"$SD/design.md"
printf '%s\n' '# SP-1 - Tasks' '' '- [ ] T1 - The login form' '  - Requirements: R1' '  - Design: Approach, components' '  - Files: src/login.ts' \
  '  - Check: open /login - expected: shows `Sign in: email, password`' '' \
  '- [x] T2 - The error' '  - Requirements: R2, R9' '  - Design: Approach' '- [ ] T3 - Nothing named' '  - Requirements: <R1, R2>' '- [ ] T4 - No design' '  - Requirements: r2' '  - Design: none' >"$SD/tasks.md"
sb spec tasks SP-1
rc_is "spec tasks: exit 0" 0
out_is "spec tasks: one row per item, in order, with no bundle as -" "T1${TAB}todo${TAB}The login form${TAB}-
T2${TAB}done${TAB}The error${TAB}-
T3${TAB}todo${TAB}Nothing named${TAB}-
T4${TAB}todo${TAB}No design${TAB}-"
sb spec packet SP-1 t1
rc_is "spec packet: exit 0, the task matched without letter case" 0
is "spec packet: the header lines first" "$(printf '%s\n' "$OUT" | head -7)" "story: SP-1
task: T1
title: The login form
repo: spec-app
repo_path: $oT/scode/spec-app
branch: feature/SP-1-first
validation: $S/claude/validation.md"
out_has "spec packet: the item as written" "  - Files: src/login.ts"
out_has "spec packet: the check and its expected result, as written" \
  '  - Check: open /login - expected: shows `Sign in: email, password`'
out_has "spec packet: the requirement it names, with its checks" "### R1 - Login form

WHEN a user opens the page, THE app SHALL show a form.

- [ ] The form has two fields."
out_lacks "spec packet: no requirement it does not name" "R2 - Bad password"
out_has "spec packet: each design heading it names, without letter case" "### Approach

A new route.

### Components

The form."
out_lacks "spec packet: no design heading it does not name" "### Testing"
out_has "spec packet: the repo's validation steps" "## Validation

### Set up and start"
out_lacks "spec packet: no other task" "T2 - The error"
out_has "spec packet: names the task's check first, and no each-task line when the section has no command" "## Checks

- task: open /login - expected: shows \`Sign in: email, password\`

## Validation"
sb spec packet SP-1 T2
rc_is "spec packet: a requirement with no section exits 1" 1
err_has "spec packet: and names it" "T2 names R9, which $S/tasks/SP-1/spec/requirements.md has no section for"
sb spec packet SP-1 T3
rc_is "spec packet: a task that names no requirement exits 1" 1
sb spec packet SP-1 T4
rc_is "spec packet: a task with no design exits 0" 0
out_lacks "spec packet: and has no design part" "## Design"
out_has "spec packet: a requirement id is matched without letter case" "### R2 - Bad password"
sb spec packet SP-1 T9
rc_is "spec packet: an unknown task exits 1" 1
sb spec packet SP-1
rc_is "spec packet: no task exits 5" 5
CRT="$SD/tasks.md"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$CRT" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$CRT"
sb spec tick SP-1 T1
rc_is "spec tick: exit 0" 0
out_is "spec tick: names the task" "ticked: T1"
line_is "spec tick: the box is ticked" "$CRT" "- [x] T1 - The login form$CR"
is "spec tick: every line keeps its CRLF" "$(grep -vc "$CR\$" "$CRT" || true)" "0"
sb spec tick SP-1 T1
rc_is "spec tick: a ticked task exits 6" 6
sb spec tick SP-1 T9
rc_is "spec tick: an unknown task exits 1" 1
sb spec tasks SP-1
out_has "spec tasks: the ticked task is done" "T1${TAB}done${TAB}The login form${TAB}-"
mv "$CRT" "$tmp/tasks.md.away"
sb spec tasks SP-1
rc_is "spec tasks: no tasks.md exits 1" 1
err_has "spec tasks: and names spec new" "run second-brain spec new SP-1"
mv "$tmp/tasks.md.away" "$CRT"

# ---------------------------------------------------------------- spec tasks: review edge cases
printf '%s\n' '# SP-1 - Tasks' '' 'An example:' '' '```' '- [ ] T1 - Example' '```' '' '- [ ] T1 - The real one' '  - Requirements: R1' '  - Design: None' \
  '  - Check: run it' '    ```sh' '#!/bin/sh' '    ```' '  - Files: a.sh' '- [ ] T2: Colon form' '  - Requirements: R1,' '- [ ] T5 - Twice' '  - Requirements: R1' '- [ ] T5 - Twice again' '  - Requirements: R1' >"$CRT"
sb spec tasks SP-1
out_is "spec tasks: fenced code is not read, and T2: is a task" "T1${TAB}todo${TAB}The real one${TAB}-
T2${TAB}todo${TAB}Colon form${TAB}-
T5${TAB}todo${TAB}Twice${TAB}-
T5${TAB}todo${TAB}Twice again${TAB}-"
sb spec packet SP-1 T1
rc_is "spec packet: Design: None names no section, in any letter case" 0
out_has "spec packet: a fence inside the item keeps the lines after it" "  - Files: a.sh"
sb spec packet SP-1 T2
rc_is "spec packet: a field that ends in a comma exits 1" 1
err_has "spec packet: and says to write it on one line" "write each field of a task on one line"
sb spec packet SP-1 T5
rc_is "spec packet: two items with one id exit 1" 1
err_has "spec packet: and say so" "have the id T5"
sb spec tick SP-1 T5
rc_is "spec tick: two items with one id exit 1" 1
sb spec tick SP-1 T1
line_is "spec tick: the fenced example is left alone" "$CRT" "- [ ] T1 - Example"
line_is "spec tick: the real item is ticked" "$CRT" "- [x] T1 - The real one"

# ---------------------------------------------------------------- spec tasks: bundles
printf '%s\n' '# SP-1 - Tasks' '' 'Tasks with the same `- Bundle: <n>` line are one bundle.' '' '```' '- [ ] T1 - Example' '  - Bundle: 7' '```' '' \
  '- [ ] T1 - Alone' '  - Requirements: R1' \
  '- [ ] T2 - First of two' '  - Requirements: R1' '  - Bundle: 1' \
  '- [x] T3 - Second of two' '  - Requirements: R1' '  - bundle: 01' '  - Bundle: 9' \
  '- [ ] T4 - None named' '  - Requirements: R1' '  - Bundle: None' \
  '- [ ] T5 - The template' '  - Requirements: R1' '  - Bundle: <n>' \
  '- [ ] T6 - Another bundle' '  - Requirements: R1' '  - Bundle: 2' \
  '- [ ] T7 - Its second' '  - Requirements: R1' '  - Bundle: 2' \
  '- [ ] T8 - Last' '  - Requirements: R1' '' 'Notes:' '  - Bundle: 5' >"$CRT"
sb spec tasks SP-1
rc_is "spec tasks: a bundled list exits 0" 0
out_is "spec tasks: each task's bundle last, from its own first Bundle line, as a number" "T1${TAB}todo${TAB}Alone${TAB}-
T2${TAB}todo${TAB}First of two${TAB}1
T3${TAB}done${TAB}Second of two${TAB}1
T4${TAB}todo${TAB}None named${TAB}-
T5${TAB}todo${TAB}The template${TAB}-
T6${TAB}todo${TAB}Another bundle${TAB}2
T7${TAB}todo${TAB}Its second${TAB}2
T8${TAB}todo${TAB}Last${TAB}-"
text="$OUT"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$CRT" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$CRT"
sb spec tasks SP-1
is "spec tasks: CRLF line endings read the same" "$OUT" "$text"
sb spec tasks SP-1 --json
json_ok "spec tasks --json: a bundled list parses as JSON"
out_has "spec tasks --json: the bundle is a string" '{"id": "T2", "state": "todo", "title": "First of two", "bundle": "1"}'
sb spec packet SP-1 T2
rc_is "spec packet: a bundled task builds its packet" 0
out_has "spec packet: and shows its Bundle line as written" "  - Bundle: 1"
printf '%s\n' '# SP-1 - Tasks' '' '- [ ] T1 - One' '  - Requirements: R1' '  - Bundle: 1' \
  '- [ ] T2 - Two' '  - Requirements: R1' '  - Bundle: two' '- [ ] T3 - Three' '  - Requirements: R1' '  - Bundle: x' >"$CRT"
sb spec tasks SP-1
rc_is "spec tasks: a bundle that is no whole number exits 1" 1
out_is "spec tasks: and prints no row" ""
err_has "spec tasks: and names the first such task" "T2 has the bundle two in $S/tasks/SP-1/spec/tasks.md: a bundle is a whole number"
sb spec tasks SP-1 --json
rc_is "spec tasks --json: a bad bundle exits 1 too" 1
out_is "spec tasks --json: and prints nothing" ""
printf '%s\n' '# SP-1 - Tasks' '' '- [ ] T1 - One' '  - Requirements: R1' '  - Bundle: 1' \
  '- [ ] T2 - Two' '  - Requirements: R1' '- [ ] T3 - Three' '  - Requirements: R1' '  - Bundle: 1' >"$CRT"
sb spec tasks SP-1
rc_is "spec tasks: a bundle split by another task exits 1" 1
out_is "spec tasks: and prints no row either" ""
err_has "spec tasks: and names the task out of place" \
  "T3 is in bundle 1, but the task before it is not: put a bundle's tasks next to each other in $S/tasks/SP-1/spec/tasks.md"
printf '%s\n' '# SP-1 - Tasks' '' '- [ ] T1 - One' '  - Requirements: R1' '  - Provides: one()' \
  '- [ ] T2 - Two' '  - Requirements: R1' '  - Uses: T1' '  - Bundle: 1' '- [ ] T3 - Three' '  - Requirements: R1' '  - Bundle: 1' '  - uses: none' \
  '- [ ] T4 - Four' '  - Requirements: R1' '  - Provides: four()' '  - Bundle: 2' '- [ ] T5 - Five' '  - Requirements: R1' '  - Bundle: 2' '  - Uses: t2, T4' >"$CRT"
sb spec tasks SP-1
rc_is "spec tasks: a task that uses a task of its own bundle exits 1" 1
out_is "spec tasks: and prints no row" ""
err_has "spec tasks: and names both tasks and the bundle" \
  "T5 uses T4, which is in its own bundle 2: move one of them out of the bundle in $S/tasks/SP-1/spec/tasks.md"
edit "$CRT" 's/^  - Uses: t2, T4$/  - Uses: t2, T1/'
sb spec tasks SP-1
rc_is "spec tasks: a task may use a task of another bundle, or of none" 0
out_has "spec tasks: and lists each bundle" "T5${TAB}todo${TAB}Five${TAB}2"
printf '\n## R1 - Again\n' >>"$SD/requirements.md"
printf '%s\n' '# SP-1 - Tasks' '' '- [ ] T1 - One' '  - Requirements: R1' >"$CRT"
sb spec packet SP-1 T1
rc_is "spec packet: a requirement with two sections exits 1" 1
err_has "spec packet: and names it" "has two sections for R1"
edit "$SPF" 's/^spec_home: vault$/spec_home: repo/'
edit "$SPF" "s|^repos_root: \"$tmp/scode\"\$|repos_root: \"\"|"
sb spec SP-1
rc_is "spec: a repo spec with no recorded location still exits 1" 1
out_has "spec: but prints the delivery first" "delivery: direct"
out_has "spec: and the folder as -" "dir: -"
edit "$SPF" "s|^repos_root: \"\"\$|repos_root: \"$tmp/scode\"|; s/^spec_home: repo$/spec_home: vault/"
for a in implementer reviewer spec-checker; do
  line_is "$a: loads no CLAUDE.md" "$here/agents/$a.md" "omitClaudeMd: true"
done
file_has "spec build: read only once all three approvals count" "$BM" 'Read this file only when all three approvals count'
line_is "spec build: a BLOCKED review stops at once" "$BM" '5. BLOCKED: first the stop note,'
file_has "spec build: a BLOCKED build stops, unless a ruling settles it" "$BM" '4. Its reply starts with `BLOCKED:`, or no commit was found: a stop, unless a ruling settles it.'
file_has "spec build: and any other BLOCKED stops at once" "$BM" '   - Any other, or the same question again after its ruling: first the stop note,'
file_has "spec build: a lone task with no commit line is looked for by its commit first" "$BM" \
  '3. Its reply has no `Commit:` line, and does not start with `BLOCKED:`: look for its commit'
file_has "spec build: a resumed failed task with a built fix goes to review" "$BM" \
  '- A `fix` in `spec status` that is not `-`: its fix was built before the session ended.'
is "spec build: a built fix is reviewed before any new fix round" \
  "$(($(lineno "$BM" '- A `fix` in `spec status` that is not `-`: its fix was built') < $(lineno "$BM" '- `fails` 5 or less: `### The fix loop`, with its ruling lines')))" "1"
file_has "spec build: a fix round's reply is taken as for a build" "$BM" '3. Take its reply as items 3 to 5 of `### Build it` say.'
file_has "contract: a lone task with no commit line is looked for by its commit" "$here/docs/contract.md" \
  '- A task whose reply names no commit, and that did not stop, is looked for by its commit in the'
file_has "contract: a failed task with a built fix goes to review" "$here/docs/contract.md" \
  'session ended. It goes to the review of its fix, not to a new fix round.'
file_has "contract: spec status names the fix" "$here/docs/contract.md" '- commits <hashes or -> - fix <hashes or -> - <title>`'
file_has "changelog: spec status names the fix" "$here/CHANGELOG.md" '- `spec status` names each task'"'"'s `fix`'
is "spec build: each block writes the stop note before it sets blocked" \
  "$(awk '/stopped at <task>: <why>\."`, then$/ { n = NR } /^ +`second-brain spec status <ID> <task> blocked`, and stop\.$/ && n == NR - 1 { k++ } END { print k + 0 }' "$BM")" "2"
is "spec build: and nothing sets blocked any other way" "$(grep -c 'spec status <ID> <task> blocked`' "$BM")" "2"
file_has "spec build: commits the tick of a repo spec" "$BM" 'commit -m "<ID> <task>: passed review" -- spec/<ID>/tasks.md'
file_has "spec build: a session resumes the build from build.json" "$BM" \
  'It prints a line: the build resumes, from the states `build.json` in the story'"'"'s folder'
file_has "reviewer: a BLOCKED verdict" "$here/agents/reviewer.md" '- `BLOCKED`: a step could not be run'
file_has "implementer: reads nothing outside the repo" "$here/agents/implementer.md" 'Read nothing outside `repo_path`'
file_has "spec skill: a reopened phase voids later approvals" "$here/skills/spec/SKILL.md" 'only when it is newer than every `reopened` note'
file_has "spec build: commits a repo spec before the build" "$BM" 'commit -m "<ID>: spec"'

# ---------------------------------------------------------------- spec link
sb help
out_has "help: lists spec link" "spec packet <ID> <task> | spec link <ID>"
for n in 2 3 4 5; do sb task new "SP-$n" --project Specs --title "Linked $n"; done
for n in 2 3 5; do sb task set "SP-$n" delivery=spec; sb spec new "SP-$n"; done
L2="$vault/$S/tasks/SP-2/README.md"
sb spec link SP-2
rc_is "spec link: exit 0" 0
out_is "spec link: names each section it changed" "linked: Approach / Key decisions
linked: Changes
linked: Verification"
is "spec link: the design link opens Approach, the template text gone" \
  "$(awk '/^## Approach/ { on = 1; next } on && /^## / { exit } on' "$L2")" "
See [[$S/tasks/SP-2/spec/design|SP-2 Design]]."
is "spec link: the tasks link replaces None yet. in Changes" \
  "$(awk '/^## Changes/ { on = 1; next } on && /^## / { exit } on' "$L2")" "
See [[$S/tasks/SP-2/spec/tasks|SP-2 Tasks]]."
line_is "spec link: and opens Verification" "$L2" "See [[$S/tasks/SP-2/spec/tasks|SP-2 Tasks]]."
sb unresolved Specs
out_is "spec link: its links resolve" ""
cp "$L2" "$tmp/sp2.before"
sb spec link SP-2
out_is "spec link again: no change" "no change"
if cmp -s "$L2" "$tmp/sp2.before"; then pass "spec link again: the README is byte-identical"; else fail "spec link again: the README is byte-identical"; fi
L3="$vault/$S/tasks/SP-3/README.md"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$L3" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$L3"
sb spec link SP-3
rc_is "spec link: a CRLF README takes the links" 0
is "spec link: every line keeps its CRLF" "$(grep -vc "$CR\$" "$L3" || true)" "0"
L4="$vault/$S/tasks/SP-4/README.md"
cp "$L4" "$tmp/sp4.before"
sb spec link SP-4
out_is "spec link: a direct story is not built from a spec" "no change: SP-4 is not built from a spec (delivery: direct)"
if cmp -s "$L4" "$tmp/sp4.before"; then pass "spec link: a direct story's README is byte-identical"; else fail "spec link: a direct story's README is byte-identical"; fi
L5="$vault/$S/tasks/SP-5/README.md"
awk '{ print } /^## Approach \/ Key decisions$/ { getline; print; getline; print "- Keep this decision."; next }' "$L5" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$L5"
sb spec link SP-5
is "spec link: other text stays under the link" \
  "$(awk '/^## Approach/ { on = 1; next } on && /^## / { exit } on' "$L5" | head -4)" "
See [[$S/tasks/SP-5/spec/design|SP-5 Design]].

- Keep this decision."
rm "$vault/$S/tasks/SP-5/spec/design.md"
sb spec link SP-5
rc_is "spec link: a missing design.md exits 1" 1
edit "$SPF" 's/^spec_home: vault$/spec_home: repo/'
sb task new SP-6 --project Specs --title "Repo link"
sb task set SP-6 delivery=spec
sb spec new SP-6
sb spec link SP-6
line_is "spec link: a repo spec names the file and the repo" "$vault/$S/tasks/SP-6/README.md" 'See `spec/SP-6/design.md` in the `spec-app` repo.'
edit "$SPF" 's/^spec_home: repo$/spec_home: vault/'
file_has "spec skill: runs spec link after the tasks approval" "$here/skills/spec/SKILL.md" 'After the tasks note, run `second-brain spec link <ID>`'
file_has "spec phases: each requirement opens with its Serves line" "$here/skills/spec/phases.md" 'Each section opens with `- Serves: AC1, AC3`'
file_has "spec phases: every criterion is served" "$here/skills/spec/phases.md" 'Every criterion of the story is named on a `- Serves:` line'
file_has "spec phases: the doctor checks the trace" "$here/skills/spec/phases.md" 'its `spec-trace` row must name'

# ---------------------------------------------------------------- a project's own templates
OT="$vault/$S/claude/templates"
# A story made from the plugin's template before the project has its own.
sb task new SP-24 --project Specs --title "Made before"
O24="$vault/$S/tasks/SP-24/README.md"
mkdir -p "$OT"
cat >"$OT/task-readme.md.tmpl" <<'TMPL'
---
aliases:
  - {{ID}}
title: "{{TITLE}}"
status: planned
next: "Frame the story"
branch: "none yet"
epic: "-"
type: task
tags:
{{TOPIC_TAGS}}
  - type/task
  - status/active
---

> Up: {{UP_LINK}}

# {{ID}} - {{TITLE}}

## Ticket markup

<The markup this project's tracker keeps.>

## Approach / Key decisions

- <A decision of this project, and its reason.>

## Changes

## Verification

## Status notes

## Discovery log
TMPL
sb task new SP-21 --project Specs --title "Own shape"
rc_is "own template: task new exits 0" 0
O21="$vault/$S/tasks/SP-21/README.md"
is "own template: task new fills the project's template" "$(grep '^## ' "$O21" | tr '\n' '|')" \
  "## Ticket markup|## Approach / Key decisions|## Changes|## Verification|## Status notes|## Discovery log|"
line_is "own template: its placeholders are filled" "$O21" "# SP-21 - Own shape"
line_is "own template: the up link is the tasks hub's" "$O21" "> Up: [[$S/tasks/README|Specs Tasks Hub]]"
line_is "own template: the title is quoted as task new writes it" "$O21" 'title: "Own shape"'
sb task note SP-21 "Shaped by the project" --session own
line_is "own template: task note writes under its Status notes" "$O21" '**2026-10-08 (session `own`) - Shaped by the project**'
sb task set SP-21 delivery=spec
sb spec new SP-21
sb spec link SP-21
is "own template: spec link reads the project's template text, so the link stands alone" \
  "$(awk '/^## Approach/ { on = 1; next } on && /^## / { exit } on' "$O21")" "
See [[$S/tasks/SP-21/spec/design|SP-21 Design]]."
sb task set SP-24 delivery=spec
sb spec new SP-24
sb spec link SP-24
is "own template: spec link still reads the plugin's template text in a story made before the project's" \
  "$(awk '/^## Approach/ { on = 1; next } on && /^## / { exit } on' "$O24")" "
See [[$S/tasks/SP-24/spec/design|SP-24 Design]]."
is "own template: and in its Changes section" \
  "$(awk '/^## Changes/ { on = 1; next } on && /^## / { exit } on' "$O24")" "
See [[$S/tasks/SP-24/spec/tasks|SP-24 Tasks]]."
printf '%s\n' '{{TEAM}}' >>"$OT/task-readme.md.tmpl"
sb task new SP-22 --project Specs --title "Unknown placeholder"
rc_is "own template: a placeholder the plugin's lacks exits 5" 5
err_has "own template: the message names the project's template" "$S/claude/templates/task-readme.md.tmpl"
absent "own template: nothing is written on refusal" "$vault/$S/tasks/SP-22/README.md"
: >"$OT/task-readme.md.tmpl"
sb task new SP-26 --project Specs --title "Empty template"
rc_is "own template: an empty template exits 5" 5
err_has "own template: and the message names it" "$S/claude/templates/task-readme.md.tmpl"
absent "own template: an empty template leaves no task folder" "$vault/$S/tasks/SP-26"
printf '%s\n' '# {{ID}} - {{TITLE}}' '' '## Status notes' '' '## Discovery log' >"$OT/task-readme.md.tmpl"
mkdir -p "$vault/$S/tasks/SP-27"
sb task new SP-27 --project Specs --title "No frontmatter"
rc_is "own template: a template with no frontmatter exits 5" 5
err_has "own template: the message says the README has no frontmatter" "no frontmatter"
absent "own template: a template with no frontmatter leaves no README" "$vault/$S/tasks/SP-27/README.md"
exists "own template: a folder that was there before stays" "$vault/$S/tasks/SP-27"
rmdir "$vault/$S/tasks/SP-27"
rm "$OT/task-readme.md.tmpl"
printf '%s\n' 'The project shape of a ticket.' >"$OT/ticket-description.md.tmpl"
sb task new SP-23 --project Specs --title "Plugin shape"
rc_is "own template: with none, task new exits 0" 0
is "own template: with none in the folder, task new fills the plugin's" "$(grep '^## ' "$vault/$S/tasks/SP-23/README.md" | tr '\n' '|')" \
  "## Description|## Findings|## Acceptance criteria|## Approach / Key decisions|## Code verification (read-only)|## Changes|## Verification|## Status notes|## Discovery log|"
awk '/^## Status notes$/ { print "```"; print; print "```"; print "" } { print }' "$here/templates/task-readme.md.tmpl" >"$OT/task-readme.md.tmpl"
sb doctor Specs
is "own template: a fenced heading before the real one passes the doctor" "$(printf '%s\n' "$OUT" | grep ' | task-template | Specs | ' | cut -d'|' -f1-4)" \
  "ok | task-template | Specs | 0 "
sb task new SP-25 --project Specs --title "Fenced example"
O25="$vault/$S/tasks/SP-25/README.md"
sb task note SP-25 "Under the real heading" --session own
is "own template: task note leaves the fenced heading alone" "$(awk '/^```$/ { f = !f; print; next } f' "$O25")" \
  "$(printf '%s\n' '```' '## Status notes' '```')"
n25="$(grep -n '^## Status notes$' "$O25" | sed -n 2p | cut -d: -f1)"
is "own template: task note writes under the real heading, as the doctor finds it" "$(sed -n "$((n25 + 2))p" "$O25")" \
  '**2026-10-08 (session `own`) - Under the real heading**'
sb task head SP-25
out_has "own template: task head reads the newest note under the real heading, not in fenced code" \
  'last_note: **2026-10-08 (session `own`) - Under the real heading**'
# The index row writer still reads its table as written, so the rule names the commands that keep it.
line_is "contract: the commands that take no fenced heading are named" "$here/docs/contract.md" \
  '- `task note`, `task head`, `task new --envs`, `sprint open`, `sprint close` and'
file_lacks "contract: no rule for every command that the index writer breaks" "$here/docs/contract.md" \
  'No command takes a line in fenced code'
file_has "changelog: names the commands that take no fenced heading" "$here/CHANGELOG.md" \
  '- `task note`, `task head`, `task new --envs`, `sprint open`, `sprint close` and'
file_lacks "changelog: no rule for every command" "$here/CHANGELOG.md" 'is never the one a command writes under'
grep -v '^next: \|^## Discovery log$' "$here/templates/task-readme.md.tmpl" >"$OT/task-readme.md.tmpl"
sb doctor Specs
is "own template: the doctor warns on a template that lacks a key or a section the helper writes" \
  "$(printf '%s\n' "$OUT" | grep ' | task-template | Specs | ')" \
  "warn | task-template | Specs | 2 | next, ## Discovery log | add them to claude/templates/task-readme.md.tmpl, as the plugin's templates/task-readme.md.tmpl has them"
case "$OT" in "$vault"/?*/claude/templates) rm -r "$OT" ;; esac

# ---------------------------------------------------------------- result
result
