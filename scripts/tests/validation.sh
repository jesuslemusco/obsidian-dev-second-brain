#!/usr/bin/env bash
# Area validation: validation and validation new, each repo's home, and their --json forms.
# Usage: bash scripts/test.sh validation, or bash scripts/tests/validation.sh
. "$(dirname "$0")/lib.sh"

sb scaffold vault

# ---------------------------------------------------------------- the vault note
sb help
out_has "help: lists validation" "validation <project> [repo] [--path DIR] | validation new <project> <repo>"
S="work/checks"
CKF="$vault/$S/claude/profile.md"
mkdir -p "$tmp/ccode/check-app" "$tmp/ccode/check-infra"
sb scaffold project Checks --path "$S" --keys CK
out_has "validation: scaffold project writes claude/validation.md" "$S/claude/validation.md"
line_is "validation: the note is typed" "$vault/$S/claude/validation.md" "type: validation"
line_is "validation: the note links up to the Claude hub" "$vault/$S/claude/validation.md" "> Up: [[$S/claude/README|Checks Claude Hub]]"
file_has "validation: the note holds one section per repo" "$vault/$S/claude/validation.md" 'code, in one `## <repo>` section per repo.'
line_is "validation: the note names the command agents read it with" "$vault/$S/claude/validation.md" 'section with `second-brain validation "Checks" <repo>` before they build or review a change.'
line_is "validation: the note names validation new" "$vault/$S/claude/validation.md" '`second-brain validation new "Checks" <repo>` adds a missing section.'
file_has "validation: the Claude hub links to it" "$vault/$S/claude/README.md" "[[$S/claude/validation|Checks Validation]]"
line_is "profile template: validation_home: vault" "$CKF" "validation_home: vault"
sb validation Checks
rc_is "validation: a project with no repo exits 0" 0
out_is "validation: and prints no row" ""
edit "$CKF" "s|^repos: \\[\\]\$|repos: [check-app]|; s|^repos_root: \"\"\$|repos_root: \"$tmp/ccode\"|"
sb scaffold subproject Checks infra --repos check-infra
CKS="$vault/$S/claude/subprojects/infra.md"
sb subproject Checks infra
out_has "subproject: shows the validation home, the profile's" "validation_home: vault"

# ---------------------------------------------------------------- validation.md
sb validation Checks
out_is "validation: one row per repo, the vault home, no section yet" "check-app${TAB}vault${TAB}$S/claude/validation.md${TAB}no-section
check-infra${TAB}vault${TAB}$S/claude/validation.md${TAB}no-section"
sb validation Checks check-app
rc_is "validation: a repo with no section exits 1" 1
err_has "validation: and names validation new" "has no ## check-app section: run second-brain validation new"
sb validation new Checks check-app
rc_is "validation new: exit 0" 0
out_is "validation new: names the file" "$S/claude/validation.md"
line_is "validation new: adds the repo's section" "$vault/$S/claude/validation.md" "## check-app"
line_is "validation new: with the check as a user would" "$vault/$S/claude/validation.md" "### Check as a user would"
is "validation new: the section holds the template's four parts, word for word" "$(section_of "$vault/$S/claude/validation.md" check-app)" \
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
sb validation new Checks CHECK-APP
rc_is "validation new again: exit 0" 0
out_is "validation new again: writes nothing" ""
err_has "validation new again: names what exists" "exists: $S/claude/validation.md"
sb validation Checks Check-App
rc_is "validation: the repo is matched without letter case" 0
is "validation: the path comes first" "$(printf '%s\n' "$OUT" | head -1)" "path: $S/claude/validation.md"
out_has "validation: then the repo's steps" "### Set up and start"
out_has "validation: to the end of its section" "- npm test"
sb validation Checks nope
rc_is "validation: a repo that is not the project's exits 1" 1
sb validation Checks check-app extra
rc_is "validation: too many arguments exit 5" 5
sb validation new Checks
rc_is "validation new: no repo exits 5" 5
edit "$CKS" 's/^validation_home: ""$/validation_home: repo/'
sb validation Checks
out_has "validation: a subproject's home wins for its repos" "check-infra${TAB}repo${TAB}$oT/ccode/check-infra/validation.md${TAB}missing"
out_has "validation: the profile's holds for the others" "check-app${TAB}vault${TAB}$S/claude/validation.md${TAB}ok"
sb subproject Checks infra
out_has "subproject: shows its own validation home" "validation_home: repo"
edit "$CKS" 's/^validation_home: repo$/validation_home: Repo/'
sb validation Checks
out_has "validation: a home is read in any letter case" "check-infra${TAB}repo${TAB}"
edit "$CKS" 's/^validation_home: Repo$/validation_home: somewhere/'
sb validation Checks
out_has "validation: a home that is not allowed is the vault" "check-infra${TAB}vault${TAB}$S/claude/validation.md${TAB}"
edit "$CKS" 's/^validation_home: somewhere$/validation_home: repo/'
sb validation new Checks check-infra
out_is "validation new: a repo home writes at the repo's root" "$oT/ccode/check-infra/validation.md"
is "validation new: a repo file opens with its title" "$(head -1 "$tmp/ccode/check-infra/validation.md")" "# check-infra validation"
line_is "validation new: then the repo's section" "$tmp/ccode/check-infra/validation.md" "## check-infra"
file_lacks "validation new: a repo file has no frontmatter" "$tmp/ccode/check-infra/validation.md" "type: validation"
sb validation Checks
out_has "validation: the repo file is ok" "check-infra${TAB}repo${TAB}$oT/ccode/check-infra/validation.md${TAB}ok"
rm -rf "$tmp/ccode/check-infra"
sb validation Checks check-infra
rc_is "validation: a repo home whose folder is missing exits 1" 1
err_has "validation: and says so" "the folder of check-infra is missing"
sb scaffold project Checks --path "$S" --keys CK
err_has "validation: a second scaffold leaves the note alone" "exists: $S/claude/validation.md"
VS="$here/skills/vault-setup/SKILL.md"
file_has "vault-setup: lists the validation mode" "$VS" '| validation <project> | link]'
file_has "vault-setup: asks for validation_home" "$VS" '| `validation_home` | whether `validation.md`'
file_has "vault-setup: project mode ends with the validation steps" "$VS" "10. Write each repo's validation steps as"
file_has "vault-setup validation: never invents a step" "$here/skills/vault-setup/validation.md" "Never invent a step."
file_has "vault-setup validation: writes only what the user confirms" "$here/skills/vault-setup/validation.md" "Write only what they confirm"
file_has "vault-setup repo: a new repo gets its validation steps" "$here/skills/vault-setup/repo.md" "Write the repository's validation steps"

