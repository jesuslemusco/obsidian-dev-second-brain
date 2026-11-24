#!/usr/bin/env bash
# Area scaffold: scaffold vault, and scaffold project with its roots and without sprints.
# Usage: bash scripts/test.sh scaffold, or bash scripts/tests/scaffold.sh
. "$(dirname "$0")/lib.sh"

# ---------------------------------------------------------------- scaffold vault
sb scaffold vault
rc_is "scaffold vault: exit 0" 0
out_is "scaffold vault: lists the five files" "CLAUDE.md
obsidian-conventions.md
claude/README.md
claude/pull-request.md
claude/writing-style.md"
exists "scaffold vault: index" "$vault/CLAUDE.md"
exists "scaffold vault: conventions" "$vault/obsidian-conventions.md"
exists "scaffold vault: vault Claude hub" "$vault/claude/README.md"
is "pull request format: the goal first, then the four headings, in order and bold" "$(grep '^## \*\*' "$vault/claude/pull-request.md" | tr '\n' '|')" \
  "## **Goal**|## **What was changed?**|## **What was added?**|## **Dependencies:**|## **Risks:**|"
is "pull request format: every bullet of the format starts with a bold label" \
  "$(awk '/^```/ { on = !on; next } on && /^- / { n++; if (/^- \*\*<part>:\*\* </) b++ } END { print b + 0 "/" n + 0 }' "$vault/claude/pull-request.md")" "4/4"
is "pull request format: the goal is one or two lines, not a bullet" \
  "$(awk '/^## \*\*Goal\*\*$/ { on = 1; next } /^## / { on = 0 } on && NF' "$vault/claude/pull-request.md")" \
  "<why this pull request exists, in one or two lines>"
