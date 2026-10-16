---
name: story-tracker
description: Write ticket text (summary, description, acceptance criteria) and track stories as one README per task in the Obsidian vault - draft, start, update, recall, list.
argument-hint: "[TICKET-ID | status [all | <status> | <topic> | sprint]]"
allowed-tools: Read Grep Glob Bash(second-brain *)
---

# Story tracker

A story is one task folder's `README.md` in the vault, named by its ticket id. This file is the
workflow. Everything that differs between projects comes from the project's profile.

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

The session id for notes is `${CLAUDE_SESSION_ID}`.

## Step 0 - Context, project, profile

Run these yourself, before anything else. Chain them in one Bash call where that helps.

1. `second-brain context`. Command not found: the plugin is not enabled; say so and stop.
   `vault: none`: say no vault is set up, offer `/obsidian-dev-second-brain:vault-setup`, and
   stop. Never guess paths.
2. Resolve the project, first match wins: the name the user gave
   (`second-brain project --name <N>`), the ticket id (`--key EX-123`), else the `project:` line.
   `none`, exit 1 or exit 4: show `second-brain projects` and ask.
3. `second-brain profile <project> --keys` prints the settings the steps below name. Exit 1: the
   profile is missing; say so, offer `/obsidian-dev-second-brain:vault-setup adopt`, and stop.
4. `second-brain profile <project> stories`: what this project does differently. Exit 1 here only
   means there is no Stories section; carry on. Read other sections only when a step names them.

## Modes

| Mode | When | Do |
|---|---|---|
| draft | The user wants a ticket written, with or without an id | Read `${CLAUDE_SKILL_DIR}/create.md` section 1, fill `${CLAUDE_PLUGIN_ROOT}/templates/ticket-description.md.tmpl`, reply with the text. Write no file until the id arrives, then go to start |
| start | Work begins on a ticket with no story, often signalled by a branch named for it | Find (expect none), branch check, then read `${CLAUDE_SKILL_DIR}/create.md` |
| update | A decision, a root cause, a changed approach or a status move on a tracked ticket | Find, branch check, then "Edit an existing story" |
| recall | The user refers to a tracked ticket | Find, branch check, then read cheapest first |
| status | "What is active", a standup summary, the stories on a topic or in the sprint | Read `${CLAUDE_SKILL_DIR}/status.md`. Read-only, no branch check |
| environment set | The story has an `envs:` mapping, the id asked for is only an alias, or the user wants a ticket per environment | Also read `${CLAUDE_SKILL_DIR}/env-split.md` |

Ticket text, in draft mode or when the user asks for text to paste into the tracker: fill
`${CLAUDE_PLUGIN_ROOT}/templates/ticket-description.md.tmpl`, from the story when there is one, and
reply with plain text in the tracker's markup. Never write it freehand. One screen, about 40
lines, at most 4 findings and 4 acceptance criteria, the same Description and criteria as the
README, when there is one, and no other sections.

## Find the story

- `second-brain find <ID> --project <P>` prints the story's path, relative to the `vault:` path.
  Exit 1 means not tracked: expected in start mode, otherwise say so and offer to start it.
- The path's folder is not the id you asked for: the id is an alias, usually a later environment's
  ticket in an environment set. That file is the story, and every command that takes an id
  accepts the alias. Never create a folder for an alias, or a second README for a tracked id.
- The path is outside the profile's `tasks_root`: the story predates the layout. Say so and offer
  to move it with `second-brain move`.
- Read cheapest first: `second-brain task head <ID>` (it shows the path, and `envs` for a set),
  then `second-brain outline <path>` and a ranged read of one section. A whole README last.

## Branch check (start, update, recall)

A story is only as correct as the code it was read from. Know the exact ref, branch plus HEAD
commit, before you reason about, recall or review a ticket.

- Repository: `second-brain repo <project>` lists name, path and state, the default first. For the
  one the ticket touches use `second-brain repo <project> <name>`, which prints its path. Exit 1,
  or a state other than `ok`: say which case it is (not listed, no location recorded, folder
  missing) and ask the user where it is. Never guess a path. What each repository holds is in
  `second-brain profile <project> repos`.
- Run git as `git -C "<repo path>"`. Get the current branch and its HEAD commit, and list every
  local or remote branch whose name carries the ticket id (`branch -a --list '*<ID>*'`). The
  profile keys `base_branch` and `branch_pattern` give the base and the naming.
- No id given: derive it from the branch with `branch_pattern`. Still unknown: ask, never invent.
- The branch does not match the ticket: you are looking at the wrong code. Read the right ref
  without switching (`git -C "<repo path>" show <branch>:<file>`), or tell the user.
