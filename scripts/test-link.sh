#!/usr/bin/env bash
# Scratch-vault tests for the link and pointer commands: a vault and a link directory in a temp dir.
# Usage: bash scripts/test-link.sh
set -u

here="$(cd "$(dirname "$0")/.." && pwd)"
SB="$here/bin/second-brain"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-link.XXXXXX")" || exit 2
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

vault="$tmp/my vault"
home="$tmp/link home"
mkdir -p "$vault/.obsidian" "$tmp/userdir"
export HOME="$tmp/userdir"
export SECOND_BRAIN_VAULT="$vault"
export SECOND_BRAIN_CLAUDE_HOME="$home"
export SECOND_BRAIN_OBSIDIAN="none"

# On Windows, in Git Bash, the helper makes junctions and prints paths in the drive form.
WIN=0
case "${OSTYPE:-}" in msys* | cygwin*) WIN=1 ;; esac

P="projects/example"
n_pass=0
n_fail=0
OUT=""
ERR=""
RC=0

pass() {
  n_pass=$((n_pass + 1))
  printf 'ok    %s\n' "$1"
}
fail() {
  n_fail=$((n_fail + 1))
  printf 'FAIL  %s\n' "$1"
  shift
  while [ $# -gt 0 ]; do
    printf '      %s\n' "$1"
    shift
  done
}
# run <command...>: capture stdout, stderr and the exit code.
run() {
  OUT="$("$@" 2>"$tmp/stderr")"
  RC=$?
  ERR="$(cat "$tmp/stderr")"
}
sb() { run "$SB" "$@"; }
rc_is() {
  if [ "$RC" -eq "$2" ]; then pass "$1"; else fail "$1" "exit $RC, wanted $2" "stdout: $OUT" "stderr: $ERR"; fi
}
is() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "got:    $2" "wanted: $3"; fi
}
out_is() { is "$1" "$OUT" "$2"; }
# row_is <desc> <exact row>: the row is one whole line of the output.
row_is() {
  if printf '%s\n' "$OUT" | grep -qxF -- "$2"; then pass "$1"; else fail "$1" "no such row: $2" "in: $OUT"; fi
}
out_lacks() {
  case "$OUT" in *"$2"*) fail "$1" "unwanted: $2" "in: $OUT" ;; *) pass "$1" ;; esac
}
# points_at <desc> <link> <target>: the entry is a link holding exactly that target.
points_at() {
  if [ -L "$2" ]; then is "$1" "$(readlink "$2")" "$3"; else fail "$1" "not a link: $2"; fi
}
# leads_to <desc> <link> <folder>: the entry is a link and opens that folder.
leads_to() {
  if [ -L "$2" ] && [ "$2" -ef "$3" ]; then pass "$1"; else fail "$1" "not a link to $3: $2"; fi
}
absent() {
  if [ -e "$2" ] || [ -L "$2" ]; then fail "$1" "should not exist: $2"; else pass "$1"; fi
}
exists_dir() {
  if [ -d "$2" ] && [ ! -L "$2" ]; then pass "$1"; else fail "$1" "not a real folder: $2"; fi
}
# shown <path>: the path as the helper prints it.
shown() {
  if [ "$WIN" -eq 1 ]; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}
# symlink <target> <link>: a real symlink on every system, to build a fixture.
symlink() {
  if [ "$WIN" -eq 1 ]; then MSYS=winsymlinks:nativestrict ln -s "$1" "$2"; else ln -s "$1" "$2"; fi
}
# is_junction <desc> <path>: Windows holds the entry as a junction, not a symlink and not a copy.
is_junction() {
  if fsutil reparsepoint query "$(cygpath -w "$2")" 2>/dev/null | grep -qi '0xa0000003'; then pass "$1"; else fail "$1" "not a junction: $2"; fi
}
# skill <claude folder> <folder name> <frontmatter name>: write a skill.
skill() {
  mkdir -p "$1/skills/$2"
  printf -- '---\nname: %s\ndescription: A test skill.\n---\n\n# %s\n' "$3" "$2" >"$1/skills/$2/SKILL.md"
}
# agent <claude folder> <file name without .md> <frontmatter name>: write an agent.
agent() {
  mkdir -p "$1/agents"
  printf -- '---\nname: %s\ndescription: A test agent.\n---\n\nAn agent.\n' "$3" >"$1/agents/$2.md"
}

if [ "$WIN" -eq 1 ]; then
  symlink "$tmp/userdir" "$tmp/fixture-check" 2>/dev/null
  if [ ! -L "$tmp/fixture-check" ]; then
    printf 'test-link: the fixtures need real symlinks; turn on Developer Mode or run in an elevated shell\n' >&2
    exit 2
  fi
  rm "$tmp/fixture-check"
fi

# ---------------------------------------------------------------- setup
sb scaffold vault
rc_is "setup: scaffold vault" 0
sb scaffold project Example --path "$P" --keys EX
rc_is "setup: scaffold project" 0