is "pull request format: the rules, word for word" "$(section_of "$vault/claude/pull-request.md" 'The rules')" \
  "- Write the description only from \`git log <target>..<source>\` and
  \`git diff <target>...<source>\`, never from memory of the work.
- \`<source>\` is the branch that holds the work. \`<target>\` is the branch it merges into, as the
  remote has it after a \`git fetch\`: usually \`origin/main\`.
- Name both branches in the commands: the checkout may be on another one.
- Use the five bold headings below, in this order, and no others.
- Under each heading after \`Goal\`, write a few bullets in short plain English, one line each.
- Start each bullet with the part it is about, in bold: \`- **doctor:** warns on an old index\`.
- Name the file, the command or the setting; leave out what the diff shows line by line.
- Under a heading with nothing to say, write \`- **None.**\`"
line_is "pull request format: version property" "$vault/claude/pull-request.md" "pull_request_version: 3"
file_has "pull request format: a project's own note wins" "$vault/claude/pull-request.md" \
  'A project that keeps its own'
line_is "index: the pull request rule points to the note, and a project's own copy wins" "$vault/CLAUDE.md" \
  "  \`<Path>/claude/pull-request.md\` wins."
line_is "index: the pull request rule names the vault note through the pointer" "$vault/CLAUDE.md" \
  "  \`~/.claude/second-brain-vault/claude/pull-request.md\`; a project's own"
line_is "index: the pull request rule opens its bullet" "$vault/CLAUDE.md" \
  "- Write a pull request description in the format of"
WS="$vault/claude/writing-style.md"
exists "scaffold vault: writing style" "$WS"
is "writing style: the starter is the plugin's template" "$(cmp -s "$here/templates/writing-style.md.tmpl" "$WS" && printf same)" "same"
is "writing style: frontmatter with an alias, the type and its tag" \
  "$(awk 'NR == 1 && /^---$/ { on = 1; next } on && /^---$/ { exit } on' "$WS")" "aliases:
  - Writing Style
type: onboarding
tags:
  - type/onboarding"
line_is "writing style: up link to the conventions" "$WS" "> Conventions: [[obsidian-conventions|Obsidian Conventions]]"
is "writing style: a title and one section" "$(grep '^#' "$WS" | tr '\n' '|')" "# Writing style|## Lists|"
line_is "writing style: one line says a project's own note wins" "$WS" \
  "Claude writes notes in this style. A project's own \`<project>/claude/writing-style.md\` wins."
is "writing style: the list rule, word for word" "$(section_of "$WS" Lists)" \
  "- Indent a nested list item in a note's body with one tab per level, never spaces, so Obsidian
  shows the nesting. The YAML frontmatter keeps spaces, as YAML allows no tabs."
is "writing style: no tab in the starter, so its frontmatter stays YAML" "$(grep -c "$TAB" "$WS")" "0"
line_is "index: the writing style rule names the vault note through the pointer" "$vault/CLAUDE.md" \
  "- Write notes in the style of \`~/.claude/second-brain-vault/claude/writing-style.md\`; a"
line_is "index: a project's own writing style wins" "$vault/CLAUDE.md" \
  "  project's own \`<Path>/claude/writing-style.md\` wins."
is "index: the writing style rule is in the section for every session" \
  "$(($(lineno "$vault/CLAUDE.md" 'writing-style.md') < $(lineno "$vault/CLAUDE.md" '## Working on a project or on notes')))" "1"
line_is "vault Claude hub: names the writing style note" "$vault/claude/README.md" \
  '`writing-style.md` here is the style of every note Claude writes. Edit it to change the style.'
file_has "vault Claude hub: names the pull request format note" "$vault/claude/README.md" \
  '`pull-request.md` here is the format of every pull request'
line_is "vault Claude hub: what it holds" "$vault/claude/README.md" \
  'Your own skills and agents that serve every project live here:'
line_is "vault Claude hub: a project's skill or agent goes in its claude folder" "$vault/claude/README.md" \
  '1. Create the file here, or in `<project>/claude/` for one that serves a single project.'
line_is "vault Claude hub: name equals the folder or file name" "$vault/claude/README.md" \
  '2. Give its frontmatter at least `name`, the same as the skill folder or agent file name, and a'
line_is "vault Claude hub: the description is one sentence" "$vault/claude/README.md" \
  '   one-sentence `description`.'
line_is "vault Claude hub: a project-specific name has the project prefix" "$vault/claude/README.md" \
  '3. Names share one namespace. Prefix a project-specific name with the project: `example-deploy`.'
line_is "vault Claude hub: link --apply registers it" "$vault/claude/README.md" \
  '4. Run `second-brain link --apply` to link it into `~/.claude/skills/` or `~/.claude/agents/`.'
line_is "vault Claude hub: the vault file is the only copy" "$vault/claude/README.md" \
  '   The file in the vault stays the only copy.'
line_is "vault Claude hub: each one is listed with its use when line" "$vault/claude/README.md" \
  '5. List it below, or in the project'"'"'s `claude/README.md`, with its "use when" line.'
line_is "vault Claude hub: a rename, move or delete fixes the link" "$vault/claude/README.md" \
  '6. On a rename, move or delete, fix or remove the link in the same change.'
line_is "vault Claude hub: link --check lists dangling links" "$vault/claude/README.md" \
  '   `second-brain link --check` lists dangling links.'
is "index: the pull request rule is in the section for every session" \
  "$(($(lineno "$vault/CLAUDE.md" 'pull-request.md') < $(lineno "$vault/CLAUDE.md" '## Working on a project or on notes')))" "1"
line_is "index: table header as in the contract" "$vault/CLAUDE.md" "| Project | Path | Keys | Use when |"
line_is "index: version property" "$vault/CLAUDE.md" "index_version: 7"
rules="$(section_of "$vault/CLAUDE.md" "Rules for notes that most often go wrong" | tr '\n' ' ' | tr -s ' ')"
is "index: the rules for notes hold the search and read rule" "$(printf '%s\n' "$rules" | grep -c -F 'Find and read notes with the helper, never with grep, cat or sed on vault files: `second-brain find`, `search` (also for related notes before a decision), `task head`, then `outline` and a ranged read, and a whole note last.')" "1"
is "index: what holds in every session comes before what holds for a project" \
  "$(($(lineno "$vault/CLAUDE.md" '## In every session') < $(lineno "$vault/CLAUDE.md" '## Working on a project or on notes')))" "1"
file_has "index: a new skill is not created straight in the link directory" "$vault/CLAUDE.md" '~/.claude/skills'
every="$(awk '/^## / { on = ($0 == "## In every session") } on' "$vault/CLAUDE.md")"
is "index: the every-session section says where the vault is" "$(printf '%s\n' "$every" | tr '\n' ' ' | grep -c -E 'The vault is +`~/\.claude/second-brain-vault/`')" "1"
is "index: it names the command that registers a new skill" "$(printf '%s\n' "$every" | grep -c -F 'second-brain link --apply')" "1"
file_lacks "index: no line says to ignore the file" "$vault/CLAUDE.md" "ignore this file"
file_has "index: story-tracker is named for any question or change on a ticket" "$vault/CLAUDE.md" "\`story-tracker\` for any question or change on a ticket (where it stands, a standup, an"
is "index: the ticket text rule is said once, in the bullet that sends it to story-tracker" "$(grep -ci 'ticket text' "$vault/CLAUDE.md")" "1"
file_has "index: ticket text is never written freehand and goes to story-tracker" "$vault/CLAUDE.md" "- Ticket text is never written freehand. Use \`story-tracker\`"
is "index: the ticket text rule sits under the rules that most often go wrong" \
  "$(($(lineno "$vault/CLAUDE.md" '## Rules for notes that most often go wrong') < $(lineno "$vault/CLAUDE.md" '- Ticket text is never')))" "1"
file_has "index: a rule about one project goes under the project's Rules" "$vault/CLAUDE.md" 'A rule about one project goes under `## Rules` in `<Path>/claude/README.md`'
is "index: the rule placement holds in every session" \
  "$(($(lineno "$vault/CLAUDE.md" 'A rule about one project') < $(lineno "$vault/CLAUDE.md" '## Working on a project or on notes')))" "1"
file_has "index: the subproject note is read with the project's rules" "$vault/CLAUDE.md" 'the `claude/subprojects/<name>.md` that `second-brain context` names'
file_has "index: a new skill is added by the steps of the vault Claude hub" "$vault/CLAUDE.md" \
  '- Add it by the steps under `## Adding a skill or agent` in the vault'"'"'s `claude/README.md`.'
line_is "vault Claude hub: holds the heading the index points to" "$vault/claude/README.md" '## Adding a skill or agent'
line_is "index: Claude Code loads a new skill only after link --apply" "$vault/CLAUDE.md" \
  '  Claude Code loads it only after `second-brain link --apply`.'
