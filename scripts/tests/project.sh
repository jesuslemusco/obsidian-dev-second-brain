#!/usr/bin/env bash
# Area project: project, profile, repo, and the path forms on Windows.
# Usage: bash scripts/test.sh project, or bash scripts/tests/project.sh
. "$(dirname "$0")/lib.sh"

# The two Example projects, as scaffold.sh makes them.
fixture_projects

# ---------------------------------------------------------------- project
sb project --name example
rc_is "project --name: exit 0" 0
out_is "project --name: case-insensitive, one row" "Example${TAB}$P${TAB}EX,EXOPS"
sb project --name Nope
rc_is "project --name: none gives exit 1" 1
sb project --key EXOPS-12
out_is "project --key: a ticket id gives its prefix" "Example${TAB}$P${TAB}EX,EXOPS"
sb project --key TWO
out_is "project --key: a bare prefix" "Example Two${TAB}$P2${TAB}EX,TWO"
sb project --key EX-5
rc_is "project --key: a shared key gives exit 4" 4
is "project --key: prints the candidates" "$(lines "$OUT")" "2"
sb project --key ZZ-1
rc_is "project --key: none gives exit 1" 1
sb project --cwd "$vault/$P/tasks"
out_is "project --cwd: a folder inside the project" "Example${TAB}$P${TAB}EX,EXOPS"
sb project --cwd "$tmp"
rc_is "project --cwd: outside everything gives exit 1" 1
edit "$vault/$P/claude/profile.md" 's/^repos: \[\]$/repos: [example-api, example-web]/'
mkdir -p "$tmp/code/example-api/src/deep" "$tmp/code/shared-lib"
sb project --cwd "$tmp/code/example-api/src/deep"
out_is "project --cwd: a repo folder named in the profile" "Example${TAB}$P${TAB}EX,EXOPS"
run sh -c "cd '$vault/$P2/docs' && '$SB' project"
out_is "project: no flag uses the working directory" "Example Two${TAB}$P2${TAB}EX,TWO"
edit "$vault/$P/claude/profile.md" 's/^repos: .*$/repos: [example-api, shared-lib]/'
edit "$vault/$P2/claude/profile.md" 's/^repos: \[\]$/repos:\
  - shared-lib/'
sb project --cwd "$tmp/code/shared-lib"
rc_is "project --cwd: a repo in two profiles gives exit 4" 4
sb project --bogus x
rc_is "project: unknown flag gives exit 5" 5
sb project --name
rc_is "project: flag with no value gives exit 5" 5
sb context --cwd "$tmp/code/example-api"
out_has "context: project from the working directory" "project: Example"
out_has "context: project path" "project_path: $P"
out_has "context: no sprint yet" "sprint: none"

# ---------------------------------------------------------------- profile
sb profile Example --keys
rc_is "profile --keys: exit 0" 0
out_has "profile --keys: scalar" "project: Example"
out_has "profile --keys: inline list" "ticket_keys: EX, EXOPS"
out_has "profile --keys: block list" "tags: type/profile"
out_has "profile --keys: roots" "tasks_root: tasks"
out_has "profile --keys: the task layout, flat by default" "task_layout: flat"
out_has "profile --keys: the days a done task waits for the archive" "archive_after_days: 14"
out_has "profile --keys: an empty value prints a dash" "persona: -"
out_has "profile --keys: an empty list prints a dash" "environments: -"
is "profile: persona sits right after tracker" "$(($(lineno "$vault/$P/claude/profile.md" 'persona:') - $(lineno "$vault/$P/claude/profile.md" 'tracker:')))" "1"
sb profile Example stories
out_has "profile: the stories section explains the persona" "the role a story's description opens with"
sb profile Example stories
rc_is "profile section: exit 0" 0
out_has "profile section: its body" "Persona"
out_lacks "profile section: stops at the next heading" "Spelling exceptions"
sb profile Example live systems
rc_is "profile section: two words, any case" 0
sb profile Example Docs
out_has "profile section: Docs keeps its level-3 headings" "### Debt file"
is "profile: nine headings under Docs" "$(printf '%s\n' "$OUT" | grep -c '^### ')" "9"
is "profile: seven fixed sections" "$(grep -c '^## ' "$vault/$P/claude/profile.md")" "7"
sb profile Example nosuch
rc_is "profile section: absent gives exit 1" 1
sb profile Nope --keys
rc_is "profile: unknown project gives exit 1" 1
sb profile Example
rc_is "profile: no section gives exit 5" 5
mkdir -p "$vault/misc/three/tasks"
printf '| Three | misc/three | T | A project with no profile. |\n' >>"$vault/CLAUDE.md"
sb profile Three --keys
rc_is "profile: missing profile gives exit 1" 1
err_has "profile: missing profile hints at adopt" "vault-setup adopt"