# ---------------------------------------------------------------- usage and no vault
sb link --nope
rc_is "link: unknown flag gives exit 5" 5
sb link --check --apply
rc_is "link: two flags give exit 5" 5
run env SECOND_BRAIN_VAULT="$tmp/nowhere" "$SB" link
rc_is "link: no vault gives exit 2" 2

# ---------------------------------------------------------------- sources
skill "$vault/claude" my-skill my-skill
agent "$vault/claude" my-agent my-agent
skill "$vault/$P/claude" ex-skill ex-skill
agent "$vault/$P/claude" ex-agent ex-agent
printf '# Agents\n' >"$vault/claude/agents/README.md"
printf '# Agents\n' >"$vault/$P/claude/agents/README.md"
mkdir -p "$vault/claude/skills/no-skill-file"
VS="$vault/claude/skills/my-skill"
VA="$vault/claude/agents/my-agent.md"
PS="$vault/$P/claude/skills/ex-skill"
PA="$vault/$P/claude/agents/ex-agent.md"
outside="$tmp/outside"

# The same places as the helper prints them.
oV="$(shown "$vault")"
oO="$(shown "$outside")"
oVS="$oV/claude/skills/my-skill"
oVA="$oV/claude/agents/my-agent.md"
oPS="$oV/$P/claude/skills/ex-skill"
oPA="$oV/$P/claude/agents/ex-agent.md"

# An agent's link: where it sits (S), what it leads to (L), the agent file seen through it (F),
# a dead target for it (D), and the name a link left behind there is listed under (N).
# On Windows the link is the junction of the agent's folder; elsewhere a symlink to its file.
if [ "$WIN" -eq 1 ]; then
  SVA="$home/agents/second-brain-vault"
  LVA="$vault/claude/agents"
  SPA="$home/agents/second-brain-project-projects-example"
  LPA="$vault/$P/claude/agents"
  FPA="$SPA/ex-agent.md"
  DPA="$vault/$P/claude/old-agents"
  NPA="second-brain-project-projects-example"
else
  SVA="$home/agents/my-agent.md"
  LVA="$VA"
  SPA="$home/agents/ex-agent.md"
  LPA="$PA"
  FPA="$SPA"
  DPA="$vault/$P/claude/agents/old-name.md"
  NPA="ex-agent"
fi
oLPA="$oV/${LPA#"$vault"/}"
oDPA="$oV/${DPA#"$vault"/}"

MISSING="my-skill | skill | missing | $oVS
my-agent | agent | missing | $oVA
ex-skill | skill | missing | $oPS
ex-agent | agent | missing | $oPA"

# ---------------------------------------------------------------- check, nothing linked
sb link
rc_is "check: exit 1 while items are missing" 1
out_is "check: the four items are missing, README.md is ignored" "$MISSING"
sb link --check
rc_is "check: --check exits 1 too" 1
out_is "check: --check prints the same rows" "$MISSING"
absent "check: creates no link directory" "$home"

# ---------------------------------------------------------------- apply
LINKED="my-skill | skill | linked | $oVS
my-agent | agent | linked | $oVA
ex-skill | skill | linked | $oPS
ex-agent | agent | linked | $oPA"
sb link --apply
rc_is "apply: exit 0" 0
out_is "apply: prints the rows as they now are" "$LINKED"
points_at "apply: vault skill link" "$home/skills/my-skill" "$VS"
points_at "apply: vault agent link" "$SVA" "$LVA"
points_at "apply: project skill link" "$home/skills/ex-skill" "$PS"
points_at "apply: project agent link" "$SPA" "$LPA"
is "apply: the skill link resolves to its SKILL.md" "$(sed -n 2p "$home/skills/my-skill/SKILL.md")" "name: my-skill"
is "apply: the agent link resolves to the file" "$(sed -n 2p "$FPA")" "name: ex-agent"
absent "apply: README.md in an agents folder is not linked" "$home/agents/README.md"
absent "apply: a folder with no SKILL.md is not linked" "$home/skills/no-skill-file"
is "apply: says what it linked" "$(printf '%s\n' "$ERR" | grep -c '^note: linked: ')" "4"
if [ "$WIN" -eq 1 ]; then
  is_junction "apply: on Windows a skill link is a junction" "$home/skills/my-skill"
  is_junction "apply: on Windows an agents link is a junction" "$SVA"
  absent "apply: on Windows no agent file is linked by itself" "$home/agents/my-agent.md"
  is "apply: on Windows the agents folder holds the two junctions" "$(LC_ALL=C ls "$home/agents" | tr '\n' ' ')" "second-brain-project-projects-example second-brain-vault "