file_has "index: only a rule for every project goes in the link directory's CLAUDE.md" "$vault/CLAUDE.md" \
  'Only a rule for every project goes in `~/.claude/CLAUDE.md`. Unsure which: ask.'
line_is "index: a plugin skill or agent is called for its work" "$vault/CLAUDE.md" \
  '- Call a plugin skill or agent for its work, even when the helper alone could answer. Skills:'
file_has "index: a task note is never filed inside its topic" "$vault/CLAUDE.md" '- Never file a task note inside the topic it is about.'
line_is "index: notes move and rename with the helper" "$vault/CLAUDE.md" \
  '- Move and rename notes with `second-brain move` and `second-brain rename`, never `mv`.'
line_is "conventions: version property" "$vault/obsidian-conventions.md" "conventions_version: 10"
is "conventions: no command of the Obsidian CLI is left" "$(grep -c -e 'brain ob ' -e '`obsidian ' -e 'probe' "$vault/obsidian-conventions.md")" "0"
is "conventions: the short version is the first section" "$(grep -m1 '^## ' "$vault/obsidian-conventions.md")" "## The short version"
sb conventions
rc_is "conventions: exit 0" 0
is "conventions: the default is the short version, without its heading" "$(printf '%s\n' "$OUT" | head -1 | cut -c1-17)" "1. Every task is "
is "conventions: one section only" "$(printf '%s\n' "$OUT" | grep -c '^## ' || true)" "0"
if [ "$(lines "$OUT")" -le 30 ]; then pass "conventions: the short version stays within 30 lines"; else fail "conventions: the short version stays within 30 lines" "$(lines "$OUT") lines"; fi
for c in "<project>/tasks/<TICKET-ID>/README.md" "topic tag" "unique **alias**" "Links carry a path" 'bare `[[Alias]]` does not resolve' \
  "second-brain move" "second-brain unresolved <project>" "status/done" "in-review" "Quote a YAML value" 'sprint: "<id>"'; do
  out_has "conventions: the short version covers: $c" "$c"
done
sb conventions "note metadata"
out_has "conventions: a named section, any case" "Every substantive note carries frontmatter."
out_lacks "conventions: stops at the next section" "In a tag, spaces and underscores"
sb conventions Helper commands
out_has "conventions: a section name of several words" 'second-brain backlinks "<vault path>"'
sb conventions "in the obsidian app"
out_has "conventions: the app is kept as the viewer" "Obsidian is the viewer"
sb conventions tasks
out_has "conventions: a slug gets the id as an alias" 'second-brain task alias <slug> add <ID>'
out_has "conventions: says the folder keeps the slug" "renaming a task folder is not supported yet"
out_lacks "conventions: no advice to rename the folder to the id" "renamed to the id"
sb conventions "no such section"
rc_is "conventions: unknown section gives exit 1" 1
mkdir -p "$tmp/vault0/.obsidian"
run env SECOND_BRAIN_VAULT="$tmp/vault0" "$SB" conventions
rc_is "conventions: no conventions note gives exit 1" 1
printf 'my own line\n' >>"$vault/claude/README.md"
sb scaffold vault
rc_is "scaffold vault again: exit 0" 0
out_is "scaffold vault again: creates nothing" ""
file_has "scaffold vault again: does not overwrite" "$vault/claude/README.md" "my own line"
printf -- '- my own pull request rule\n' >>"$vault/claude/pull-request.md"
sb scaffold vault
err_has "scaffold vault again: names the pull request note that exists" "exists: claude/pull-request.md"
file_has "scaffold vault again: does not overwrite the pull request note" "$vault/claude/pull-request.md" "my own pull request rule"
printf -- '- my own writing rule\n\t- a nested item\n' >>"$WS"
cp "$WS" "$tmp/ws.before"
sb scaffold vault
rc_is "scaffold vault again: exit 0 with a writing style note" 0
out_is "scaffold vault again: writes no writing style note" ""
err_has "scaffold vault again: names the writing style note that exists" "exists: claude/writing-style.md"
is "scaffold vault again: keeps the writing style note byte for byte" "$(cmp -s "$tmp/ws.before" "$WS" && printf same)" "same"
rm "$WS"
others="CLAUDE.md obsidian-conventions.md claude/README.md claude/pull-request.md"
before="$(cd "$vault" && cksum $others)"
sb scaffold vault
rc_is "scaffold vault, a vault without the writing style: exit 0" 0
out_is "scaffold vault, a vault without the writing style: writes only that note" "claude/writing-style.md"
is "scaffold vault, a vault without the writing style: writes the template" "$(cmp -s "$here/templates/writing-style.md.tmpl" "$WS" && printf same)" "same"
is "scaffold vault, a vault without the writing style: names each other file as one that exists" \
  "$(printf '%s\n' "$ERR" | tr '\n' '|')" "exists: CLAUDE.md|exists: obsidian-conventions.md|exists: claude/README.md|exists: claude/pull-request.md|"
is "scaffold vault, a vault without the writing style: leaves the other files as they were" "$(cd "$vault" && cksum $others)" "$before"
mkdir -p "$tmp/vault2/.obsidian"
sb scaffold vault "$tmp/vault2"
exists "scaffold vault DIR: writes into that vault" "$tmp/vault2/CLAUDE.md"
sb scaffold vault "$tmp/userdir"
rc_is "scaffold vault DIR: not a vault gives exit 2" 2
sb projects
rc_is "projects: exit 0 with no rows" 0
out_is "projects: empty" ""

