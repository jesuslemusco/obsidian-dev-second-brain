#!/usr/bin/env bash
# End-to-end check with Claude Code itself: the plugin loads, its hook runs, the helper is on the
# Bash PATH, and a vault's own skills and agents are found through the links.
# It writes into the real link directory and spends a little API usage, so it runs in CI only.
# Usage, on a CI runner: ANTHROPIC_API_KEY=... bash scripts/e2e-claude.sh
set -u

here="$(cd "$(dirname "$0")/.." && pwd -P)"
SB="$here/bin/second-brain"

[ -n "${CI:-}" ] || { echo "e2e: this writes into the link directory, run it in CI only" >&2; exit 2; }
command -v claude >/dev/null 2>&1 || { echo "e2e: the claude command was not found" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "e2e: jq was not found" >&2; exit 2; }
if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  echo "e2e: no credential: set ANTHROPIC_API_KEY or CLAUDE_CODE_OAUTH_TOKEN" >&2
  exit 2
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-e2e.XXXXXX")" || exit 2
tmp="$(cd "$tmp" && pwd -P)"
vault="$tmp/e2e vault"
work="$tmp/work"
P="projects/example"
token="E2E$$x$(date +%s)"
mkdir -p "$vault/.obsidian" "$work" "$HOME/.claude"

# The plugin folder in the form a Windows program takes, when the shell is Git Bash.
plugin="$here"
if command -v cygpath >/dev/null 2>&1; then plugin="$(cygpath -m "$here")"; fi

n_pass=0
n_fail=0
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
# holds <desc> <text> <part>: the text holds the part.
holds() {
  case "$2" in *"$3"*) pass "$1" ;; *) fail "$1" "wanted: $3" "in: $2" ;; esac
}
# step <desc> <command...>: the command exits 0.
step() {
  local desc="$1" out
  shift
  if out="$("$@" 2>&1)"; then pass "$desc"; else fail "$desc" "exit $?" "output: $out"; fi
}
# ask <out file> <prompt> [tool...]: one headless Claude Code session in the work folder, as a JSON
# stream. It may run the helper and skills, and the tools named.
ask() {
  local out="$1" prompt="$2"
  shift 2
  (cd "$work" && claude -p "$prompt" --plugin-dir "$plugin" --model haiku --max-budget-usd 0.50 \
    --output-format stream-json --verbose --include-hook-events --no-session-persistence \
    --allowedTools "Bash(second-brain *)" Skill "$@" >"$out" 2>"$out.err")
  printf 'claude exit %s, %s lines\n' "$?" "$(wc -l <"$out" | tr -d ' ')"
}
# field <out file> <jq filter>: print what the filter selects.
field() {
  jq -r "$2" "$1" 2>/dev/null
}
hook_out='select(.type == "system" and .subtype == "hook_response" and .hook_event == "SessionStart") | "exit=\(.exit_code) \(.stdout)\(.stderr)"'
init_of='select(.type == "system" and .subtype == "init")'
tool_out='select(.type == "user") | .message.content[]? | select(.type == "tool_result") | .content | if type == "string" then . else (map(.text? // "") | join("\n")) end'

printf '== before setup: the hook reports the missing vault ==\n'
ask "$tmp/first.jsonl" "Reply with the single word OK."
holds "plugin: loaded from the folder" "$(field "$tmp/first.jsonl" "$init_of | .plugins[].name")" "obsidian-dev-second-brain"
got="$(field "$tmp/first.jsonl" "$hook_out")"
holds "hook: the SessionStart hook ran the helper" "$got" "no vault is set up"
holds "hook: it exits 0" "$got" "exit=0"

printf '== setup: pointer, scaffold, links ==\n'
step "pointer set: creates the pointer" bash "$SB" pointer set "$vault"
# Everything below writes into the vault the pointer leads to: stop unless it is the scratch one.
if [ ! "$(bash "$SB" root 2>/dev/null)" -ef "$vault" ]; then
  echo "e2e: the pointer does not lead to the scratch vault; nothing more was written" >&2
  exit 2
