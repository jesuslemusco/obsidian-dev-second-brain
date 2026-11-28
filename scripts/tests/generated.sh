#!/usr/bin/env bash
# Area generated: no placeholder, bare link or dead link in what the helper writes, across the
# projects that the scaffold, project, tasks, board, sprint, subprojects and archive areas make.
# Usage: bash scripts/test.sh generated, or bash scripts/tests/generated.sh
. "$(dirname "$0")/lib.sh"

# The checks read every note, so this replays the commands of those areas that write the vault.
fixture_board
# scaffold vault and scaffold project
printf 'my own line\n' >>"$vault/claude/README.md"
printf -- '- my own pull request rule\n' >>"$vault/claude/pull-request.md"
mkdir -p "$tmp/vault2/.obsidian"
sb scaffold vault "$tmp/vault2"
printf 'kept\n' >>"$vault/$P/README.md"
# sprint
sb sprint open Example --end 2026-10-14 --goal "Ship: invoices"
sb sprint set Example committed=5 "goal=Ship: invoices and credits"
for t in EX-2 EX-3 EX-4 EX-5; do sb task set "$t" sprint=2026-10-14; done
sb sprint close Example --carry EX-1 --backlog EX-2 --abandon EX-55 --abandon EX-6
sb sprint open Example
sb sprint close Example --carry EX-1
sb task set EX-2 sprint=2030-01-01
sb task set EX-4 sprint=2031-01-01
sb sprint open Example --end 2026-11-05
sb sprint open "Example Two" --end 2028-03-05
# edge cases
mkdir -p "$vault/$P/tasks/EX-20/queries"
printf 'select 1;\n' >"$vault/$P/tasks/EX-20/queries/check.sql"
sb task new EX-20 --project Example --title "Folder came first"
sb task set EX-2 epic=EX-900
sb task set EX-3 type=bug
sb task set EX-3 type=task
mkdir -p "$vault/$P/tasks/bare-readme"
printf '# bare-readme - Bare\n\nText written by hand.\n' >"$vault/$P/tasks/bare-readme/README.md"
sb task set bare-readme type=task status=planned "title=Bare one" --project Example
sb task alias bare-readme add bare-readme --project Example
mkdir -p "$vault/$P2/tasks/legacy-task"
printf -- '---\naliases:\n  - legacy-task\nstatus: planned\n---\n\n# legacy-task - twin\n\n## Discovery log\n\nold finding\n' >"$vault/$P2/tasks/legacy-task/README.md"
sb task note legacy-task "Before the log" --project "Example Two"
sb task new 2026-cleanup --project Example --title "Slug that looks like a date"
sb scaffold project Four --path work/four --keys FOUR
edit "$vault/work/four/tasks/tasks.base" 's/sprint == "none"/sprint == date("none")/'
sb sprint open Four --end 2026-11-11
sb scaffold project Five --path work/five
edit "$vault/work/five/tasks/tasks.base" 's/name: Current sprint/name: Some other view/'
sb sprint open Five --end 2026-11-11
mkdir -p "$tmp/vault3/.obsidian" "$tmp/vault4/.obsidian"
printf '# My index\r\n\r\n## Projects\r\n\r\n- an old nested list\r\n\r\n## Other\r\n' >"$tmp/vault3/CLAUDE.md"
run env SECOND_BRAIN_VAULT="$tmp/vault3" "$SB" scaffold project Legacy --path old/legacy --keys LEG
printf '# My index\n\nNo project list yet.\n' >"$tmp/vault4/CLAUDE.md"
run env SECOND_BRAIN_VAULT="$tmp/vault4" "$SB" scaffold project Fresh --path fresh
# scaffold project, other roots
R="work/roots"
sb scaffold project Roots --path "$R" --keys RT --tasks-root plan/tasks --topics-root knowledge --sprints-root cadence/sprints
sb task new RT-1 --project Roots --title First
mkdir -p "$vault/$R/knowledge/api"
sb task tag RT-1 add knowledge/API
sb sprint open Roots --end 2026-10-21
D="work/dot"
sb scaffold project Dot --path "$D" --topics-root .
mkdir -p "$vault/$D/Billing"
sb task new dot-task --project Dot --topics billing
E="work/existing"
mkdir -p "$vault/$E/tasks"
printf -- '---\naliases:\n  - Old Tasks Hub\ntype: moc\n---\n\n# Tasks kept by hand\n' >"$vault/$E/tasks/README.md"
printf 'filters:\n  and:\n    - file.name == "README"\n' >"$vault/$E/tasks/tasks.base"
sb scaffold project Existing --path "$E"
# repo
RPF="$vault/work/repo-one/claude/profile.md"
sb scaffold project "Repo One" --path work/repo-one --keys RA
edit "$RPF" 's|^repos_root: ""$|repos_root: "~/code/acme"|'
edit "$RPF" 's/^repos: .*$/repos: [alpha-api, alpha-web, alpha-tools]/'
edit "$RPF" "s|^repo_paths: \\[\\]\$|repo_paths:\\
  - \"alpha-tools=$tmp/else where/alpha-tools\"\\
  - alpha-web=~/elsewhere/alpha-web|"