# ---------------------------------------------------------------- repo
RP="work/repo-one"
RPF="$vault/$RP/claude/profile.md"
sb scaffold project "Repo One" --path "$RP" --keys RA
is "profile: repos_root sits right after repos" "$(($(lineno "$RPF" 'repos_root:') - $(lineno "$RPF" 'repos:')))" "1"
is "profile: repo_paths sits right after repos_root" "$(($(lineno "$RPF" 'repo_paths:') - $(lineno "$RPF" 'repos_root:')))" "1"
line_is "profile: repos_root starts empty" "$RPF" 'repos_root: ""'
line_is "profile: repo_paths starts empty" "$RPF" "repo_paths: []"
sb profile "Repo One" repos
out_has "profile: the repos section explains the two keys" "repo_paths:"
out_has "profile: the repos section names the default repository" "first name is the default repository for branch checks"
sb repo "Repo One"
rc_is "repo: a project with no repos exits 0" 0
out_is "repo: and prints nothing" ""
edit "$RPF" 's/^repos: \[\]$/repos: [alpha-api, alpha-web]/'
sb repo "Repo One"
out_is "repo: no location recorded gives unknown and a dash" "alpha-api${TAB}-${TAB}unknown
alpha-web${TAB}-${TAB}unknown"
sb repo "Repo One" alpha-api
rc_is "repo name: no location recorded gives exit 1" 1
out_is "repo name: nothing on stdout" ""
err_has "repo name: the message says no location is recorded" "no location is recorded for alpha-api"
mkdir -p "$tmp/userdir/code/acme/alpha-api/src"
edit "$RPF" 's|^repos_root: ""$|repos_root: "~/code/acme"|'
sb repo "Repo One"
out_is "repo: rows from repos_root, tilde expanded, in the order of repos" "alpha-api${TAB}$oT/userdir/code/acme/alpha-api${TAB}ok
alpha-web${TAB}$oT/userdir/code/acme/alpha-web${TAB}missing"
run env HOME="$tmp/another" "$SB" repo "Repo One"
out_is "repo: the tilde follows the home directory" "alpha-api${TAB}$oT/another/code/acme/alpha-api${TAB}missing
alpha-web${TAB}$oT/another/code/acme/alpha-web${TAB}missing"
sb repo "Repo One" alpha-api
rc_is "repo name: exit 0 when the folder exists" 0
out_is "repo name: prints the path alone" "$oT/userdir/code/acme/alpha-api"
sb repo "Repo One" alpha-web
rc_is "repo name: a missing folder gives exit 1" 1
out_is "repo name: nothing on stdout for a missing folder" ""
err_has "repo name: the message says the folder is missing" "the folder of alpha-web is missing"
sb repo "Repo One" alpha-nope
rc_is "repo name: a name not in repos gives exit 1" 1
err_has "repo name: the message says it is not in repos" "alpha-nope is not in repos"
mkdir -p "$tmp/else where/alpha-tools" "$tmp/real-elsewhere/alpha-web/lib"
symlink "$tmp/real-elsewhere" "$tmp/userdir/elsewhere"
edit "$RPF" 's/^repos: .*$/repos: [alpha-api, alpha-web, alpha-tools]/'
edit "$RPF" "s|^repo_paths: \\[\\]\$|repo_paths:\\
  - \"alpha-tools=$tmp/else where/alpha-tools\"\\
  - alpha-web=~/elsewhere/alpha-web|"