fi
pass "root: the vault is found through the pointer"
step "scaffold vault" bash "$SB" scaffold vault
step "scaffold project" bash "$SB" scaffold project Example --path "$P" --keys EX --no-sprints
for dir in "$vault/claude" "$vault/$P/claude"; do
  kind="vault"
  [ "$dir" = "$vault/claude" ] || kind="project"
  mkdir -p "$dir/skills/e2e-$kind-skill" "$dir/agents"
  printf -- '---\nname: e2e-%s-skill\ndescription: A scratch skill for the end-to-end check.\n---\n\nReply with the word %s.\n' \
    "$kind" "$token" >"$dir/skills/e2e-$kind-skill/SKILL.md"
  printf -- '---\nname: e2e-%s-agent\ndescription: A scratch agent for the end-to-end check.\n---\n\nReply with the word %s.\n' \
    "$kind" "$token" >"$dir/agents/e2e-$kind-agent.md"
done
step "link --apply: registers the skills and agents" bash "$SB" link --apply
step "link --check: every row is linked" bash "$SB" link --check
printf '\nThe end-to-end token is %s.\n' "$token" >>"$vault/CLAUDE.md"
printf '@~/.claude/second-brain-vault/CLAUDE.md\n' >>"$HOME/.claude/CLAUDE.md"
bash "$SB" link --check
bash "$SB" doctor

printf '== after setup: Claude Code sees the vault ==\n'
ask "$tmp/second.jsonl" "Run this bash command and no other: second-brain context
Then answer in one line with the end-to-end token from your instructions."
got="$(field "$tmp/second.jsonl" "$hook_out")"
holds "hook: exits 0 once the vault is set up" "$got" "exit=0"
case "$got" in *"no vault is set up"*) fail "hook: no complaint once the vault is set up" "got: $got" ;; *) pass "hook: no complaint once the vault is set up" ;; esac
case "$got" in *"project:"*) fail "hook: no session block outside a project" "got: $got" ;; *) pass "hook: no session block outside a project" ;; esac
skills="$(field "$tmp/second.jsonl" "$init_of | .skills[]")"
agents="$(field "$tmp/second.jsonl" "$init_of | .agents[]")"
holds "skills: the vault's own skill is found through its link" "$skills" "e2e-vault-skill"
holds "skills: a project's skill is found through its link" "$skills" "e2e-project-skill"
holds "skills: the plugin's skills are loaded" "$skills" "story-tracker"
holds "agents: the vault's own agent is found through its link" "$agents" "e2e-vault-agent"
holds "agents: a project's agent is found through its link" "$agents" "e2e-project-agent"
holds "agents: the plugin's agents are loaded" "$agents" "scrum-master"
holds "bin: second-brain runs from the Bash tool" "$(field "$tmp/second.jsonl" "$tool_out")" "vault: "
holds "import: the index is read through the pointer" "$(field "$tmp/second.jsonl" 'select(.type == "result") | .result')" "$token"

printf '== ticket text: a request to write a ticket loads story-tracker ==\n'
# With no persona, section 1 of create.md asks for one, and a headless run cannot answer.
sed 's/^persona: ""$/persona: "developer"/' "$vault/$P/claude/profile.md" >"$tmp/profile.md" &&
  mv "$tmp/profile.md" "$vault/$P/claude/profile.md"
holds "trigger: the profile has a persona" "$(bash "$SB" profile Example --keys)" "developer"
ask "$tmp/third.jsonl" "For the Example project: give me summary, description and AC for a new ticket, no id.
The ticket: the task board should show each task's branch."
holds "trigger: the request loads story-tracker" \
  "$(field "$tmp/third.jsonl" 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use" and .name == "Skill") | .input.skill')" "story-tracker"
got="$(field "$tmp/third.jsonl" 'select(.type == "result") | .result')"
case "${got#"${got%%[![:space:]]*}"}" in
  '*As a*'*) pass "trigger: the ticket text starts with *As a*" ;;
  *) fail "trigger: the ticket text starts with *As a*" "got: $got" ;;
esac
printf '== search rule: a fresh session recalls a story with the helper ==\n'
step "task new: a tracked story" bash "$SB" task new EX-1 --project Example --title "Show each task's branch on the board"
step "task set: its next action" bash "$SB" task set EX-1 status=in-progress "next=Add a branch column to the board view"
# Read, Grep, cat, sed and grep are allowed too, so a whole-file read could come first.
ask "$tmp/fourth.jsonl" "Where does story EX-1 stand, and what is its next action? Answer in one line." \
  Read Grep "Bash(cat *)" "Bash(sed *)" "Bash(grep *)"