fi
sb link --check
rc_is "check after apply: exit 0" 0
out_is "check after apply: all linked" "$LINKED"
before="$(ls -l "$home/skills" "$home/agents")"
sb link --apply
rc_is "second apply: exit 0" 0
out_is "second apply: same rows" "$LINKED"
is "second apply: says nothing" "$ERR" ""
is "second apply: changes nothing" "$(ls -l "$home/skills" "$home/agents")" "$before"

# ---------------------------------------------------------------- foreign entries
mkdir -p "$outside/other-skill" "$home/skills/real-skill"
printf 'mine\n' >"$home/skills/real-skill/SKILL.md"
printf 'mine\n' >"$home/agents/real-agent.md"
printf 'theirs\n' >"$outside/other-agent.md"
symlink "$outside/other-skill" "$home/skills/other-skill"
symlink "$outside/other-agent.md" "$home/agents/other-agent.md"
sb link --check
rc_is "foreign: exit 0, foreign entries do not count" 0
row_is "foreign: a symlink pointing outside the vault" "other-skill | skill | foreign | $oO/other-skill"
row_is "foreign: an agent symlink pointing outside" "other-agent | agent | foreign | $oO/other-agent.md"
row_is "foreign: a real folder" "real-skill | skill | foreign | -"
row_is "foreign: a real file" "real-agent | agent | foreign | -"
row_is "foreign: the vault items stay linked" "my-skill | skill | linked | $oVS"
sb link --apply
rc_is "foreign: apply exits 0" 0
is "foreign: apply says nothing" "$ERR" ""
points_at "foreign: the outside symlink is untouched" "$home/skills/other-skill" "$outside/other-skill"
points_at "foreign: the outside agent symlink is untouched" "$home/agents/other-agent.md" "$outside/other-agent.md"
is "foreign: the real folder is untouched" "$(cat "$home/skills/real-skill/SKILL.md")" "mine"
is "foreign: the real folder is still a folder" "$([ -d "$home/skills/real-skill" ] && [ ! -L "$home/skills/real-skill" ] && echo yes)" "yes"
is "foreign: the real file is untouched" "$(cat "$home/agents/real-agent.md")" "mine"

# ---------------------------------------------------------------- wrong target
mkdir -p "$vault/notes/elsewhere"
rm "$home/skills/my-skill" "$SVA"
symlink "$vault/notes/elsewhere" "$home/skills/my-skill"
symlink "../../my vault/${LPA#"$vault"/}" "$SVA"
sb link --check
rc_is "wrong target: exit 1" 1
row_is "wrong target: a link to another vault folder" "my-skill | skill | wrong-target | $oV/notes/elsewhere"
row_is "wrong target: a relative link is resolved" "my-agent | agent | wrong-target | $oLPA"
points_at "wrong target: check changes nothing" "$home/skills/my-skill" "$vault/notes/elsewhere"
sb link --apply
rc_is "wrong target: apply exits 0" 0
out_lacks "wrong target: none left after apply" "wrong-target"
points_at "wrong target: the skill link is repointed" "$home/skills/my-skill" "$VS"
points_at "wrong target: the agent link is repointed" "$SVA" "$LVA"
is "wrong target: apply says what it repointed" "$(printf '%s\n' "$ERR" | grep -c '^note: repointed: ')" "2"
exists_dir "wrong target: the old target folder is kept" "$vault/notes/elsewhere"
is "wrong target: what the agent link led to is kept" "$(sed -n 2p "$PA")" "name: ex-agent"

rm "$home/skills/ex-skill"
symlink "$outside/other-skill" "$home/skills/ex-skill"
sb link --apply
rc_is "wrong target outside the vault: apply exits 1" 1
row_is "wrong target outside the vault: reported" "ex-skill | skill | wrong-target | $oO/other-skill"
points_at "wrong target outside the vault: left alone" "$home/skills/ex-skill" "$outside/other-skill"
rm "$home/skills/ex-skill"
symlink "$vault/notes/elsewhere" "$outside/hop"
symlink "$outside/hop" "$home/skills/ex-skill"
sb link --apply
rc_is "wrong target through an outside link: apply exits 1" 1
row_is "wrong target through an outside link: the first hop decides" "ex-skill | skill | wrong-target | $oO/hop"
points_at "wrong target through an outside link: left alone" "$home/skills/ex-skill" "$outside/hop"
rm "$home/skills/ex-skill"
mkdir "$home/skills/ex-skill"
printf 'mine\n' >"$home/skills/ex-skill/keep.txt"
sb link --apply
rc_is "real folder at a vault name: apply exits 1" 1
row_is "real folder at a vault name: reported with no target" "ex-skill | skill | wrong-target | -"
is "real folder at a vault name: a note says why" "$ERR" "note: ex-skill: a real file or folder holds this name in the link directory; it is left alone"
exists_dir "real folder at a vault name: still a folder" "$home/skills/ex-skill"
is "real folder at a vault name: nothing is put inside it" "$(ls "$home/skills/ex-skill")" "keep.txt"
rm -r "$home/skills/ex-skill"
sb link --apply
rc_is "wrong target: clean again once the folder is gone" 0

