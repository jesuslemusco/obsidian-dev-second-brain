#!/usr/bin/env bash
# Area subprojects: scaffold subproject, subproject, and how the other commands take one.
# Usage: bash scripts/test.sh subprojects, or bash scripts/tests/subprojects.sh
. "$(dirname "$0")/lib.sh"

sb scaffold vault

# ---------------------------------------------------------------- subprojects
M="work/multi"
MF="$vault/$M/claude/profile.md"
mkdir -p "$tmp/mcode/multi-app/src" "$tmp/mcode/multi-infra/mod/deep" "$tmp/far/multi-tools/lib" "$tmp/loose/multi-loose/x"
sb scaffold project Multi --path "$M" --keys MU
edit "$MF" "s|^repos: \\[\\]\$|repos: [multi-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/mcode\"|"
edit "$MF" 's|^base_branch: main$|base_branch: develop|; s|^production_branch: ""$|production_branch: release|; s|^environments: \[\]$|environments: [dev, prod]|'
sb subproject Multi
rc_is "subproject: a project with none exits 0" 0
out_is "subproject: and lists nothing" ""
sb context --cwd "$tmp/mcode/multi-app/src"
is "subproject: with none, context keeps its four lines" "$(lines "$OUT")" "4"
out_lacks "subproject: with none, context has no subproject line" "subproject:"
sb repo Multi
out_is "subproject: with none, repo lists the profile's repos" "multi-app${TAB}$oT/mcode/multi-app${TAB}ok"
sb subproject
rc_is "subproject: no project gives exit 5" 5
sb subproject Multi infra extra
rc_is "subproject: too many arguments give exit 5" 5
sb subproject Nope
rc_is "subproject: an unknown project gives exit 1" 1
sb subproject Multi infra
rc_is "subproject: an unknown subproject gives exit 1" 1
err_has "subproject: the message says how to list them" "second-brain subproject Multi"

sb scaffold subproject Multi infra --repos multi-infra
rc_is "scaffold subproject: exit 0" 0
out_is "scaffold subproject: prints the note and the docs hub" "$M/claude/subprojects/infra.md
$M/docs/infra/README.md"
line_is "scaffold subproject: the note's type" "$vault/$M/claude/subprojects/infra.md" "type: subproject"
line_is "scaffold subproject: the note's repos" "$vault/$M/claude/subprojects/infra.md" "repos: [multi-infra]"
line_is "scaffold subproject: the note has a Rules section" "$vault/$M/claude/subprojects/infra.md" "## Rules"
line_is "scaffold subproject: the note says how to read its settings" "$vault/$M/claude/subprojects/infra.md" 'Read these settings with `second-brain subproject "Multi" "infra"`, which fills in'
line_is "scaffold subproject: the first repo is the default for branch checks" "$vault/$M/claude/subprojects/infra.md" '- `repos`: the subproject'"'"'s repositories, the first the default for branch checks.'
line_is "scaffold subproject: an empty key takes the profile's value" "$vault/$M/claude/subprojects/infra.md" '- `base_branch` to `validation_home` are the profile'"'"'s keys. One left empty takes the value in'
line_is "scaffold subproject: the note links the profile" "$vault/$M/claude/subprojects/infra.md" "  [[$M/claude/profile|Multi Profile]]."
line_is "scaffold subproject: the note links its docs" "$vault/$M/claude/subprojects/infra.md" "- Its docs live in [[$M/docs/infra/README|Multi infra Docs]]."
line_is "scaffold subproject: the Rules placeholder" "$vault/$M/claude/subprojects/infra.md" "- <A rule Claude must follow in this subproject, one per bullet.>"
line_is "scaffold subproject: the docs hub links up to the topics hub" "$vault/$M/docs/infra/README.md" "> Up: [[$M/docs/README|Multi Docs Hub]]"
line_is "scaffold subproject: the docs hub points to the note" "$vault/$M/docs/infra/README.md" "The subproject's repositories, branches and rules are in [[$M/claude/subprojects/infra|Multi infra Subproject]]."
line_is "scaffold subproject: the docs hub says each folder is a topic" "$vault/$M/docs/infra/README.md" "Each folder under this one is a topic, tagged with its path below the topics root."
line_is "scaffold subproject: the topics hub links down to it" "$vault/$M/docs/README.md" "- [[$M/docs/infra/README|Multi infra Docs]] - the docs of the infra subproject"
sb scaffold subproject Multi infra
rc_is "scaffold subproject: again, exit 0" 0
err_has "scaffold subproject: again, it overwrites nothing" "exists: $M/claude/subprojects/infra.md"
is "scaffold subproject: again, the topics hub keeps one line" "$(grep -c "docs/infra/README|" "$vault/$M/docs/README.md")" "1"
sb scaffold subproject Multi INFRA
rc_is "scaffold subproject: the same name in another case gives exit 6" 6
sb scaffold subproject Multi tools --repos MULTI-INFRA
rc_is "scaffold subproject: a repository of another subproject gives exit 6" 6
err_has "scaffold subproject: the message names the owner" "already belongs to the subproject infra"
absent "scaffold subproject: nothing is written on a refusal" "$vault/$M/claude/subprojects/tools.md"
for bad in "a/b" ".hidden" "-x" "a|b" "a#b" "a:b" "a*b" "a?b" "a<b" "a>b"; do
  sb scaffold subproject Multi "$bad"
  rc_is "scaffold subproject: the name $bad gives exit 5" 5
