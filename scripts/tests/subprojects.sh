#!/usr/bin/env bash
# Area subprojects: retired in 0.14.0. No command takes one, and none reads a note left in
# claude/subprojects/ or a task's subproject key; the doctor names them and folds them, as
# scripts/test-doctor.sh tests.
# Usage: bash scripts/test.sh subprojects, or bash scripts/tests/subprojects.sh
. "$(dirname "$0")/lib.sh"

sb scaffold vault

# ---------------------------------------------------------------- no command takes one
M="work/multi"
MF="$vault/$M/claude/profile.md"
mkdir -p "$tmp/mcode/multi-app/src" "$tmp/mcode/multi-infra/mod"
sb scaffold project Multi --path "$M" --keys MU
edit "$MF" "s|^repos: \\[\\]\$|repos: [multi-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/mcode\"|"
edit "$MF" 's|^environments: \[\]$|environments: [dev, prod]|'
# A note as versions before 0.14.0 wrote it, with settings of its own.
mkdir -p "$vault/$M/claude/subprojects"
printf '%s\n' '---' 'type: subproject' 'repos: [multi-infra]' 'base_branch: develop' 'environments: [staging]' \
  'validation_home: repo' '---' '' '## Rules' '' '- Never apply a plan to prod.' >"$vault/$M/claude/subprojects/infra.md"
for c in "subproject Multi" "subproject Multi infra" "subproject Multi --cwd $tmp/mcode/multi-infra"; do
  # shellcheck disable=SC2086
  sb $c
  rc_is "retired: second-brain $c is no command, exit 5" 5
  err_has "retired: second-brain $c says so" "unknown command: subproject"
done
sb scaffold subproject Multi tools --repos multi-tools
rc_is "retired: scaffold subproject is no subcommand, exit 5" 5
absent "retired: and scaffold subproject writes nothing" "$vault/$M/claude/subprojects/tools.md"
sb help
out_lacks "retired: help names no subproject" "subproject"

# ---------------------------------------------------------------- no command reads a note
sb repo Multi
out_is "repo: a note's repos are no repos of the project" "multi-app${TAB}$oT/mcode/multi-app${TAB}ok"
sb context --cwd "$tmp/mcode/multi-app/src"
is "context: four lines in a repo of the project" "$(lines "$OUT")" "4"
out_lacks "context: no subproject line" "subproject:"
sb context --cwd "$tmp/mcode/multi-infra/mod"
out_has "context: a repo that only a note lists is in no project" "project: none"
sb validation Multi
out_is "validation: a note's validation_home is not read" "multi-app${TAB}vault${TAB}$M/claude/validation.md${TAB}no-section"
sb task new MU-1 --project Multi --title "Infra work" --subproject infra
rc_is "task new: --subproject is no flag, exit 5" 5
absent "task new: and writes no README" "$vault/$M/tasks/MU-1/README.md"
sb task new MU-1 --project Multi --title "Infra work" --envs
TM="$vault/$M/tasks/MU-1/README.md"
line_is "task new --envs: the profile's first environment, never a note's" "$TM" "  dev: { id: MU-1, status: planned }"
edit "$TM" 's/^epic: "-"$/epic: "-"\
subproject: infra/'
sb task head MU-1
out_lacks "task head: no subproject line, even with the key left in the note" "subproject"
sb task head MU-1 --json
out_lacks "task head --json: no subproject key either" '"subproject"'
sb task set MU-1 subproject=
out_is "task set: subproject= removes the key left in the note" "subproject: (removed)"
sb board Multi
is "board: nine columns" "$(printf '%s\n' "$OUT" | awk -F' [|] ' '{ printf "%s ", NF }')" "9 "
sb board Multi --subproject infra
rc_is "board: --subproject is no flag, exit 5" 5
sb board Multi "By subproject"
rc_is "board: By subproject is no view, exit 5" 5
err_has "board: the views it names" "unknown view (views: Active, Current sprint, By topic, Needs a status, All)"

# ---------------------------------------------------------------- result
result