# A real entry where an agent's link belongs: on Windows that place is the folder's junction.
rm "$SVA"
if [ "$WIN" -eq 1 ]; then
  mkdir "$SVA"
  held="the name second-brain-vault"
else
  printf 'mine\n' >"$SVA"
  held="this name"
fi
sb link --apply
rc_is "real entry at an agent's place: apply exits 1" 1
row_is "real entry at an agent's place: reported with no target" "my-agent | agent | wrong-target | -"
is "real entry at an agent's place: a note names what holds it" "$ERR" "note: my-agent: a real file or folder holds $held in the link directory; it is left alone"
if [ -e "$SVA" ] && [ ! -L "$SVA" ]; then pass "real entry at an agent's place: left alone"; else fail "real entry at an agent's place: left alone" "$SVA"; fi
rm -r "$SVA"
sb link --apply
rc_is "real entry at an agent's place: clean again once it is gone" 0

# ---------------------------------------------------------------- dangling
symlink "$vault/claude/skills/gone-skill" "$home/skills/gone-skill"
symlink "$vault/$P/claude/agents/gone-agent.md" "$home/agents/gone-agent.md"
symlink "$outside/gone-skill" "$home/skills/lost-skill"
rm "$SPA"
symlink "$DPA" "$SPA"
sb link --check
rc_is "dangling: exit 1" 1
row_is "dangling: a dead link into the vault" "gone-skill | skill | dangling | $oV/claude/skills/gone-skill"
row_is "dangling: a dead agent link into the vault" "gone-agent | agent | dangling | $oV/$P/claude/agents/gone-agent.md"
row_is "dangling: a dead link pointing outside" "lost-skill | skill | dangling | $oO/gone-skill"
row_is "dangling: a dead link at a vault name" "ex-agent | agent | dangling | $oDPA"
points_at "dangling: check changes nothing" "$home/skills/gone-skill" "$vault/claude/skills/gone-skill"
sb link --apply
rc_is "dangling: apply exits 1 while the outside one is left" 1
absent "dangling: the dead link into the vault is removed" "$home/skills/gone-skill"
absent "dangling: the dead agent link into the vault is removed" "$home/agents/gone-agent.md"
points_at "dangling: the dead link pointing outside is left" "$home/skills/lost-skill" "$outside/gone-skill"
points_at "dangling: the dead link at a vault name is repointed" "$SPA" "$LPA"
out_lacks "dangling: the removed skill row is gone" "gone-skill | skill"
out_lacks "dangling: the removed agent row is gone" "gone-agent | agent"
row_is "dangling: the outside one is still reported" "lost-skill | skill | dangling | $oO/gone-skill"
is "dangling: apply says what it removed" "$(printf '%s\n' "$ERR" | grep -c '^note: removed: ')" "2"
rm "$home/skills/lost-skill"
sb link --check
rc_is "dangling: exit 0 once the outside one is removed by hand" 0

# A link the helper made dies when its source is deleted from the vault.
skill "$vault/claude" short-lived short-lived
sb link --apply
rc_is "dangling after a delete: the new skill is linked first" 0
rm -r "$vault/claude/skills/short-lived"
mv "$vault/$P/claude/agents" "$vault/$P/claude/agents-away"
sb link --check
rc_is "dangling after a delete: exit 1" 1
row_is "dangling after a delete: the skill link is dead" "short-lived | skill | dangling | $oV/claude/skills/short-lived"
row_is "dangling after a delete: the agent link is dead" "$NPA | agent | dangling | $oLPA"
sb link --apply
rc_is "dangling after a delete: apply exits 0" 0
absent "dangling after a delete: the skill link is removed" "$home/skills/short-lived"
absent "dangling after a delete: the agent link is removed" "$SPA"
is "dangling after a delete: apply says what it removed" "$(printf '%s\n' "$ERR" | grep -c '^note: removed: ')" "2"
is "dangling after a delete: the moved agents folder is whole" "$(LC_ALL=C ls "$vault/$P/claude/agents-away" | tr '\n' ' ')" "README.md ex-agent.md "
mv "$vault/$P/claude/agents-away" "$vault/$P/claude/agents"
sb link --apply
rc_is "dangling after a delete: the agent is linked again" 0
points_at "dangling after a delete: its link is back" "$SPA" "$LPA"

