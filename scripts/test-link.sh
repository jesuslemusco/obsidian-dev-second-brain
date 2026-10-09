#!/usr/bin/env bash
# Scratch-vault tests for the link command: a vault and a link directory in a temp dir.
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
# points_at <desc> <link> <target>: the entry is a symlink holding exactly that target.
points_at() {
  if [ -L "$2" ]; then is "$1" "$(readlink "$2")" "$3"; else fail "$1" "not a symlink: $2"; fi
}
absent() {
  if [ -e "$2" ] || [ -L "$2" ]; then fail "$1" "should not exist: $2"; else pass "$1"; fi
}
exists_dir() {
  if [ -d "$2" ] && [ ! -L "$2" ]; then pass "$1"; else fail "$1" "not a real folder: $2"; fi
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

MISSING="my-skill | skill | missing | $VS
my-agent | agent | missing | $VA
ex-skill | skill | missing | $PS
ex-agent | agent | missing | $PA"

# ---------------------------------------------------------------- check, nothing linked
sb link
rc_is "check: exit 1 while items are missing" 1
out_is "check: the four items are missing, README.md is ignored" "$MISSING"
sb link --check
rc_is "check: --check exits 1 too" 1
out_is "check: --check prints the same rows" "$MISSING"
absent "check: creates no link directory" "$home"

# ---------------------------------------------------------------- apply
LINKED="my-skill | skill | linked | $VS
my-agent | agent | linked | $VA
ex-skill | skill | linked | $PS
ex-agent | agent | linked | $PA"
sb link --apply
rc_is "apply: exit 0" 0
out_is "apply: prints the rows as they now are" "$LINKED"
points_at "apply: vault skill link" "$home/skills/my-skill" "$VS"
points_at "apply: vault agent link" "$home/agents/my-agent.md" "$VA"
points_at "apply: project skill link" "$home/skills/ex-skill" "$PS"
points_at "apply: project agent link" "$home/agents/ex-agent.md" "$PA"
is "apply: the skill link resolves to its SKILL.md" "$(sed -n 2p "$home/skills/my-skill/SKILL.md")" "name: my-skill"
is "apply: the agent link resolves to the file" "$(sed -n 2p "$home/agents/ex-agent.md")" "name: ex-agent"
absent "apply: README.md in an agents folder is not linked" "$home/agents/README.md"
absent "apply: a folder with no SKILL.md is not linked" "$home/skills/no-skill-file"
is "apply: says what it linked" "$(printf '%s\n' "$ERR" | grep -c '^note: linked: ')" "4"
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
outside="$tmp/outside"
mkdir -p "$outside/other-skill" "$home/skills/real-skill"
printf 'mine\n' >"$home/skills/real-skill/SKILL.md"
printf 'mine\n' >"$home/agents/real-agent.md"
printf 'theirs\n' >"$outside/other-agent.md"
ln -s "$outside/other-skill" "$home/skills/other-skill"
ln -s "$outside/other-agent.md" "$home/agents/other-agent.md"
sb link --check
rc_is "foreign: exit 0, foreign entries do not count" 0
row_is "foreign: a symlink pointing outside the vault" "other-skill | skill | foreign | $outside/other-skill"
row_is "foreign: an agent symlink pointing outside" "other-agent | agent | foreign | $outside/other-agent.md"
row_is "foreign: a real folder" "real-skill | skill | foreign | -"
row_is "foreign: a real file" "real-agent | agent | foreign | -"
row_is "foreign: the vault items stay linked" "my-skill | skill | linked | $VS"
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
rm "$home/skills/my-skill" "$home/agents/my-agent.md"
ln -s "$vault/notes/elsewhere" "$home/skills/my-skill"
ln -s "../../my vault/$P/claude/agents/ex-agent.md" "$home/agents/my-agent.md"
sb link --check
rc_is "wrong target: exit 1" 1
row_is "wrong target: a link to another vault folder" "my-skill | skill | wrong-target | $vault/notes/elsewhere"
row_is "wrong target: a relative link is resolved" "my-agent | agent | wrong-target | $PA"
points_at "wrong target: check changes nothing" "$home/skills/my-skill" "$vault/notes/elsewhere"
sb link --apply
rc_is "wrong target: apply exits 0" 0
out_lacks "wrong target: none left after apply" "wrong-target"
points_at "wrong target: the skill link is repointed" "$home/skills/my-skill" "$VS"
points_at "wrong target: the agent link is repointed" "$home/agents/my-agent.md" "$VA"
is "wrong target: apply says what it repointed" "$(printf '%s\n' "$ERR" | grep -c '^note: repointed: ')" "2"
exists_dir "wrong target: the old target folder is kept" "$vault/notes/elsewhere"

rm "$home/skills/ex-skill"
ln -s "$outside/other-skill" "$home/skills/ex-skill"
sb link --apply
rc_is "wrong target outside the vault: apply exits 1" 1
row_is "wrong target outside the vault: reported" "ex-skill | skill | wrong-target | $outside/other-skill"
points_at "wrong target outside the vault: left alone" "$home/skills/ex-skill" "$outside/other-skill"
rm "$home/skills/ex-skill"
ln -s "$vault/notes/elsewhere" "$outside/hop"
ln -s "$outside/hop" "$home/skills/ex-skill"
sb link --apply
rc_is "wrong target through an outside link: apply exits 1" 1
row_is "wrong target through an outside link: the first hop decides" "ex-skill | skill | wrong-target | $outside/hop"
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

# ---------------------------------------------------------------- dangling
ln -s "$vault/claude/skills/gone-skill" "$home/skills/gone-skill"
ln -s "$vault/$P/claude/agents/gone-agent.md" "$home/agents/gone-agent.md"
ln -s "$outside/gone-skill" "$home/skills/lost-skill"
rm "$home/agents/ex-agent.md"
ln -s "$vault/$P/claude/agents/old-name.md" "$home/agents/ex-agent.md"
sb link --check
rc_is "dangling: exit 1" 1
row_is "dangling: a dead link into the vault" "gone-skill | skill | dangling | $vault/claude/skills/gone-skill"
row_is "dangling: a dead agent link into the vault" "gone-agent | agent | dangling | $vault/$P/claude/agents/gone-agent.md"
row_is "dangling: a dead link pointing outside" "lost-skill | skill | dangling | $outside/gone-skill"
row_is "dangling: a dead link at a vault name" "ex-agent | agent | dangling | $vault/$P/claude/agents/old-name.md"
points_at "dangling: check changes nothing" "$home/skills/gone-skill" "$vault/claude/skills/gone-skill"
sb link --apply
rc_is "dangling: apply exits 1 while the outside one is left" 1
absent "dangling: the dead link into the vault is removed" "$home/skills/gone-skill"
absent "dangling: the dead agent link into the vault is removed" "$home/agents/gone-agent.md"
points_at "dangling: the dead link pointing outside is left" "$home/skills/lost-skill" "$outside/gone-skill"
points_at "dangling: the dead link at a vault name is repointed" "$home/agents/ex-agent.md" "$PA"
out_lacks "dangling: the removed skill row is gone" "gone-skill | skill"
out_lacks "dangling: the removed agent row is gone" "gone-agent | agent"
row_is "dangling: the outside one is still reported" "lost-skill | skill | dangling | $outside/gone-skill"
is "dangling: apply says what it removed" "$(printf '%s\n' "$ERR" | grep -c '^note: removed: ')" "2"
rm "$home/skills/lost-skill"
sb link --check
rc_is "dangling: exit 0 once the outside one is removed by hand" 0

# ---------------------------------------------------------------- name mismatch
skill "$vault/claude" odd-folder other-name
agent "$vault/$P/claude" odd-agent other-agent-name
mkdir -p "$vault/claude/skills/no-name"
printf -- '---\ndescription: No name key.\n---\n' >"$vault/claude/skills/no-name/SKILL.md"
sb link --check
rc_is "name mismatch: exit 1" 1
row_is "name mismatch: a skill folder named unlike its frontmatter" "odd-folder | skill | name-mismatch | $vault/claude/skills/odd-folder"
row_is "name mismatch: an agent file named unlike its frontmatter" "odd-agent | agent | name-mismatch | $vault/$P/claude/agents/odd-agent.md"
row_is "name mismatch: a skill with no name key" "no-name | skill | name-mismatch | $vault/claude/skills/no-name"
sb link --apply
rc_is "name mismatch: apply exits 1" 1
row_is "name mismatch: still reported after apply" "odd-folder | skill | name-mismatch | $vault/claude/skills/odd-folder"
absent "name mismatch: not linked by its folder name" "$home/skills/odd-folder"
absent "name mismatch: not linked by its frontmatter name" "$home/skills/other-name"
absent "name mismatch: the agent is not linked" "$home/agents/odd-agent.md"
absent "name mismatch: the nameless skill is not linked" "$home/skills/no-name"
row_is "name mismatch: the good items stay linked" "my-skill | skill | linked | $VS"
rm -r "$vault/claude/skills/odd-folder" "$vault/claude/skills/no-name" "$vault/$P/claude/agents/odd-agent.md"

# ---------------------------------------------------------------- duplicate
skill "$vault/claude" twin twin
skill "$vault/$P/claude" twin twin
agent "$vault/claude" ex-agent ex-agent
sb link --check
rc_is "duplicate: exit 1" 1
row_is "duplicate: the vault copy" "twin | skill | duplicate | $vault/claude/skills/twin"
row_is "duplicate: the project copy" "twin | skill | duplicate | $vault/$P/claude/skills/twin"
row_is "duplicate: an agent that was linked before" "ex-agent | agent | duplicate | $PA"
sb link --apply
rc_is "duplicate: apply exits 1" 1
absent "duplicate: the skill is not linked" "$home/skills/twin"
points_at "duplicate: the earlier agent link is left as it was" "$home/agents/ex-agent.md" "$PA"
row_is "duplicate: still reported after apply" "twin | skill | duplicate | $vault/claude/skills/twin"
rm -r "$vault/$P/claude/skills/twin" "$vault/claude/agents/ex-agent.md"
sb link --apply
rc_is "duplicate: apply exits 0 once one copy is gone" 0
points_at "duplicate: the remaining copy is linked" "$home/skills/twin" "$vault/claude/skills/twin"

# ---------------------------------------------------------------- edges
ln -s "$VS" "$home/skills/alias-skill"
sb link --apply
rc_is "extra link into the vault: exit 0" 0
row_is "extra link into the vault: foreign, the scan owns no such name" "alias-skill | skill | foreign | $VS"
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
row_is "space in the vault path: rows carry the whole path" "my-skill | skill | linked | $VS"
is "space in the vault path: the link opens" "$(sed -n 2p "$home/skills/twin/SKILL.md")" "name: twin"
out_lacks "plugin skills: none is ever listed" "$here/"

mkdir -p "$tmp/userdir/.claude/skills/home-skill"
run env -u SECOND_BRAIN_CLAUDE_HOME "$SB" link --check
rc_is "default link directory: exit 1, nothing is linked there" 1
row_is "default link directory: the .claude folder in the home" "home-skill | skill | foreign | -"
row_is "default link directory: the vault items are missing there" "my-skill | skill | missing | $VS"

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