# ---------------------------------------------------------------- scaffold project
sb scaffold project Example --path "$P" --keys EX,EXOPS
rc_is "scaffold project: exit 0" 0
out_is "scaffold project: lists what it created" "$P/README.md
$P/claude/README.md
$P/claude/profile.md
$P/claude/validation.md
$P/tasks/README.md
$P/tasks/tasks.base
$P/docs/README.md
$P/sprints/README.md"
line_is "index: one row for the project" "$vault/CLAUDE.md" "| Example | $P | EX, EXOPS | Anything about Example. |"
line_is "profile: ticket keys" "$vault/$P/claude/profile.md" "ticket_keys: [EX, EXOPS]"
line_is "profile: sprints are on by default" "$vault/$P/claude/profile.md" "uses_sprints: true"
line_is "board: folder filter" "$vault/$P/tasks/tasks.base" "    - file.inFolder(\"$P/tasks\")"
line_is "board: folder depth is the path segments plus one" "$vault/$P/tasks/tasks.base" '        - file.folder.split("/").length == 6'
line_is "board: the archive folder is accepted too" "$vault/$P/tasks/tasks.base" "            - file.inFolder(\"$P/tasks/archive\")"
line_is "board: an archived task sits two folders deeper" "$vault/$P/tasks/tasks.base" '            - file.folder.split("/").length == 8'
# filters_of <board>: the board's own filters block, above its formulas and views.
filters_of() { awk '/^[^ \t#-]/ { top = ($0 ~ /^filters:/) } top' "$1"; }
# filters_want <tasks path> <flat depth>: the filters block the template writes for that tasks root,
# with the branch that takes a task one level deeper, such as a child task, last.
filters_want() {
  local s
  printf '%s\n' "filters:" "  and:" "    - file.inFolder(\"$1\")" '    - file.name == "README"' "    - or:" \
    "        - file.folder.split(\"/\").length == $2" "        - and:" "            - file.inFolder(\"$1/archive\")" \
    "            - file.folder.split(\"/\").length == $(($2 + 2))" "        - and:" \
    "            - file.folder.split(\"/\").length == $(($2 + 1))" "            - or:"
  for s in planned in-progress in-review done abandoned; do printf '%s\n' "                - file.inFolder(\"$1/$s\")"; done
  printf '%s\n' "        - and:" "            - file.folder.split(\"/\").length == $(($2 + 1))" \
    "            - file.folder.split(\"/\")[$2] == aliases[0]"
  printf '%s\n' "        - and:" "            - file.folder.split(\"/\").length == $(($2 + 2))" \
    "            - file.folder.split(\"/\")[$(($2 + 1))] == aliases[0]"
}
is "board: the filters take a task in each status folder, one folder deeper than a flat task" \
  "$(filters_of "$vault/$P/tasks/tasks.base")" "$(filters_want "$P/tasks" 6)"
is "board: the depth of the status folders is that of a task folder in each" \
  "$(filters_of "$vault/$P/tasks/tasks.base" | awk '/split\("\/"\)\.length ==/ { d = $NF } /^            - or:$/ { print d; exit }')" \
  "$(for s in planned in-progress in-review done abandoned; do printf '%s\n' "$P/tasks/$s/EX-1"; done | awk -F/ '{ print NF }' | sort -u)"
line_is "board: sprint literal placeholder" "$vault/$P/tasks/tasks.base" '        - sprint == "none"'
line_is "board: a Depends on column" "$vault/$P/tasks/tasks.base" "    displayName: Depends on"
line_is "board: a Subproject column" "$vault/$P/tasks/tasks.base" "    displayName: Subproject"
for v in Active "Current sprint" "By topic" "By subproject" "Needs a status" All; do
  line_is "board: view $v" "$vault/$P/tasks/tasks.base" "    name: $v"
done
file_has "tasks hub: names the By subproject view" "$vault/$P/tasks/README.md" '`By subproject`, `Needs a status` and `All`'
line_is "tasks hub: embedded board" "$vault/$P/tasks/README.md" "![[$P/tasks/tasks.base#Active]]"
line_is "tasks hub: unique alias" "$vault/$P/tasks/README.md" '  - "Example Tasks Hub"'
line_is "tasks hub: up-link in the full-path form" "$vault/$P/tasks/README.md" "> Up: [[$P/README|Example Hub]]"
line_is "tasks hub: names its folder" "$vault/$P/tasks/README.md" 'The hub of `tasks/`.'
line_is "project hub: the Claude hub line" "$vault/$P/README.md" "- [[$P/claude/README|Example Claude Hub]] - rules, profile, skills and agents"
line_is "project hub: the placeholder paragraph" "$vault/$P/README.md" "<One paragraph: what the project is, who it is for, and where its code lives.>"
line_is "Claude hub: what Claude reads first" "$vault/$P/claude/README.md" "What Claude reads before it works on Example: the rules below, then the profile."
line_is "Claude hub: the profile line" "$vault/$P/claude/README.md" "- Profile: [[$P/claude/profile|Example Profile]] - ticket keys, folders, sprint"
line_is "Claude hub: the profile line ends at the doc map" "$vault/$P/claude/README.md" "  cadence, repos and the doc map."
line_is "Claude hub: the rule placeholder" "$vault/$P/claude/README.md" "- <A rule Claude must follow in this project, one per bullet.>"
line_is "Claude hub: the live systems placeholder" "$vault/$P/claude/README.md" "- <Live systems: what is read-only unless you ask for a write. Detail goes in the profile.>"
line_is "Claude hub: where project skills live, and their prefix" "$vault/$P/claude/README.md" 'Project skills live in `claude/skills/<name>/SKILL.md`. Prefix each name with the project.'
line_is "Claude hub: where project agents live" "$vault/$P/claude/README.md" 'Project agents live in `claude/agents/<name>.md`.'
PF="$vault/$P/claude/profile.md"
line_is "profile: facts only, the workflow is in the skills" "$PF" "The one settings note for Example. Keep it to facts: the workflow lives in the skills."
line_is "profile: the four task layouts" "$PF" '- `task_layout:` above is `flat`, the default, `archive`, `status` or `sprint`. A `flat` project'
line_is "profile: flat moves no task" "$PF" '  never moves a task.'
line_is "profile: archive moves a done task once, with task archive" "$PF" \
  '- `archive` moves a done or abandoned task, once, with `second-brain task archive <ID>`, to'