# ---------------------------------------------------------------- name mismatch
skill "$vault/claude" odd-folder other-name
agent "$vault/$P/claude" odd-agent other-agent-name
mkdir -p "$vault/claude/skills/no-name"
printf -- '---\ndescription: No name key.\n---\n' >"$vault/claude/skills/no-name/SKILL.md"
sb link --check
rc_is "name mismatch: exit 1" 1
row_is "name mismatch: a skill folder named unlike its frontmatter" "odd-folder | skill | name-mismatch | $oV/claude/skills/odd-folder"
row_is "name mismatch: an agent file named unlike its frontmatter" "odd-agent | agent | name-mismatch | $oV/$P/claude/agents/odd-agent.md"
row_is "name mismatch: a skill with no name key" "no-name | skill | name-mismatch | $oV/claude/skills/no-name"
sb link --apply
rc_is "name mismatch: apply exits 1" 1
row_is "name mismatch: still reported after apply" "odd-folder | skill | name-mismatch | $oV/claude/skills/odd-folder"
absent "name mismatch: not linked by its folder name" "$home/skills/odd-folder"
absent "name mismatch: not linked by its frontmatter name" "$home/skills/other-name"
absent "name mismatch: the agent is not linked" "$home/agents/odd-agent.md"
absent "name mismatch: the nameless skill is not linked" "$home/skills/no-name"
row_is "name mismatch: the good items stay linked" "my-skill | skill | linked | $oVS"
if [ "$WIN" -eq 1 ]; then
  row_is "name mismatch: on Windows the folder's good agent stays linked" "ex-agent | agent | linked | $oPA"
  is "name mismatch: on Windows the file sits in its linked folder all the same" "$(sed -n 2p "$SPA/odd-agent.md")" "name: other-agent-name"
fi
rm -r "$vault/claude/skills/odd-folder" "$vault/claude/skills/no-name" "$vault/$P/claude/agents/odd-agent.md"

# ---------------------------------------------------------------- duplicate
skill "$vault/claude" twin twin
skill "$vault/$P/claude" twin twin
agent "$vault/claude" ex-agent ex-agent
sb link --check
rc_is "duplicate: exit 1" 1
row_is "duplicate: the vault copy" "twin | skill | duplicate | $oV/claude/skills/twin"
row_is "duplicate: the project copy" "twin | skill | duplicate | $oV/$P/claude/skills/twin"
row_is "duplicate: an agent that was linked before" "ex-agent | agent | duplicate | $oPA"
sb link --apply
rc_is "duplicate: apply exits 1" 1
absent "duplicate: the skill is not linked" "$home/skills/twin"
points_at "duplicate: the earlier agent link is left as it was" "$SPA" "$LPA"
row_is "duplicate: still reported after apply" "twin | skill | duplicate | $oV/claude/skills/twin"
rm -r "$vault/$P/claude/skills/twin" "$vault/claude/agents/ex-agent.md"
sb link --apply
rc_is "duplicate: apply exits 0 once one copy is gone" 0
points_at "duplicate: the remaining copy is linked" "$home/skills/twin" "$vault/claude/skills/twin"

# ---------------------------------------------------------------- several agents in one folder
agent "$vault/claude" second-agent second-agent
oSA="$oV/claude/agents/second-agent.md"
sb link --check
if [ "$WIN" -eq 1 ]; then
  FSA="$SVA/second-agent.md"
  rc_is "second agent in a folder: on Windows exit 0, its folder is linked already" 0
  row_is "second agent in a folder: on Windows linked at once" "second-agent | agent | linked | $oSA"
else
  FSA="$home/agents/second-agent.md"
  rc_is "second agent in a folder: exit 1 until it is linked" 1
  row_is "second agent in a folder: missing" "second-agent | agent | missing | $oSA"
fi
sb link --apply
rc_is "second agent in a folder: apply exits 0" 0
row_is "second agent in a folder: linked" "second-agent | agent | linked | $oSA"
row_is "second agent in a folder: the first stays linked" "my-agent | agent | linked | $oVA"
is "second agent in a folder: its file opens through the link directory" "$(sed -n 2p "$FSA")" "name: second-agent"

rm "$SVA"
[ "$WIN" -eq 1 ] || rm "$FSA"
sb link --check
rc_is "two agents, nothing linked: exit 1" 1
row_is "two agents, nothing linked: the first is missing" "my-agent | agent | missing | $oVA"
row_is "two agents, nothing linked: the second is missing" "second-agent | agent | missing | $oSA"
sb link --apply
rc_is "two agents, nothing linked: apply exits 0" 0
is "two agents, nothing linked: apply names each agent it linked" "$(printf '%s\n' "$ERR" | sort | tr '\n' ' ')" "note: linked: agent my-agent note: linked: agent second-agent "
row_is "two agents, nothing linked: the second is linked" "second-agent | agent | linked | $oSA"
points_at "two agents, nothing linked: the link is made" "$SVA" "$LVA"

rm "$SVA"
if [ "$WIN" -eq 1 ]; then
  symlink "$vault/notes/elsewhere" "$SVA"
  oWrong="$oV/notes/elsewhere"
else
  rm "$FSA"
  symlink "$PA" "$SVA"
  symlink "$PA" "$FSA"
  oWrong="$oPA"