done
sb scaffold subproject Multi tools --repos "multi tools"
rc_is "scaffold subproject: a repository name with a blank gives exit 5" 5
sb scaffold subproject Nope tools
rc_is "scaffold subproject: an unknown project gives exit 1" 1

sb subproject Multi
out_is "subproject: one row per subproject: name, repos, docs folder" "infra${TAB}multi-infra${TAB}$M/docs/infra"
sb subproject Multi Infra
rc_is "subproject name: matched without case" 0
out_is "subproject name: every key falls back to the profile while the note leaves it empty" "subproject: infra
note: $M/claude/subprojects/infra.md
docs: $M/docs/infra
repos: multi-infra
base_branch: develop
production_branch: release
branch_pattern: feature/<ID>-<slug>
environments: dev, prod
delivery: direct
spec_home: vault
validation_home: vault
repo_paths: multi-infra=$oT/mcode/multi-infra"
SF="$vault/$M/claude/subprojects/infra.md"
edit "$SF" 's|^base_branch: ""$|base_branch: main|; s|^branch_pattern: ""$|branch_pattern: "infra/<ID>"|; s|^environments: \[\]$|environments:\
  - staging\
  - live|'
sb subproject Multi infra
out_is "subproject name: its own values win, the rest fall back" "subproject: infra
note: $M/claude/subprojects/infra.md
docs: $M/docs/infra
repos: multi-infra
base_branch: main
production_branch: release
branch_pattern: infra/<ID>
environments: staging, live
delivery: direct
spec_home: vault
validation_home: vault
repo_paths: multi-infra=$oT/mcode/multi-infra"

sb repo Multi
out_is "repo: the subproject's repositories follow the profile's" "multi-app${TAB}$oT/mcode/multi-app${TAB}ok
multi-infra${TAB}$oT/mcode/multi-infra${TAB}ok"
sb project --cwd "$tmp/mcode/multi-infra/mod/deep"
out_is "project --cwd: a subproject's repository resolves to its project" "Multi${TAB}$M${TAB}MU"
sb subproject Multi --cwd "$tmp/mcode/multi-infra/mod/deep"
rc_is "subproject --cwd: exit 0 inside its repository" 0
out_has "subproject --cwd: the settings of the subproject" "subproject: infra"
sb subproject Multi --cwd "$tmp/mcode/multi-app/src"
rc_is "subproject --cwd: a repository of the profile alone is in no subproject, exit 1" 1
sb context --cwd "$tmp/mcode/multi-infra/mod"
is "context: five lines in a subproject's repository" "$(lines "$OUT")" "5"
out_has "context: the subproject line, after project_path" "project_path: $M
subproject: infra
sprint:"
sb context --cwd "$tmp/mcode/multi-app"
out_lacks "context: no subproject line in the profile's own repository" "subproject:"