sb repo "Repo One"
out_is "repo: repo_paths wins over repos_root for the names it lists" "alpha-api${TAB}$oT/userdir/code/acme/alpha-api${TAB}ok
alpha-web${TAB}$oT/userdir/elsewhere/alpha-web${TAB}ok
alpha-tools${TAB}$oT/else where/alpha-tools${TAB}ok"
sb repo "Repo One" alpha-tools
out_is "repo name: a path with spaces" "$oT/else where/alpha-tools"
# Inside the helper a path is in the shell's own form; the repo command prints it as shown.
is "sb_repo_rows: the same rows for other libraries" "$(SB_ROOT=""; sb_repo_rows "Repo One" | while IFS="$TAB" read -r n p s; do
  printf '%s\t%s\t%s\n' "$n" "$oT${p#"$tmp"}" "$s"
done)" "$("$SB" repo "Repo One")"
sb_repo_rows "No Such Project" >/dev/null 2>&1
is "sb_repo_rows: returns 1 for an unknown project" "$?" "1"
SB_ROOT=""
sb repo
rc_is "repo: no project gives exit 5" 5
sb repo "Repo One" alpha-api extra
rc_is "repo: too many arguments give exit 5" 5
sb repo Nope
rc_is "repo: unknown project gives exit 1" 1
sb repo Three
rc_is "repo: no profile gives exit 1" 1
err_has "repo: no profile hints at adopt" "vault-setup adopt"
sb scaffold project "Repo Two" --path work/repo-two --keys RB
mkdir -p "$tmp/other root/alpha-api/pkg" "$tmp/third/alpha-api"
edit "$vault/work/repo-two/claude/profile.md" 's/^repos: \[\]$/repos: [alpha-api]/'
edit "$vault/work/repo-two/claude/profile.md" "s|^repos_root: \"\"\$|repos_root: \"$tmp/other root\"|"
sb repo "Repo Two" alpha-api
out_is "repo: an absolute repos_root with a space" "$oT/other root/alpha-api"
sb project --cwd "$tmp/userdir/code/acme/alpha-api/src"
out_is "project --cwd: inside a recorded repository folder" "Repo One${TAB}$RP${TAB}RA"
sb project --cwd "$tmp/other root/alpha-api/pkg"
out_is "project --cwd: the same folder name under another root is the other project" "Repo Two${TAB}work/repo-two${TAB}RB"
sb project --cwd "$tmp/real-elsewhere/alpha-web/lib"
out_is "project --cwd: a recorded path through a symlink still matches" "Repo One${TAB}$RP${TAB}RA"
symlink "$tmp/other root/alpha-api" "$tmp/link-to-two"
sb project --cwd "$tmp/link-to-two/pkg"
out_is "project --cwd: a working directory reached through a symlink" "Repo Two${TAB}work/repo-two${TAB}RB"
sb project --cwd "$tmp/third/alpha-api"
rc_is "project --cwd: outside every recorded folder the name match is the fallback, exit 4 for two" 4
is "project --cwd: the fallback prints both candidates" "$(lines "$OUT")" "2"
sb project --cwd "$tmp/code/example-api/src/deep"
out_has "project --cwd: a project with no recorded location still matches by folder name" "Example${TAB}$P${TAB}"
sb context --cwd "$tmp/other root/alpha-api"
is "context: still four lines" "$(lines "$OUT")" "4"
out_has "context: project from a recorded repository folder" "project: Repo Two"

# The path forms read EX-1 and name EX-2, as tasks.sh makes them.
mkdir -p "$vault/$P/docs/billing/Invoices" "$vault/$P/docs/api"
sb task new EX-1 --project Example --title 'Fix: totals "rounded" twice' --topics billing/invoices
sb task new EX-2 --project Example --title Second --topics "docs/API, billing-old"