line_is "profile: the archive folder" "$PF" '  `archive/<YYYY>/<ID>/` under the tasks root.'
line_is "profile: status keeps a task in the folder of its status" "$PF" \
  '- `status` keeps each task in the folder of its status under the tasks root, such as `done/<ID>/`.'
line_is "profile: task set moves a status task, and nothing is archived" "$PF" \
  '  `second-brain task set <ID> status=<status>` moves it there, and nothing is archived.'
line_is "profile: sprint keeps a task in the folder of its sprint" "$PF" \
  '- `sprint` keeps each task in the folder of its sprint under the tasks root, such as'
line_is "profile: and a task in no sprint in backlog/" "$PF" \
  '  `2026-12-04/<ID>/`, and a task in no sprint in `backlog/<ID>/`. `second-brain task set` moves it'
line_is "profile: sprint with sprints off is flat" "$PF" \
  '  when its sprint changes, and nothing is archived. With `uses_sprints: false` it is `flat`.'
line_is "profile: sprint_folder names a sprint's folder" "$PF" \
  '- With `sprint`, a `sprint_folder:` key added above names a sprint'"'"'s folder: its end date with no'
line_is "profile: sprint_folder points to the contract" "$PF" \
  '  key, or a pattern such as `sprint-<n>`, as `### Profile frontmatter` in the plugin'"'"'s'
file_lacks "profile: sprint_folder adds no placeholder" "$PF" '`<end>`'
file_lacks "profile: no longer says only archive moves a task" "$PF" 'Only `archive` moves'
line_is "profile: with archive only, when a done task is due for the archive" "$PF" '- With `archive`, `archive_after_days:` is how many days a done task waits, counted from its newest'
line_is "profile: the doctor names a due task and doctor --fix archives it" "$PF" '  status note or its sprint'"'"'s end, before the doctor names it and `doctor --fix` archives it.'
file_has "profile: delivery is what a story with none of its own falls back to" "$PF" \
  '- `delivery:` above is `direct | spec`, what a story with no `delivery` of its own falls back'
line_is "profile: delivery points to the contract" "$PF" \
  "  as \`### Profile frontmatter\` in the plugin's \`docs/contract.md\` says."
line_is "profile: where spec_home puts the spec" "$PF" '- `spec_home:` puts the spec in the task'"'"'s folder (`vault`) or in `spec/<ID>/` in the repo (`repo`).'
line_is "profile: where validation_home puts validation.md" "$PF" '- `validation_home:` puts `validation.md` in `claude/` (`vault`) or at each repo'"'"'s root (`repo`).'
line_is "profile: list every repository" "$PF" '- List every repository'"'"'s folder name in `repos:` above.'
line_is "profile: what repos_root holds" "$PF" '- `repos_root:` is where the repositories usually sit on this machine, absolute or starting with `~`.'
line_is "profile: turning sprints off" "$PF" '- Set `uses_sprints: false` above to turn sprints off; the cadence lines then do not apply.'
line_is "profile: docs follow production" "$PF" 'Docs follow production: a doc is updated only after its change is confirmed deployed to production,'
line_is "profile: the branch production runs" "$PF" 'which runs `production_branch` above, or `base_branch` when that is empty. Say here how a'
line_is "profile: every repository has a row in the code to doc map" "$PF" 'Every repository in `repos` has at least one row, added in the same change as the repository.'
printf 'kept\n' >>"$vault/$P/README.md"
cp "$vault/$P/claude/profile.md" "$tmp/profile.before"
sb scaffold project Example --path "$P" --keys EX,EXOPS
rc_is "scaffold project again: exit 0" 0
out_is "scaffold project again: creates nothing" ""
file_has "scaffold project again: does not overwrite" "$vault/$P/README.md" "kept"
is "scaffold project again: profile untouched" "$(cmp -s "$tmp/profile.before" "$vault/$P/claude/profile.md"; echo $?)" "0"
is "index: still exactly one row" "$(grep -c '^| Example |' "$vault/CLAUDE.md")" "1"
sb scaffold project Example --path other/place
rc_is "scaffold project: a taken name gives exit 6" 6
absent "scaffold project: nothing created for the refused name" "$vault/other"
sb scaffold project Other --path "$P"
rc_is "scaffold project: a taken path gives exit 6" 6
sb scaffold project NoPath
rc_is "scaffold project: no --path gives exit 5" 5
sb scaffold project "Bad|Name" --path x/y
rc_is "scaffold project: a name with a pipe gives exit 5" 5
sb scaffold project Up --path ../outside
rc_is "scaffold project: a path leaving the vault gives exit 5" 5
sb scaffold
rc_is "scaffold: no subcommand gives exit 5" 5
sb scaffold project "Example Two" --path "$P2" --keys NEW,ex --use-when "The second | service."
rc_is "scaffold project: a key another project owns gives exit 6" 6
err_has "scaffold project: the message names the owner" "already belongs to the project Example"
absent "scaffold project: nothing created for a taken key" "$vault/$P2"
is "scaffold project: no index row for a taken key" "$(grep -c '^| Example Two |' "$vault/CLAUDE.md")" "0"
sb scaffold project "Example Two" --path "$P2" --keys TWO --use-when "The second | service."
rc_is "scaffold project: second project" 0
line_is "index: second row, pipe escaped" "$vault/CLAUDE.md" "| Example Two | $P2 | TWO | The second \\| service. |"
sb scaffold project "Example Two" --path "$P2" --keys TWO
rc_is "scaffold project: a project keeps its own keys on a second run" 0
edit "$vault/CLAUDE.md" 's/^| Example Two | \(.*\) | TWO | /| Example Two | \1 | EX, TWO | /'
sb projects
out_is "projects: one TSV row per project" "Example${TAB}$P${TAB}EX,EXOPS
Example Two${TAB}$P2${TAB}EX,TWO"