sb scaffold subproject Multi tools --repos multi-tools
SF2="$vault/$M/claude/subprojects/tools.md"
edit "$SF2" "s|^repo_paths: \\[\\]\$|repo_paths: [\"multi-tools=$tmp/far/multi-tools\"]|"
sb repo Multi multi-tools
out_is "repo: a subproject's repo_paths entry gives the location" "$oT/far/multi-tools"
sb subproject Multi --cwd "$tmp/far/multi-tools/lib"
out_has "subproject --cwd: found through the note's repo_paths" "subproject: tools"
sb subproject Multi tools
out_has "subproject name: its own repo_paths" "repo_paths: multi-tools=$oT/far/multi-tools"
sb scaffold subproject Multi loose --repos multi-loose
edit "$MF" 's|^repos_root: .*$|repos_root: ""|'
sb subproject Multi --cwd "$tmp/loose/multi-loose/x"
rc_is "subproject --cwd: with no location recorded, the folder name decides" 0
out_has "subproject --cwd: the folder name names the subproject" "subproject: loose"
sb subproject Multi loose
out_has "subproject name: no location recorded gives no repo_paths" "repo_paths: -"
mkdir -p "$tmp/loose/multi-loose/vendor/multi-app/y"
sb subproject Multi --cwd "$tmp/loose/multi-loose/vendor/multi-app/y"
rc_is "subproject --cwd: a deeper folder named for a repo of the profile alone gives exit 1" 1
sb context --cwd "$tmp/loose/multi-loose/vendor/multi-app/y"
out_lacks "context: no subproject line under a deeper repo of the profile alone" "subproject:"
sb subproject Multi --cwd "$tmp/far"
rc_is "subproject --cwd: a folder in no repository gives exit 1" 1
edit "$MF" "s|^repos_root: \"\"\$|repos_root: \"$tmp/mcode\"|"
sb scaffold subproject Multi tasks --repos tasks
sb subproject Multi --cwd "$vault/$M/tasks"
rc_is "subproject --cwd: a folder of the vault is in no subproject, whatever its name" 1
sb context --cwd "$vault/$M/tasks"
out_lacks "context: no subproject line in a folder of the vault" "subproject:"
out_has "context: the vault folder still gives the project" "project: Multi"
sb scaffold subproject Multi dup --repos "dup-a, DUP-A ,dup-b"
line_is "scaffold subproject: a repo named twice, in any case, is written once" "$vault/$M/claude/subprojects/dup.md" "repos: [dup-a, dup-b]"
printf '%s\n' '---' 'type: subproject' 'repos: [MULTI-APP]' '---' >"$vault/$M/claude/subprojects/again.md"
sb repo Multi
is "repo: a subproject repo that the profile lists in another case is listed once" "$(printf '%s\n' "$OUT" | grep -ic '^multi-app')" "1"
rm -f "$vault/$M/claude/subprojects/again.md"
cp "$MF" "$tmp/multi-profile"
: >"$MF"
printf '%s\n' '---' 'type: subproject' "repos_root: \"$tmp/mcode\"" 'repos: [rr-x]' '---' >"$vault/$M/claude/subprojects/rr.md"
sb repo Multi
out_has "repo: an empty profile gives no repos_root, not a note's" "rr-x${TAB}-${TAB}unknown"
rm -f "$vault/$M/claude/subprojects/rr.md"
cp "$tmp/multi-profile" "$MF"

