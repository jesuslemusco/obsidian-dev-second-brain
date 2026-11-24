#!/usr/bin/env bash
# Area templates: a project's own task and ticket templates, and the task commands that fill them.
# Usage: bash scripts/test.sh templates, or bash scripts/tests/templates.sh
. "$(dirname "$0")/lib.sh"

sb scaffold vault
S="work/shapes"
sb scaffold project Shapes --path "$S" --keys SH

# ---------------------------------------------------------------- a project's own templates
OT="$vault/$S/claude/templates"
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
sb task new SH-21 --project Shapes --title "Own shape"
rc_is "own template: task new exits 0" 0
O21="$vault/$S/tasks/SH-21/README.md"
is "own template: task new fills the project's template" "$(grep '^## ' "$O21" | tr '\n' '|')" \
  "## Ticket markup|## Approach / Key decisions|## Changes|## Verification|## Status notes|## Discovery log|"
line_is "own template: its placeholders are filled" "$O21" "# SH-21 - Own shape"
line_is "own template: the up link is the tasks hub's" "$O21" "> Up: [[$S/tasks/README|Shapes Tasks Hub]]"
line_is "own template: the title is quoted as task new writes it" "$O21" 'title: "Own shape"'
sb task note SH-21 "Shaped by the project" --session own
line_is "own template: task note writes under its Status notes" "$O21" '**2026-10-08 (session `own`) - Shaped by the project**'
printf '%s\n' '{{TEAM}}' >>"$OT/task-readme.md.tmpl"
sb task new SH-22 --project Shapes --title "Unknown placeholder"
rc_is "own template: a placeholder the plugin's lacks exits 5" 5
err_has "own template: the message names the project's template" "$S/claude/templates/task-readme.md.tmpl"
absent "own template: nothing is written on refusal" "$vault/$S/tasks/SH-22/README.md"
: >"$OT/task-readme.md.tmpl"
sb task new SH-26 --project Shapes --title "Empty template"
rc_is "own template: an empty template exits 5" 5
err_has "own template: and the message names it" "$S/claude/templates/task-readme.md.tmpl"
absent "own template: an empty template leaves no task folder" "$vault/$S/tasks/SH-26"
printf '%s\n' '# {{ID}} - {{TITLE}}' '' '## Status notes' '' '## Discovery log' >"$OT/task-readme.md.tmpl"
mkdir -p "$vault/$S/tasks/SH-27"
sb task new SH-27 --project Shapes --title "No frontmatter"
rc_is "own template: a template with no frontmatter exits 5" 5
err_has "own template: the message says the README has no frontmatter" "no frontmatter"
absent "own template: a template with no frontmatter leaves no README" "$vault/$S/tasks/SH-27/README.md"
exists "own template: a folder that was there before stays" "$vault/$S/tasks/SH-27"
rmdir "$vault/$S/tasks/SH-27"
rm "$OT/task-readme.md.tmpl"
printf '%s\n' 'The project shape of a ticket.' >"$OT/ticket-description.md.tmpl"
sb task new SH-23 --project Shapes --title "Plugin shape"
rc_is "own template: with none, task new exits 0" 0
is "own template: with none in the folder, task new fills the plugin's" "$(grep '^## ' "$vault/$S/tasks/SH-23/README.md" | tr '\n' '|')" \
  "## Description|## Findings|## Acceptance criteria|## Approach / Key decisions|## Code verification (read-only)|## Changes|## Verification|## Status notes|## Discovery log|"
awk '/^## Status notes$/ { print "```"; print; print "```"; print "" } { print }' "$here/templates/task-readme.md.tmpl" >"$OT/task-readme.md.tmpl"
sb doctor Shapes
is "own template: a fenced heading before the real one passes the doctor" "$(printf '%s\n' "$OUT" | grep ' | task-template | Shapes | ' | cut -d'|' -f1-4)" \
  "ok | task-template | Shapes | 0 "
sb task new SH-25 --project Shapes --title "Fenced example"
O25="$vault/$S/tasks/SH-25/README.md"
sb task note SH-25 "Under the real heading" --session own
is "own template: task note leaves the fenced heading alone" "$(awk '/^```$/ { f = !f; print; next } f' "$O25")" \
  "$(printf '%s\n' '```' '## Status notes' '```')"
n25="$(grep -n '^## Status notes$' "$O25" | sed -n 2p | cut -d: -f1)"
is "own template: task note writes under the real heading, as the doctor finds it" "$(sed -n "$((n25 + 2))p" "$O25")" \
  '**2026-10-08 (session `own`) - Under the real heading**'
sb task head SH-25
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
sb doctor Shapes
is "own template: the doctor warns on a template that lacks a key or a section the helper writes" \
  "$(printf '%s\n' "$OUT" | grep ' | task-template | Shapes | ')" \
  "warn | task-template | Shapes | 2 | next, ## Discovery log | add them to claude/templates/task-readme.md.tmpl, as the plugin's templates/task-readme.md.tmpl has them"
case "$OT" in "$vault"/?*/claude/templates) rm -r "$OT" ;; esac

# ---------------------------------------------------------------- result
result