uses='select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | if .name == "Bash" then "bash " + (.input.command | gsub("\n"; " ")) elif .name == "Read" then "read " + .input.file_path + (if (.input.offset // .input.limit) then " ranged" else "" end) else .name end'
first="$(field "$tmp/fourth.jsonl" "$uses" | awk '
  /^bash .*second-brain +(task +head|outline|search)/ { print "helper: " $0; exit }
  /^read / && !/ ranged$/ { print "whole: " $0; exit }
  /^Grep$/ || /^bash .*[^a-z](cat|sed|grep|head|tail)[ \t]/ { print "whole: " $0; exit }')"
case "$first" in
  helper:*) pass "search rule: task head, outline or search comes before any whole-file read" ;;
  *) fail "search rule: task head, outline or search comes before any whole-file read" "first: ${first:-none}" ;;
esac
holds "search rule: the answer gives the story's next action" "$(field "$tmp/fourth.jsonl" 'select(.type == "result") | .result')" "branch column"
got="$(field "$tmp/fourth.jsonl" 'select(.type == "system" and .subtype == "hook_response" and .hook_event == "PreToolUse") | "exit=\(.exit_code)"' | sort -u | tr '\n' ' ')"
holds "search rule: the PreToolUse hook ran" "$got" "exit=0"
case "$got" in *"exit="[!0]*) fail "search rule: the PreToolUse hook always exits 0" "got: $got" ;; *) pass "search rule: the PreToolUse hook always exits 0" ;; esac
printf '== session context: the SessionStart hook names the project, the ticket and its story ==\n'
repo="$tmp/code/example-api"
mkdir -p "$repo"
step "git init: a repo of the project" git init -q "$repo"
step "git: on a ticket branch" git -C "$repo" symbolic-ref HEAD refs/heads/feature/EX-1-branch-column
code="$tmp/code"
if command -v cygpath >/dev/null 2>&1; then code="$(cygpath -m "$code")"; fi
sed -e 's/^repos: \[\]$/repos: [example-api]/' -e "s|^repos_root: \"\"$|repos_root: \"$code\"|" \
  "$vault/$P/claude/profile.md" >"$tmp/profile.md" && mv "$tmp/profile.md" "$vault/$P/claude/profile.md"
holds "repo: the profile records the repo" "$(bash "$SB" repo Example)" "example-api"
was="$work"
work="$repo"
ask "$tmp/fifth.jsonl" "Which ticket id does the branch of this session name? Reply with the id only."
work="$was"
got="$(field "$tmp/fifth.jsonl" "$hook_out")"
holds "session context: the hook exits 0" "$got" "exit=0"
holds "session context: it names the project" "$got" "project: Example"
holds "session context: it names the branch" "$got" "branch: feature/EX-1-branch-column"
holds "session context: it names the ticket" "$got" "ticket: EX-1"
holds "session context: it names the story and its status" "$got" "story: projects/example/tasks/EX-1/README.md - in-progress"
holds "session context: it ends with the search and read rule" "$got" "never grep, cat or sed on vault files."
holds "session context: Claude knows the ticket from the first message" "$(field "$tmp/fifth.jsonl" 'select(.type == "result") | .result')" "EX-1"
if [ "$n_fail" -gt 0 ]; then
  printf '\n== what Claude Code printed ==\n'
  for f in "$tmp/first.jsonl" "$tmp/second.jsonl" "$tmp/third.jsonl" "$tmp/fourth.jsonl" "$tmp/fifth.jsonl"; do
    printf -- '-- %s --\n' "${f##*/}"
    cat "$f.err" 2>/dev/null
    field "$f" "$init_of | {skills, agents, plugins}"
    field "$f" 'select(.type == "system" and (.subtype | startswith("hook_"))) | {subtype, hook_event, exit_code, outcome, stdout, stderr}'
    field "$f" 'select(.type == "result")'
  done
fi

printf '\n%s passed, %s failed\n' "$n_pass" "$n_fail"
[ "$n_fail" -eq 0 ]