sb task new MU-1 --project Multi --title "Infra work" --subproject INFRA --envs
rc_is "task new --subproject: exit 0" 0
TM="$vault/$M/tasks/MU-1/README.md"
line_is "task new --subproject: the key holds the note's own spelling" "$TM" "subproject: infra"
line_is "task new --subproject --envs: the subproject's first environment" "$TM" "  staging: { id: MU-1, status: planned }"
is "task new --subproject: the key sits after epic" "$(($(lineno "$TM" 'subproject:') - $(lineno "$TM" 'epic:')))" "1"
sb task head MU-1
out_has "task head: shows the subproject" "subproject: infra"
text="$OUT"
sb task head MU-1 --json
out_has "task head --json: the subproject key, before topics" \
  ",${NL}  \"subproject\": \"infra\",${NL}  \"topics\": "
json_is "task head --json: with a subproject, the same fields as the text" "$HEAD_PY" "$text"
sb task new MU-2 --project Multi --subproject nope
rc_is "task new --subproject: an unknown subproject gives exit 1" 1
absent "task new --subproject: and writes no README" "$vault/$M/tasks/MU-2/README.md"
sb task new MU-2 --project Multi --title "App work"
sb task head MU-2
out_lacks "task head: no subproject line on a task with none" "subproject:"
sb task head MU-2 --json
out_lacks "task head --json: no subproject key on a task with none" '"subproject"'
sb task set MU-2 subproject=Tools
out_is "task set subproject: written as the note is named" "subproject: tools"
is "task set subproject: the key sits after epic" "$(($(lineno "$vault/$M/tasks/MU-2/README.md" 'subproject:') - $(lineno "$vault/$M/tasks/MU-2/README.md" 'epic:')))" "1"
sb task set MU-2 subproject=nope
rc_is "task set subproject: an unknown subproject gives exit 1" 1
line_is "task set subproject: the old value stays" "$vault/$M/tasks/MU-2/README.md" "subproject: tools"
sb task set MU-2 subproject=
out_is "task set subproject: an empty value removes the key" "subproject: (removed)"
sb task new MU-3 --project Multi --title "Tools work" --subproject tools
sb board Multi "By subproject"
is "board By subproject: active tasks by subproject, none last" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | tr '\n' ' ')" "MU-1 MU-3 MU-2 "
is "board By subproject: a tenth column names each row's subproject, - for none" \
  "$(printf '%s\n' "$OUT" | awk -F' [|] ' '{ printf "%s:%s:%s ", NF, $1, $10 }')" "10:MU-1:infra 10:MU-3:tools 10:MU-2:- "
sb board Multi
is "board: the other views keep nine columns" "$(printf '%s\n' "$OUT" | awk -F' [|] ' '{ printf "%s ", NF }')" "9 9 9 "
sb board Multi subproject
is "board: subproject names the By subproject view" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | tr '\n' ' ')" "MU-1 MU-3 MU-2 "
sb board Multi --subproject INFRA
rc_is "board --subproject: exit 0" 0
is "board --subproject: only that subproject's tasks, the name matched without case" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | tr '\n' ' ')" "MU-1 "
edit "$vault/$M/tasks/MU-3/README.md" 's/^subproject: tools$/subproject: TOOLS/'
sb task set MU-3 status=done
sb board Multi All --subproject tools
is "board --subproject: a value written in another case counts, in any view" "$(printf '%s\n' "$OUT" | cut -d' ' -f1 | tr '\n' ' ')" "MU-3 "
sb board Multi --subproject tools
rc_is "board --subproject: the view still applies, exit 0" 0
out_is "board --subproject: a done task is not in the Active view" ""
sb board Multi --subproject nope
rc_is "board --subproject: a name that is no subproject gives exit 1" 1
err_has "board --subproject: the message says how to list them" "second-brain subproject Multi"
sb board Multi --subproject
rc_is "board --subproject: no value gives exit 5" 5
file_has "story-tracker status: inside a subproject's repo, every board call takes its name" "$here/skills/story-tracker/status.md" \
  'add `--subproject <name>` to every `board` call'
file_has "conventions: the board lists the tasks of one subproject" "$vault/obsidian-conventions.md" '`second-brain board <project> --subproject <name>`'

# ---------------------------------------------------------------- result
result