fi
sb link --check
rc_is "two agents, wrong target: exit 1" 1
row_is "two agents, wrong target: the first" "my-agent | agent | wrong-target | $oWrong"
row_is "two agents, wrong target: the second" "second-agent | agent | wrong-target | $oWrong"
sb link --apply
rc_is "two agents, wrong target: apply exits 0" 0
is "two agents, wrong target: apply names each agent it repointed" "$(printf '%s\n' "$ERR" | sort | tr '\n' ' ')" "note: repointed: agent my-agent note: repointed: agent second-agent "
points_at "two agents, wrong target: the link is repointed" "$SVA" "$LVA"
is "two agents, wrong target: both files open through the link directory" "$(sed -n 2p "$FSA")" "name: second-agent"
exists_dir "two agents, wrong target: the old target folder is kept" "$vault/notes/elsewhere"
rm "$vault/claude/agents/second-agent.md"
sb link --apply
rc_is "two agents: clean again once the second is deleted" 0
out_lacks "two agents: the deleted one has no row" "second-agent"

# ---------------------------------------------------------------- two folders, one junction name
# On Windows projects/example and projects-example give their agents folders the same junction name.
sb scaffold project Clash --path projects-example
agent "$vault/projects-example/claude" clash-agent clash-agent
oCA="$oV/projects-example/claude/agents/clash-agent.md"
sb link --apply
if [ "$WIN" -eq 1 ]; then
  rc_is "one junction name for two folders: on Windows apply exits 1" 1
  row_is "one junction name for two folders: on Windows the later folder's agent is a duplicate" "clash-agent | agent | duplicate | $oCA"
  row_is "one junction name for two folders: on Windows the first folder's agent stays linked" "ex-agent | agent | linked | $oPA"
  points_at "one junction name for two folders: on Windows the junction still leads to the first" "$SPA" "$LPA"
  is "one junction name for two folders: on Windows apply does nothing" "$ERR" ""
else
  rc_is "project paths alike but for a slash: apply exits 0" 0
  row_is "project paths alike but for a slash: the second project's agent is linked" "clash-agent | agent | linked | $oCA"
  row_is "project paths alike but for a slash: the first project's agent stays linked" "ex-agent | agent | linked | $oPA"
fi
rm -r "$vault/projects-example/claude/agents"
sb link --apply
rc_is "one junction name for two folders: clean again once the second has no agents" 0
points_at "one junction name for two folders: the first folder's link is as it was" "$SPA" "$LPA"

# ---------------------------------------------------------------- edges
symlink "$VS" "$home/skills/alias-skill"
sb link --apply
rc_is "extra link into the vault: exit 0" 0
row_is "extra link into the vault: foreign, the scan owns no such name" "alias-skill | skill | foreign | $oVS"
points_at "extra link into the vault: untouched" "$home/skills/alias-skill" "$VS"
rm "$home/skills/alias-skill"

sb scaffold project Bare --path projects/bare
rm -r "$vault/projects/bare/claude"
printf '| Ghost | projects/ghost | | A folder that is not there. |\n' >>"$vault/CLAUDE.md"
sb link --check
rc_is "project without a claude folder: exit 0" 0
out_lacks "project without a claude folder: no row" "projects/bare"
out_lacks "index row without a folder: no row" "projects/ghost"

case "$vault" in
  *" "*) pass "space in the vault path: the scratch vault has one" ;;
  *) fail "space in the vault path: the scratch vault has one" "$vault" ;;
esac
case "$home" in
  *" "*) pass "space in the link directory's path: the scratch one has one" ;;
  *) fail "space in the link directory's path: the scratch one has one" "$home" ;;
esac
row_is "space in the vault path: rows carry the whole path" "my-skill | skill | linked | $oVS"
is "space in the vault path: the link opens" "$(sed -n 2p "$home/skills/twin/SKILL.md")" "name: twin"
out_lacks "plugin skills: none is ever listed" "$(shown "$here")/"

mkdir -p "$tmp/userdir/.claude/skills/home-skill"
run env -u SECOND_BRAIN_CLAUDE_HOME "$SB" link --check
rc_is "default link directory: exit 1, nothing is linked there" 1
row_is "default link directory: the .claude folder in the home" "home-skill | skill | foreign | -"
row_is "default link directory: the vault items are missing there" "my-skill | skill | missing | $oVS"

# ---------------------------------------------------------------- pointer
phome="$tmp/pointer home"
ptr="$phome/second-brain-vault"
other="$tmp/other vault"
mkdir -p "$other/.obsidian" "$tmp/not a vault"
oOther="$(shown "$other")"
# pt <args...>: run the pointer command against its own link directory.
pt() { run env SECOND_BRAIN_CLAUDE_HOME="$phome" "$SB" pointer "$@"; }