# ---------------------------------------------------------------- edge cases
sb validation Checks nope
rc_is "validation: an unknown repo exits 1" 1
out_is "validation: and prints nothing" ""
sb validation new Checks nope
rc_is "validation new: an unknown repo exits 1" 1
out_is "validation new: and writes nothing" ""
sb validation Checks --x
rc_is "validation: a flag as the second argument exits 5" 5
sb validation new Checks -h
rc_is "validation new: a flag exits 5" 5
# The vault note in CRLF: a new section keeps the line endings, after one blank line.
VN="$vault/$S/claude/validation.md"
edit "$CKF" 's|^repos: \[check-app\]$|repos: [check-app, check-web]|'
mkdir -p "$tmp/ccode/check-web"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$VN" >"$tmp/edit.tmp" && cat "$tmp/edit.tmp" >"$VN"
sb validation new Checks check-web
rc_is "validation new: a CRLF note takes a new section" 0
is "validation new: every line keeps its CRLF" "$(grep -vc "$CR\$" "$VN" || true)" "0"
is "validation new: one blank line before the new section" \
  "$(awk '{ sub(/\r$/, "") } $0 == "## check-web" { print prev } { prev = $0 }' "$VN")" ""
is "validation new: and not two" \
  "$(awk '{ sub(/\r$/, "") } $0 == "## check-web" { print p2 } { p2 = prev; prev = $0 }' "$VN" | grep -c . || true)" "1"
# A section with nothing under its heading is empty, not written.
edit "$CKF" 's|^repos: \[check-app, check-web\]$|repos: [check-app, check-web, check-gone]|'
printf '\r\n## check-gone\r\n' >>"$VN"
sb validation Checks
out_has "validation: a section with nothing under it is empty" "check-gone${TAB}vault${TAB}$S/claude/validation.md${TAB}empty"
sb validation new Checks check-gone
err_has "validation new: an empty section is left alone" "exists: $S/claude/validation.md"
edit "$CKF" 's|^repos: \[check-app, check-web, check-gone\]$|repos: [check-app]|'
# A repo home in the profile: no hub link, and no vault note.
P4="work/repohome"
mkdir -p "$vault/$P4/claude"
printf -- '---\ntype: profile\nvalidation_home: repo\n---\n' >"$vault/$P4/claude/profile.md"
sb scaffold project RepoHome --path "$P4" --keys RH
out_lacks "validation: a repo home writes no vault note" "$P4/claude/validation.md"
file_lacks "validation: and the Claude hub does not link to one" "$vault/$P4/claude/README.md" "claude/validation|"
sb unresolved RepoHome
out_is "validation: so the hub's links resolve" ""

# ---------------------------------------------------------------- --json
sb help
out_has "help: names the commands that take --json" "validation <project> [repo] and validation run take --json"
sb validation Checks
text="$OUT"
sb validation Checks --json
rc_is "validation --json: exit 0" 0
json_ok "validation --json: parses as JSON"
json_is "validation --json: the same fields as the text" \
  'for r in d: print("\t".join([r["name"], r["home"], r["path"], r["state"]]))' "$text"
vrow="{\"name\": \"check-app\", \"home\": \"vault\", "
vrow="$vrow\"path\": \"$S/claude/validation.md\", \"state\": \"ok\"}"
out_has "validation --json: one object per repo" "$vrow"
sb validation RepoHome --json
rc_is "validation --json: a project with no repo exits 0" 0
out_is "validation --json: and prints an empty array" "[]"
sb validation Checks check-app
text="$OUT"
sb validation Checks check-app --json
rc_is "validation <repo> --json: exit 0" 0
json_ok "validation <repo> --json: parses as JSON"
json_is "validation <repo> --json: the same fields as the text" 'print("path: " + d["path"])
if d["body"]: print(d["body"])' "$text"
out_has "validation <repo> --json: one object, the path first" \
  "{${NL}  \"path\": \"$S/claude/validation.md\",${NL}  \"body\": \""
out_has "validation <repo> --json: the body's lines are escaped" '\n\n### Checks'
sb validation Checks nope --json
rc_is "validation <repo> --json: an unknown repo exits 1" 1
out_is "validation <repo> --json: and prints nothing" ""
sb validation new Checks check-app --json
rc_is "validation new --json: exit 5" 5

# ---------------------------------------------------------------- result
result