- Environment set: one branch, named for the first environment's id (the folder name), serves
  every ticket in the set. Being on it while asked about a later environment's ticket is correct,
  not a mismatch; a mismatch is a branch carrying no id from `aliases`. Never "correct" its name
  or cut a branch for a later id: the code is promoted, not rewritten.
- Several branches match one ticket: they often differ materially (a rework, a PR head). Ask which
  is canonical. Never guess.
- Record the ref: `second-brain task set <ID> branch=<branch>`, and in the `**Branch:**` line the
  branch, its HEAD and the date, plus one line per other branch with that id and how it differs.
  No branch yet: `none yet`, and name the branch the repo was on, so a later session knows the
  code read was not this ticket's. A changed canonical branch also gets a status note.

## Edit an existing story

- The README is a human-facing document. Preserve its narrative; change only what moved.
- Set scalar keys (`status`, `title`, `next`, `branch`, `epic`) through the helper, never by hand:
  `second-brain task set <ID> status=in-review next="<one phrase, the next action>"`. Status is
  `planned`, `in-progress`, `in-review`, `done` or `abandoned`; any other value exits 5. Setting it
  also sets the `status/` tag. Keep `title` and `next` current: the overview reads them.
- Log what happened: `second-brain task note <ID> "<text>" --session <session id>`. It prepends a
  dated line under `## Status notes`.
- Tick the acceptance criteria that are now met, and refresh the `**Branch:**` line.
- Never edit project docs here: docs follow production. Work that will change docs: list each
  planned edit as a `- [ ]` line (the doc path and what will change) under `## Docs to update`,
  created just before `## Status notes` when absent. Those edits wait for production.
- The story reaches production (its last environment set to `done`, or the story set to `done`
  in a project with no environments) with unticked lines under `## Docs to update`: say so and
  name the `docs-keeper` agent as the one that makes those edits now. Do not start it yourself.
- Topic tags stay true: `second-brain task tag <ID> add <tag>` when the story reaches another
  topic whose folder exists, `remove <tag>` when it moves off one.
- A README with no task frontmatter: never rewrite its body. Run
  `second-brain task alias <ID> add <ID>` (the folder id becomes the first alias),
  `second-brain task set <ID> type=task title="..." next="..."` and
  `second-brain task note <ID> "<text>"`. Set `status` only after asking.

## Log discoveries

New evidence that changes or sharpens the ticket (a root cause, a ticket-versus-code mismatch, a
corrected assumption, a validation result): ask the user whether to log it. Never log unasked.

- Put it on top of `## Discovery log`: ``**YYYY-MM-DD (session `<session id>`) - <conclusion>**``,
  then the evidence (file and line at a named ref, the query, the doc).
- Record the conclusion, not the play-by-play. One entry per session and finding.
- If it contradicts the Summary, Description or Acceptance criteria, update those too. The log is
  the changelog; the body stays current.
- A general, reusable fact goes in its own vault note, linked from the entry.

## Links

- A bare alias link such as `[[EX-123]]` does not resolve, because every story is named
  `README.md`. Write the path form, `[[<project path>/<tasks_root>/EX-123/README|EX-123]]`, with
  the pipe as `\|` inside a table cell.
- After writing links, run `second-brain unresolved <project>`. None of your links may be listed.
- Move or rename a note only with `second-brain move` / `second-brain rename`, so the links to
  it are rewritten. Add `--dry-run` first to see what would change. Never fall back to `mv`,
  and never rename a task folder.

## Story rules

- Frontmatter is the source of truth. Never infer a status from prose. In helper output `-` means
  empty; show a missing field as `-` too. A missing or non-standard status is "Needs a status":
  report it, set it only after asking.
- The code is the source of truth. Verify every file, line and behaviour claim against the actual
  ref before recording it, and say which ref.
- Ask with AskUserQuestion, never invent: acceptance criteria, topics, the canonical branch, an id.
- The folder name is the story's id and first alias. No ticket yet: a kebab-case slug is the id.
  Once the ticket exists run `second-brain task alias <slug> add <ID>`; every command then accepts
  the ticket id, and the folder keeps the slug.
- Stories are short and durable: decisions, root causes, outcomes, gotchas, not a chat log. Depth
  lives in the README sections, not in the ticket text.
- Notes are session-tagged, absolute-dated, newest first. Never "yesterday" or "last week".
- Say "ticket" and "tracker". The tracker's name is the profile's `tracker`.
- Leave `sprint` and `carried_from` to the sprint skill unless the user asks.
- Vault only. Never copy story state into Claude's memory or into the code repo.