pt
rc_is "pointer: exit 2 when there is none" 2
out_is "pointer: prints nothing when there is none" ""
pt nope
rc_is "pointer: an unknown word gives exit 5" 5
pt set
rc_is "pointer set: no folder gives exit 5" 5
pt set "$vault" --nope
rc_is "pointer set: an unknown flag gives exit 5" 5
pt set "$vault" "$other"
rc_is "pointer set: two folders give exit 5" 5
pt set "$tmp/not a vault"
rc_is "pointer set: a folder with no .obsidian gives exit 5" 5
pt set "$tmp/nowhere"
rc_is "pointer set: a missing folder gives exit 5" 5
absent "pointer set: a refusal creates no link directory" "$phome"

pt set "$vault"
rc_is "pointer set: exit 0" 0
out_is "pointer set: prints the folder the pointer leads to" "$oV"
points_at "pointer set: the pointer is a link to the vault" "$ptr" "$vault"
is "pointer set: the vault opens through it" "$(ls -d "$ptr/.obsidian")" "$ptr/.obsidian"
[ "$WIN" -eq 0 ] || is_junction "pointer set: on Windows the pointer is a junction" "$ptr"
pt
rc_is "pointer: exit 0" 0
out_is "pointer: prints the folder it leads to" "$oV"
before="$(ls -l "$phome")"
pt set "$vault"
rc_is "pointer set again: exit 0" 0
out_is "pointer set again: prints the folder" "$oV"
is "pointer set again: the pointer is left alone" "$(ls -l "$phome")" "$before"

pt set "$other"
rc_is "pointer set elsewhere: exit 6" 6
out_is "pointer set elsewhere: prints nothing" ""
is "pointer set elsewhere: the message names where the pointer leads" "$ERR" "second-brain: the pointer leads elsewhere: $oV (add --replace to repoint it)"
points_at "pointer set elsewhere: the pointer is kept" "$ptr" "$vault"
pt set "$other" --replace
rc_is "pointer set --replace: exit 0" 0
out_is "pointer set --replace: prints the new folder" "$oOther"
points_at "pointer set --replace: the pointer leads to the new folder" "$ptr" "$other"
exists_dir "pointer set --replace: the old vault is kept" "$vault/.obsidian"
pt
out_is "pointer: follows the change" "$oOther"
pt set --replace "$vault"
rc_is "pointer set: the flag may come first" 0
points_at "pointer set: the flag first repoints too" "$ptr" "$vault"
cd "$tmp" || exit 2
pt set "other vault" --replace
cd "$here" || exit 2
rc_is "pointer set: a relative folder is taken" 0
out_is "pointer set: a relative folder is printed whole" "$oOther"
points_at "pointer set: a relative folder is stored whole" "$ptr" "$other"

gone="$tmp/gone vault"
mkdir -p "$gone/.obsidian"
pt set "$gone" --replace
rm -r "$gone"
pt
rc_is "dead pointer: exit 0" 0
out_is "dead pointer: prints where it leads" "$(shown "$gone")"
is "dead pointer: a note says the folder is missing" "$ERR" "note: the pointer leads to a folder that is missing"
pt set "$vault"
rc_is "dead pointer: set gives exit 6" 6
is "dead pointer: the message names where it leads" "$ERR" "second-brain: the pointer leads elsewhere: $(shown "$gone") (add --replace to repoint it)"
pt set "$vault" --replace
rc_is "dead pointer: --replace repoints it" 0
points_at "dead pointer: it leads to the vault again" "$ptr" "$vault"

rm "$ptr"
mkdir "$ptr"
printf 'mine\n' >"$ptr/keep.txt"
pt
rc_is "real folder in the pointer's place: pointer gives exit 2" 2
pt set "$vault"
rc_is "real folder in the pointer's place: set gives exit 6" 6
pt set "$vault" --replace
rc_is "real folder in the pointer's place: --replace gives exit 6 too" 6
is "real folder in the pointer's place: the message says it is never replaced" "$ERR" "second-brain: a real file or folder holds the pointer's place and is never replaced: $(shown "$ptr")"
exists_dir "real folder in the pointer's place: still a folder" "$ptr"
is "real folder in the pointer's place: nothing changes inside it" "$(ls "$ptr")" "keep.txt"
rm -r "$ptr"
printf 'mine\n' >"$ptr"
pt set "$vault" --replace
rc_is "real file in the pointer's place: exit 6" 6
is "real file in the pointer's place: untouched" "$(cat "$ptr")" "mine"
rm "$ptr"