# ---------------------------------------------------------------- scaffold project, other roots
R="work/roots"
sb scaffold project Roots --path "$R" --keys RT --tasks-root plan/tasks --topics-root knowledge --sprints-root cadence/sprints
rc_is "scaffold roots: exit 0" 0
out_is "scaffold roots: hubs and board only under the given roots" "$R/README.md
$R/claude/README.md
$R/claude/profile.md
$R/claude/validation.md
$R/plan/tasks/README.md
$R/plan/tasks/tasks.base
$R/knowledge/README.md
$R/cadence/sprints/README.md"
line_is "scaffold roots: tasks root in the profile" "$vault/$R/claude/profile.md" "tasks_root: plan/tasks"
line_is "scaffold roots: topics root in the profile" "$vault/$R/claude/profile.md" "topics_root: knowledge"
line_is "scaffold roots: sprints root in the profile" "$vault/$R/claude/profile.md" "sprints_root: cadence/sprints"
for d in tasks docs sprints; do absent "scaffold roots: no default $d folder" "$vault/$R/$d"; done
line_is "scaffold roots: board folder is the tasks root" "$vault/$R/plan/tasks/tasks.base" "    - file.inFolder(\"$R/plan/tasks\")"
line_is "scaffold roots: board depth counts the nested tasks root" "$vault/$R/plan/tasks/tasks.base" '        - file.folder.split("/").length == 5'
line_is "scaffold roots: the archive depth counts it too" "$vault/$R/plan/tasks/tasks.base" '            - file.folder.split("/").length == 7'
is "scaffold roots: the status folders sit in the nested tasks root, one folder deeper than a flat task" \
  "$(filters_of "$vault/$R/plan/tasks/tasks.base")" "$(filters_want "$R/plan/tasks" 5)"