# ---------------------------------------------------------------- path forms on Windows
# There an absolute path that is read may be written C:\a, C:/a or /c/a; one that is printed is C:/a.
if sb_is_windows; then
  wV="$(cygpath -w "$vault")"
  run env SECOND_BRAIN_VAULT="$wV" "$SB" root
  rc_is "path forms: a vault written with backslashes, exit 0" 0
  out_is "path forms: the vault is printed in the drive form" "$oV"
  run env SECOND_BRAIN_VAULT="$oV" "$SB" root
  out_is "path forms: a vault in the drive form" "$oV"
  run env SECOND_BRAIN_VAULT="/$(printf '%s' "${vault:1:1}" | tr '[:lower:]' '[:upper:]')${vault:2}" "$SB" root
  out_is "path forms: a vault with an upper-case drive letter" "$oV"
  run env SECOND_BRAIN_VAULT="$wV" "$SB" task head EX-1
  rc_is "path forms: a task is read in a vault written with backslashes" 0
  run env SECOND_BRAIN_VAULT="$wV" "$SB" context --cwd "$(cygpath -w "$tmp/other root/alpha-api")"
  out_has "path forms: context prints the vault in the drive form" "vault: $oV"
  out_has "path forms: context takes --cwd written with backslashes" "project: Repo Two"
  sb project --cwd "$(cygpath -w "$tmp/userdir/code/acme/alpha-api/src")"
  out_is "path forms: project --cwd written with backslashes" "Repo One${TAB}$RP${TAB}RA"
  sb project --cwd "$oT/userdir/code/acme/alpha-api/src"
  out_is "path forms: project --cwd in the drive form" "Repo One${TAB}$RP${TAB}RA"
  sb project --cwd "$(cygpath -w "$vault/$P/tasks")"
  out_has "path forms: project --cwd inside the vault, written with backslashes" "Example${TAB}$P${TAB}"
  W2="$vault/work/repo-two/claude/profile.md"
  cp "$W2" "$tmp/w2.before"
  SB_ROOT="$vault"
  sb_fm_set "$W2" repos_root "$oT/other root"
  sb repo "Repo Two"
  out_is "path forms: repos_root in the drive form" "alpha-api${TAB}$oT/other root/alpha-api${TAB}ok"
  sb_fm_set "$W2" repos_root "$(cygpath -w "$tmp/other root")"
  file_has "path forms: the profile holds repos_root with backslashes" "$W2" "repos_root: $(cygpath -w "$tmp/other root")"
  sb repo "Repo Two"
  out_is "path forms: repos_root written with backslashes" "alpha-api${TAB}$oT/other root/alpha-api${TAB}ok"
  sb project --cwd "$tmp/other root/alpha-api/pkg"
  out_is "path forms: a working directory under that repos_root" "Repo Two${TAB}work/repo-two${TAB}RB"
  sb_fm_set "$W2" repos_root ""
  sb_fm_edit "$W2" listadd repo_paths "alpha-api=$(cygpath -w "$tmp/third/alpha-api")"
  sb repo "Repo Two" alpha-api
  out_is "path forms: a repo_paths entry written with backslashes" "$oT/third/alpha-api"
  cat "$tmp/w2.before" >"$W2"
  SB_ROOT=""
  mkdir -p "$tmp/vault6/.obsidian"
  sb scaffold vault "$(cygpath -w "$tmp/vault6")"
  rc_is "path forms: scaffold vault takes a folder written with backslashes" 0
  exists "path forms: scaffold vault writes the index there" "$tmp/vault6/CLAUDE.md"
  sb scaffold vault "$(cygpath -w "$tmp/userdir")"
  rc_is "path forms: scaffold vault refuses a folder that is no vault, exit 2" 2
  err_has "path forms: the refusal names the folder in the drive form" "$oT/userdir"
  sb search Example "billing" --in 'docs\billing'
  rc_is "path forms: search --in refuses a backslash, exit 5" 5
  sb task head 'EX-1\..\EX-2'
  rc_is "path forms: a task id with a backslash names no task folder, exit 1" 1
fi

# ---------------------------------------------------------------- result
result