# Folder names that a command line could cut or expand, and one with an accent.
n=0
for odd in 'r&d^a,b;c=d%PATH%!e' 'R&D (x86) 100% sure' "$(printf 'caf\303\251') notes"; do
  n=$((n + 1))
  xhome="$tmp/odd$n/$odd/home"
  xvault="$tmp/odd$n/$odd/vault"
  mkdir -p "$xvault/.obsidian"
  printf 'here\n' >"$xvault/mark.txt"
  run env SECOND_BRAIN_CLAUDE_HOME="$xhome" "$SB" pointer set "$xvault"
  rc_is "awkward folder name $n: pointer set exits 0" 0
  out_is "awkward folder name $n: prints the folder" "$(shown "$(cd -P "$xvault" && pwd -P)")"
  leads_to "awkward folder name $n: the pointer leads there" "$xhome/second-brain-vault" "$xvault"
  is "awkward folder name $n: the vault opens through it" "$(cat "$xhome/second-brain-vault/mark.txt" 2>&1)" "here"
  run env SECOND_BRAIN_CLAUDE_HOME="$xhome" "$SB" pointer
  out_is "awkward folder name $n: pointer prints it back" "$(shown "$(cd -P "$xvault" && pwd -P)")"
  is "awkward folder name $n: the link directory holds the pointer alone" "$(ls "$xhome")" "second-brain-vault"
done

if [ "$WIN" -eq 1 ]; then
  pt set "$(cygpath -w "$vault")"
  rc_is "pointer set: on Windows a folder written with backslashes is taken" 0
  out_is "pointer set: on Windows it is printed in the drive form" "$oV"
  points_at "pointer set: on Windows the backslash form leads to the vault" "$ptr" "$vault"
  rm "$ptr"
  pt set "$(cygpath -m "$vault")"
  rc_is "pointer set: on Windows a folder in the drive form is taken" 0
  points_at "pointer set: on Windows the drive form leads to the vault" "$ptr" "$vault"
  run env SECOND_BRAIN_CLAUDE_HOME="$(cygpath -w "$phome")" "$SB" pointer
  rc_is "pointer: on Windows the link directory may be written with backslashes" 0
  out_is "pointer: on Windows it prints the same folder then" "$oV"
  case "$oV" in
    [A-Z]:/*) pass "paths: on Windows the printed form starts with a drive" ;;
    *) fail "paths: on Windows the printed form starts with a drive" "$oV" ;;
  esac
fi

run env -u SECOND_BRAIN_CLAUDE_HOME "$SB" pointer set "$vault"
rc_is "default link directory: pointer set exits 0" 0
points_at "default link directory: the pointer sits in the .claude folder of the home" "$tmp/userdir/.claude/second-brain-vault" "$vault"
run env -u SECOND_BRAIN_CLAUDE_HOME -u SECOND_BRAIN_VAULT "$SB" root
rc_is "default link directory: the helper finds the vault through the pointer" 0
if [ "$OUT" -ef "$vault" ]; then pass "default link directory: root is the vault"; else fail "default link directory: root is the vault" "got: $OUT"; fi

# ---------------------------------------------------------------- the SessionStart hook
hook="$(sed -n 's/^ *"command": "\(.*\)",$/\1/p' "$here/hooks/hooks.json" | sed 's/\\"/"/g')"
is "hook: one command in shell form" "$hook" 'bash "${CLAUDE_PLUGIN_ROOT}/bin/second-brain" session-check'
is "hook: no args list, which would bypass the shell" "$(grep -c '"args"' "$here/hooks/hooks.json")" "0"
run env CLAUDE_PLUGIN_ROOT="$here" SECOND_BRAIN_VAULT="$tmp/nowhere" bash -c "$hook"
rc_is "hook: exits 0 with no vault" 0
out_is "hook: says that no vault is set up" "second-brain: no vault is set up - run /obsidian-dev-second-brain:vault-setup init"
run env CLAUDE_PLUGIN_ROOT="$here" bash -c "$hook"
rc_is "hook: exits 0 with a vault" 0
out_is "hook: says nothing with a vault" ""
run env -u SECOND_BRAIN_VAULT CLAUDE_PLUGIN_ROOT="$here" bash -c "$hook"
out_is "hook: says nothing when the pointer leads to a vault" ""
if [ "$WIN" -eq 1 ]; then
  run env CLAUDE_PLUGIN_ROOT="$(cygpath -w "$here")" SECOND_BRAIN_VAULT="$tmp/nowhere" bash -c "$hook"
  rc_is "hook: on Windows it runs from a plugin root written with backslashes" 0
  out_is "hook: on Windows it reports from there too" "second-brain: no vault is set up - run /obsidian-dev-second-brain:vault-setup init"
fi

# ---------------------------------------------------------------- sb_link_scan
SB_PLUGIN_ROOT="$here"
SB_ROOT=""
for lib in "$here"/scripts/lib/*.sh; do . "$lib"; done
sb link --check
is "sb_link_scan: the same rows as link --check" "$(sb_link_scan)" "$OUT"
is "sb_link_scan: four cells in every row" "$(sb_link_scan | awk -F' [|] ' 'NF != 4' | grep -c '' || true)" "0"

# ---------------------------------------------------------------- result
printf '\n%d passed, %d failed\n' "$n_pass" "$n_fail"
[ "$n_fail" -eq 0 ]