line_is "scaffold roots: tasks hub embeds its own board" "$vault/$R/plan/tasks/README.md" "![[$R/plan/tasks/tasks.base#Active]]"
line_is "scaffold roots: map links the tasks hub" "$vault/$R/README.md" "- [[$R/plan/tasks/README|Roots Tasks Hub]] - one folder per task, and the task board"
line_is "scaffold roots: map links the topics hub" "$vault/$R/README.md" "- [[$R/knowledge/README|Roots Docs Hub]] - the topics: one folder per subject"
line_is "scaffold roots: map links the sprints hub" "$vault/$R/README.md" "- [[$R/cadence/sprints/README|Roots Sprints Hub]] - one note per sprint"
is "scaffold roots: every map link points at a file" "$(check_links "$vault/$R/README.md")" ""
sb task new RT-1 --project Roots --title First
out_is "other roots: task new writes under the tasks root" "$R/plan/tasks/RT-1/README.md"
line_is "other roots: the task links up to its hub" "$vault/$R/plan/tasks/RT-1/README.md" "> Up: [[$R/plan/tasks/README|Roots Tasks Hub]]"
mkdir -p "$vault/$R/knowledge/api"
sb task tag RT-1 add knowledge/API
out_is "other roots: a tag is the path under the topics root" "api"
is "other roots: an existing topic folder gives no warning" "$ERR" ""
sb board Roots
out_is "other roots: board reads the tasks root" "RT-1 | First | planned | - | api | none yet | Frame the story | - | -"
sb sprint open Roots --end 2026-10-21
out_is "other roots: sprint open writes under the sprints root" "$R/cadence/sprints/2026-10-21.md"
line_is "other roots: sprint hub line" "$vault/$R/cadence/sprints/README.md" "- [[$R/cadence/sprints/2026-10-21|Roots Sprint 2026-10-21]] - 2026-10-08 to 2026-10-21"
line_is "other roots: board literal rewritten" "$vault/$R/plan/tasks/tasks.base" '        - sprint == "2026-10-21"'
sb sprint current Roots
rc_is "other roots: sprint current finds it" 0
sb project --cwd "$vault/$R/plan/tasks/RT-1"
out_is "other roots: a task folder resolves to its project" "Roots${TAB}$R${TAB}RT"
D="work/dot"
sb scaffold project Dot --path "$D" --topics-root .
out_is "scaffold topics root dot: no topics hub" "$D/README.md
$D/claude/README.md
$D/claude/profile.md
$D/claude/validation.md
$D/tasks/README.md
$D/tasks/tasks.base
$D/sprints/README.md"
line_is "scaffold topics root dot: quoted in the profile" "$vault/$D/claude/profile.md" 'topics_root: "."'
absent "scaffold topics root dot: no docs folder" "$vault/$D/docs"
file_lacks "scaffold topics root dot: the README has no topics-hub line" "$vault/$D/README.md" "Docs Hub"
is "scaffold topics root dot: three map lines" "$(grep -c '^- \[\[' "$vault/$D/README.md")" "3"
is "scaffold topics root dot: map links point at files" "$(check_links "$vault/$D/README.md")" ""
mkdir -p "$vault/$D/Billing"
sb task new dot-task --project Dot --topics billing
is "scaffold topics root dot: a topic folder at the project root is found" "$ERR" ""
find "$vault/$D" -type f | LC_ALL=C sort >"$tmp/dot.before"
sb scaffold project Dot --path "$D" --topics-root . --tasks-root elsewhere
rc_is "scaffold again: exit 0" 0
out_is "scaffold again: creates nothing new" ""
err_has "scaffold again: reports what is there" "exists: $D/claude/profile.md"
err_has "scaffold again: reports the board too" "exists: $D/tasks/tasks.base"
err_has "scaffold again: root flags ignored once a profile exists" "root flags are ignored"
find "$vault/$D" -type f | LC_ALL=C sort >"$tmp/dot.after"
is "scaffold again: same files as before" "$(cmp -s "$tmp/dot.before" "$tmp/dot.after"; echo $?)" "0"
is "scaffold again: still one index row" "$(grep -c '^| Dot |' "$vault/CLAUDE.md")" "1"
E="work/existing"
mkdir -p "$vault/$E/tasks"
printf -- '---\naliases:\n  - Old Tasks Hub\ntype: moc\n---\n\n# Tasks kept by hand\n' >"$vault/$E/tasks/README.md"
printf 'filters:\n  and:\n    - file.name == "README"\n' >"$vault/$E/tasks/tasks.base"
cp "$vault/$E/tasks/README.md" "$tmp/hub.before"
cp "$vault/$E/tasks/tasks.base" "$tmp/base.before"
sb scaffold project Existing --path "$E"
rc_is "scaffold onto existing files: exit 0" 0
out_lacks "scaffold onto existing files: the hub is not listed as created" "$E/tasks/README.md"
err_has "scaffold onto existing files: hub reported" "exists: $E/tasks/README.md"
err_has "scaffold onto existing files: board reported" "exists: $E/tasks/tasks.base"
is "scaffold onto existing files: hub byte-identical" "$(cmp -s "$tmp/hub.before" "$vault/$E/tasks/README.md"; echo $?)" "0"
is "scaffold onto existing files: board byte-identical" "$(cmp -s "$tmp/base.before" "$vault/$E/tasks/tasks.base"; echo $?)" "0"
line_is "scaffold onto existing files: the map shows the hub by its own alias" "$vault/$E/README.md" "- [[$E/tasks/README|Old Tasks Hub]] - one folder per task, and the task board"
exists "scaffold onto existing files: the missing hubs are created" "$vault/$E/sprints/README.md"
sb scaffold project Bad --path work/bad --tasks-root .
rc_is "scaffold roots: the tasks root cannot be the project folder, exit 5" 5
sb scaffold project Bad --path work/bad --sprints-root ../out
rc_is "scaffold roots: a root leaving the project gives exit 5" 5
sb scaffold project Bad --path work/bad --tasks-root same --sprints-root same
rc_is "scaffold roots: two roots in one folder give exit 5" 5
sb scaffold project Bad --path work/bad --tasks-root plan --sprints-root plan/sprints
rc_is "scaffold roots: a root inside the tasks root gives exit 5" 5
sb scaffold project Bad --path work/bad --topics-root
rc_is "scaffold roots: a flag with no value gives exit 5" 5
absent "scaffold roots: nothing created for a refused call" "$vault/work/bad"
is "scaffold roots: no index row for a refused call" "$(grep -c '^| Bad |' "$vault/CLAUDE.md")" "0"