sb scaffold project "Repo Two" --path work/repo-two --keys RB
edit "$vault/work/repo-two/claude/profile.md" 's/^repos: \[\]$/repos: [alpha-api]/'
edit "$vault/work/repo-two/claude/profile.md" "s|^repos_root: \"\"\$|repos_root: \"$tmp/other root\"|"
# scaffold project, no sprints
N="work/kanban"
sb scaffold project Kanban --path "$N" --keys KB --no-sprints
sb task new KB-1 --project Kanban --title First
edit "$vault/$N/tasks/KB-1/README.md" 's/^status: planned$/status: planned\
sprint: "2026-02-01"/'
sb task set KB-1 sprint=
edit "$vault/$N/claude/profile.md" 's/^uses_sprints: false$/uses_sprints: true/'
sb scaffold project Kanban --path "$N" --keys KB
sb sprint open Kanban --end 2026-02-01
sb task set KB-1 sprint=2026-02-01
edit "$vault/$N/claude/profile.md" 's/^uses_sprints: true$/uses_sprints: false/'
# subprojects, retired: a note left by an earlier version, and the tasks the area writes
M="work/multi"
MF="$vault/$M/claude/profile.md"
sb scaffold project Multi --path "$M" --keys MU
edit "$MF" "s|^repos: \\[\\]\$|repos: [multi-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/mcode\"|"
edit "$MF" 's|^environments: \[\]$|environments: [dev, prod]|'
mkdir -p "$vault/$M/claude/subprojects"
printf '%s\n' '---' 'type: subproject' 'repos: [multi-infra]' 'base_branch: develop' 'environments: [staging]' \
  'validation_home: repo' '---' '' '## Rules' '' '- Never apply a plan to prod.' >"$vault/$M/claude/subprojects/infra.md"
sb task new MU-1 --project Multi --title "Infra work" --envs
edit "$vault/$M/tasks/MU-1/README.md" 's/^epic: "-"$/epic: "-"\
subproject: infra/'
sb task set MU-1 subproject=
# task archive
A="work/shelf"
sb scaffold project Shelf --path "$A" --keys SH
for t in SH-1 SH-2 SH-3 SH-4; do sb task new "$t" --project Shelf --title "Shelf $t"; done
sb task dep SH-2 add SH-1
sb task alias SH-3 add old-slug
sb task set SH-1 status=done
edit "$vault/$A/claude/profile.md" '/^task_layout: flat$/d'
edit "$vault/$A/claude/profile.md" 's/^tasks_root: tasks$/tasks_root: tasks\
task_layout: Archive/'
sb sprint open Shelf --end 2026-10-14
sb task set SH-1 sprint=2026-10-14
sb task set SH-2 sprint=2026-10-14
sb task archive SH-1
sb task set SH-1 next="Nothing left"
sb task note SH-1 "Archived"
sb task tag SH-1 add shelving
sb task set SH-3 status=abandoned
sb task archive old-slug
sb sprint close Shelf --carry SH-2
sb task set SH-4 status=done
sb task archive SH-4 --project Shelf
sb task new SH-5 --project Shelf --title "Shelf SH-5"
sb task set SH-5 status=done

# ---------------------------------------------------------------- generated files
is "generated files: no placeholder left" "$(grep -rl '{{' "$vault" "$tmp/vault2" "$tmp/vault3" "$tmp/vault4" | grep -c . || true)" "0"
is "index template: the answer-style rule is pinned" "$(sed -n '/^## In every session/,/^## Working/p' "$here/templates/vault-index.md.tmpl" | tr '\n' ' ' | grep -c 'Answer in short, plain English. Lead with the answer. The user, or their own instructions, may *say otherwise.')" "1"
is "templates: only UPPER_SNAKE placeholders" "$(cat "$here"/templates/*.tmpl | grep -o '{{[^}]*}}' | grep -vc '^{{[A-Z][A-Z0-9_]*}}$' || true)" "0"
bad_links="$(find "$vault" -name '.*' -prune -o -type f -name '*.md' -print | while IFS= read -r f; do check_links "$f"; done)"
is "generated notes: every link carries a path that exists" "$bad_links" ""
sb unresolved
rc_is "generated notes: unresolved exits 0" 0
out_is "generated notes: the helper reads no unresolved link in them" ""

# ---------------------------------------------------------------- result
result