# ---------------------------------------------------------------- scaffold project, no sprints
N="work/kanban"
sb scaffold project Kanban --path "$N" --keys KB --no-sprints
rc_is "no sprints: scaffold exit 0" 0
out_is "no sprints: no sprints hub is created" "$N/README.md
$N/claude/README.md
$N/claude/profile.md
$N/claude/validation.md
$N/tasks/README.md
$N/tasks/tasks.base
$N/docs/README.md"
line_is "no sprints: the profile says so" "$vault/$N/claude/profile.md" "uses_sprints: false"
absent "no sprints: no sprints folder" "$vault/$N/sprints"
file_lacks "no sprints: the map has no sprints line" "$vault/$N/README.md" "Sprints Hub"
is "no sprints: every map link points at a file" "$(check_links "$vault/$N/README.md")" ""
file_lacks "no sprints: the tasks hub names no sprint view" "$vault/$N/tasks/README.md" "Current sprint"
file_lacks "no sprints: the board has no sprint view, filter or column" "$vault/$N/tasks/tasks.base" "sprint"
file_lacks "no sprints: the board has no carried-from column" "$vault/$N/tasks/tasks.base" "carried_from"
for v in Active "By topic" "By subproject" "Needs a status" All; do
  line_is "no sprints: board view $v" "$vault/$N/tasks/tasks.base" "    name: $v"
done
is "no sprints: the board takes the status folders too" "$(filters_of "$vault/$N/tasks/tasks.base")" "$(filters_want "$N/tasks" 4)"
is "no sprints: the board keeps its five views whole" "$(grep -c '^  - type: table$' "$vault/$N/tasks/tasks.base")" "5"
line_is "no sprints: the last view keeps its last column" "$vault/$N/tasks/tasks.base" "      - file.mtime"
sb context --cwd "$vault/$N"
out_has "no sprints: context says off" "sprint: off"
for c in "current Kanban" "next Kanban" "open Kanban --end 2026-02-01" "set Kanban goal=x" "close Kanban"; do
  # shellcheck disable=SC2086
  sb sprint $c
  rc_is "no sprints: sprint ${c%% *} exits 5" 5
  err_has "no sprints: sprint ${c%% *} says why" "Kanban does not use sprints"
done
absent "no sprints: a refused open writes no note" "$vault/$N/sprints"
sb task new KB-1 --project Kanban --title First
rc_is "no sprints: task new works" 0
sb task set KB-1 status=in-progress sprint=2026-02-01
rc_is "no sprints: task set refuses a sprint id" 5
file_lacks "no sprints: a refused task set writes nothing" "$vault/$N/tasks/KB-1/README.md" "in-progress"
edit "$vault/$N/tasks/KB-1/README.md" 's/^status: planned$/status: planned\
sprint: "2026-02-01"/'
line_is "no sprints: a sprint id left over from before" "$vault/$N/tasks/KB-1/README.md" 'sprint: "2026-02-01"'
sb task set KB-1 sprint=
out_is "no sprints: task set may still remove a sprint id" "sprint: (removed)"
file_lacks "no sprints: the leftover id is gone" "$vault/$N/tasks/KB-1/README.md" "sprint:"
sb board Kanban
out_has "no sprints: the board still lists the task" "KB-1 | First | planned | - |"
sb board Kanban "Current sprint"
out_is "no sprints: the sprint view has no rows" ""
sb scaffold project Kanban --path "$N" --keys KB
out_is "no sprints: a second run without the flag creates nothing" ""
absent "no sprints: the profile decides, so still no sprints hub" "$vault/$N/sprints"
sb scaffold project Clash --path work/clash --no-sprints --sprints-root cadence
rc_is "no sprints: the flag and a sprints root together exit 5" 5
absent "no sprints: nothing written on the clash" "$vault/work/clash"
sb scaffold project Roots --path "$R" --keys RT --no-sprints
err_has "no sprints: an existing profile that uses sprints wins over the flag" "--no-sprints is ignored"
line_is "no sprints: that profile is unchanged" "$vault/$R/claude/profile.md" "uses_sprints: true"
edit "$vault/$N/claude/profile.md" 's/^uses_sprints: false$/uses_sprints: False/'
sb sprint current Kanban
rc_is "no sprints: the letter case of false does not matter" 5
edit "$vault/$N/claude/profile.md" 's/^uses_sprints: False$/uses_sprints: true/'
sb scaffold project Kanban --path "$N" --keys KB
out_is "sprints turned on: the next scaffold adds the hub" "$N/sprints/README.md"
err_has "sprints turned on: the map line to add is given" "add the sprints hub to the map in $N/README.md: - [[$N/sprints/README|Kanban Sprints Hub]] - one note per sprint"
err_has "sprints turned on: the board view to add is named" "the board at $N/tasks/tasks.base has no Current sprint view"
sb scaffold project Kanban --path "$N" --keys KB
is "sprints turned on: said once, when the hub is made" "$(printf '%s\n' "$ERR" | grep -c '^note: ' || true)" "0"
sb sprint open Kanban --end 2026-02-01
rc_is "sprints turned on: a sprint opens" 0
err_has "sprints turned on: the missing view is named" "has no Current sprint view to update"
sb context --cwd "$vault/$N"
out_has "sprints turned on: context shows the sprint" "sprint: 2026-02-01"
sb task set KB-1 sprint=2026-02-01
sb board Kanban "Current sprint"
out_has "sprints turned on: the sprint lists its task" "KB-1 | First | planned | 2026-02-01 |"
edit "$vault/$N/claude/profile.md" 's/^uses_sprints: true$/uses_sprints: false/'
sb board Kanban "Current sprint"
out_is "sprints turned off again: a sprint left in progress lists nothing" ""
sb context --cwd "$vault/$N"
out_has "sprints turned off again: context says off" "sprint: off"

# ---------------------------------------------------------------- result
result
