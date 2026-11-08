---
name: story-tracker
description: Use for any question or change on a vault ticket, even one the helper could answer: where a ticket stands, an update, a standup, a draft, ticket text (summary, description, acceptance criteria).
argument-hint: "[TICKET-ID | status [all | <status> | <topic> | sprint]]"
allowed-tools: Read Grep Glob Bash(second-brain *)
---

# Story tracker

A story is a task's `README.md` in the vault.

Conventions: before writing notes, run `second-brain conventions` and follow it. The full note is ~/.claude/second-brain-vault/obsidian-conventions.md.

The session id for notes is `${CLAUDE_SESSION_ID}`.

## Step 0 - Context, project, profile

Run these yourself, before anything else. Chain them in one Bash call where that helps.

1. `second-brain context`.
   - Command not found: the plugin is not enabled. Say so and stop.
   - `vault: none`: say no vault is set up, offer `/odsb:vault-setup`, stop.
2. Resolve the project, first match wins: the name the user gave
   (`second-brain project --name <N>`), the ticket id (`--key EX-123`), else the `project:` line.
   - `none`, exit 1 or exit 4: show `second-brain projects` and ask.
3. `second-brain profile <project> --keys` prints the settings the steps below name.
   - Exit 1: no profile. Say so, offer `/odsb:vault-setup adopt`, stop.
   - A subproject's settings win, from `second-brain subproject <project> <name>`. The subproject
     is the `subproject:` line, the task's `subproject` key, or the one the user names.
   - A new story names its subproject as `## 3. Create the story` in `create.md` says.
   - `task_layout` is `flat` or `archive`. A profile with no such line is `flat`.
4. `second-brain profile <project> stories` prints what this project does differently.
   - Exit 1 here only means there is no Stories section. Carry on.
   - Read other sections only when a step names them.

## Modes

| Mode | When | Do |
|---|---|---|
| draft | The user wants a ticket written, with or without an id | Read `${CLAUDE_SKILL_DIR}/create.md` section 1, fill `${CLAUDE_PLUGIN_ROOT}/templates/ticket-description.md.tmpl`, reply with the text. Write no file until the id arrives, then go to start |
| start | Work begins on a ticket with no story, often signalled by a branch named for it | Find (expect none), branch check, then read `${CLAUDE_SKILL_DIR}/create.md` |
| update | A decision, a root cause, a changed approach or a status move on a tracked ticket | Find, branch check, then `## Edit an existing story` |
| recall | The user refers to a tracked ticket | Find, branch check, then read cheapest first |
| status | "What is active", a standup summary, the stories on a topic, of a subproject or in the sprint | Read `${CLAUDE_SKILL_DIR}/status.md`. No branch check |
| environment set | The story has an `envs:` mapping, the id asked for is only an alias, or the user wants a ticket per environment | Also read `${CLAUDE_SKILL_DIR}/env-split.md` |

Ticket text, in draft mode or when the user asks for text to paste into the tracker:

- Fill `${CLAUDE_PLUGIN_ROOT}/templates/ticket-description.md.tmpl`. Never write it freehand.
- A story exists: fill it from the story, with the README's Description and acceptance criteria.
- Reply with plain text in the tracker's markup.
- Keep it to one screen, about 40 lines.
- Add no section the template lacks.

## Find the story

- `second-brain find <ID> --project <P>` prints the story's path, relative to the `vault:` path.
- Exit 1: the ticket is not tracked. That is expected in start mode. Otherwise say so and offer to
  start it.
- The path's folder is not the id you asked for: the id is an alias. That file is the story, and
  every command that takes an id accepts the alias.
- Never create a folder for an alias, or a second README for a tracked id.
- The path is outside the profile's `tasks_root`: the story predates the layout. Say so and offer
  to move it with `second-brain move`.
- The path is `<tasks_root>/archive/<YYYY>/<ID>/README.md`: the story is archived. Read and edit
  it as any other.
- Take a story's path from `find` or `task head`; never build it from the id.
- Read cheapest first: `second-brain task head <ID>`, then `second-brain outline <path>` and a
  ranged read of one section. A whole README last.

## Branch check (start, update, recall)

Know the exact ref, the branch and its HEAD commit, before you reason about, recall or review a
ticket.

- `second-brain repo <project>` lists the repos, the default first. For the one the ticket
  touches, `second-brain repo <project> <name>` prints its path.
- Exit 1, or a state other than `ok`: say which case it is (not listed, no location recorded,
  folder missing) and ask the user where the repo is.
- `second-brain profile <project> repos` says what each repo holds.
- Run git as `git -C "<repo path>"`.
- Get the current branch and its HEAD commit.
- List every local or remote branch whose name carries the ticket id:
  `git -C "<repo path>" branch -a --list '*<ID>*'`.
- `base_branch` and `branch_pattern` give the base branch and the branch naming.
- A new story's branch is cut from the base branch.
  - A story that needs another story's code not yet in the base branch is cut from that story's
    branch.
- No id given: derive it from the branch with `branch_pattern`. Still unknown: ask.
- The branch does not match the ticket: read the right ref without switching, with
  `git -C "<repo path>" show <branch>:<file>`, or tell the user.
- Environment set: one branch, named for the first environment's id, serves every ticket in the
  set.
  - Being on it for a later environment's ticket is no mismatch. A mismatch is a branch that
    carries no id from `aliases`.
  - Never rename it, or cut a branch for a later id.
- Several branches match one ticket: ask which is canonical.
- Record the ref:
  - `second-brain task set <ID> branch=<branch>`.
  - In the `**Branch:**` line: the branch, its HEAD and the date, plus one line per other branch
    with that id and how it differs.
  - No branch yet: record `none yet`, and name the branch the repo was on.
  - A changed canonical branch also gets a status note.

## Spec-driven stories

Weigh how a story is built when work starts on it: in start mode once the story exists, or on a
move to `in-progress`.

- A story has its own `delivery` when its README's frontmatter sets the key. Read the frontmatter
  with a ranged read.
  - `second-brain spec <ID>` cannot tell: its `delivery` line may come from the subproject or the
    profile.
- A story with its own `delivery` is never weighed again.
  - `spec`: say the story is built from a spec and offer `/odsb:spec <ID>`.
  - `direct`: go on here.
- The user says how to build it, such as "spec-driven": write it with
  `second-brain task set <ID> delivery=<value>`, then go on as for a story with its own `delivery`.
- Any other story: weigh it from its criteria and the code they touch.
  - Spec-driven: the story is big, unclear, or meant to run without the owner.
  - Signs: many files or repos, open questions in the criteria, a long unattended build.
  - Direct: any other story.
- Weighed direct: run `second-brain task set <ID> delivery=direct` and ask nothing. Say so in one
  line, with the reason.
- Weighed spec-driven: describe the story in at most three lines: what it changes, what it
  touches and how many criteria it has. Then say why a spec helps.
  - Ask the owner with AskUserQuestion: `spec` or `direct`.
  - Write the answer with `second-brain task set <ID> delivery=<answer>`.
  - `spec`: offer `/odsb:spec <ID>`. `direct`: go on here.
- A story built from a spec: do not plan or write its code here.

## Edit an existing story

- Keep the README's narrative. Change only what moved.
- Set scalar keys (`status`, `title`, `next`, `branch`, `epic`) through the helper, never by hand:
  `second-brain task set <ID> status=in-review next="<one phrase, the next action>"`.
  - An unknown status exits 5.
- Keep `title` and `next` current.
- Log what happened: `second-brain task note <ID> "<text>" --session <session id>`.
- Tick the acceptance criteria that are now met.
- Refresh the `**Branch:**` line.
- Never edit project docs from this skill: `docs-keeper` makes the edits once the story reaches
  production.
- Work that will change docs: list each planned edit under `## Docs to update` as a `- [ ]` line,
  with the doc path and what will change.
  - Create that section just before `## Status notes` when it is absent.
- The story reaches production: start the `docs-keeper` agent
  (`odsb:docs-keeper`) with the project, the ticket id and the README path.
  Ask it for Workflow 5, a ticket marked done.
  - Production means its last environment is set to `done`, or the story is set to `done` in a
    project with no environments.
  - Start it with or without a `## Docs to update` section.
  - When the session cannot start an agent, say so and name `docs-keeper` as the one to run now.
- The story is set to `done` or `abandoned` and the profile says `task_layout: archive`: after
  the docs-keeper hand-off, ask once whether to archive it now.
  - On a yes, run `second-brain task archive <ID>` and report the path it prints.
  - Never archive a story without that yes.
- An archived story is set back to `planned`, `in-progress` or `in-review`: ask whether to move it
  back.
  - On a yes, run `second-brain move "<its folder>" "<project path>/<tasks_root>/<ID>"`, then
    `second-brain task set <ID> archived=`.
- The story reaches another topic: `second-brain task tag <ID> add <tag>`.
- The story moves off a topic: `second-brain task tag <ID> remove <tag>`.
- The story waits on another task: `second-brain task dep <ID> add <other ID>`.
- The story no longer waits on it: `second-brain task dep <ID> remove <other ID>`.
- Never write a `**Depends on:**` body line.
- A README with no task frontmatter: never rewrite its body. Run
  `second-brain task alias <ID> add <ID>`,
  `second-brain task set <ID> type=task title="..." next="..."` and
  `second-brain task note <ID> "<text>"`.

## Log discoveries

New evidence that changes or sharpens the ticket, such as a root cause, a ticket-versus-code
mismatch, a corrected assumption or a validation result: ask the user whether to log it, and log
it only on a yes.

- Put it on top of `## Discovery log`: ``**YYYY-MM-DD (session `<session id>`) - <conclusion>**``,
  then the evidence: the file and line at a named ref, the query, the doc.
- Record the conclusion, not the play-by-play.
- One entry per session and finding.
- It contradicts the Summary, Description or Acceptance criteria: update those too.
- A general, reusable fact goes in its own vault note, linked from the entry.

## Links

- Link a story by its path: `[[<project path>/<tasks_root>/EX-123/README|EX-123]]`.
  - An archived story's path is the one `find` prints.
  - In a table cell, write the pipe as `\|`.
- Run `second-brain move` or `second-brain rename` with `--dry-run` first.
- Never rename a task folder.

## Story rules

- Never infer a status from prose: read the frontmatter.
- In helper output `-` means empty. Show a missing field as `-` too.
- A missing or non-standard status is "Needs a status": report it, and set it only after asking.
- The code is the source of truth: verify every file, line and behaviour claim against the ref
  before you record it, and name the ref.
- Ask with AskUserQuestion, never invent or guess: a path, acceptance criteria, topics, the
  canonical branch, an id.
- The ticket arrives for a story whose folder is a slug: run
  `second-brain task alias <slug> add <ID>`.
- Stories are short and durable: decisions, root causes, outcomes, gotchas, not a chat log.
- Write absolute dates in notes. Never "yesterday" or "last week".
- Say "ticket" and "tracker". The tracker's name is the profile's `tracker`.
- Leave `sprint` and `carried_from` to the sprint skill unless the user asks.
- Keep story state in the vault only: never in Claude's memory or the code repo.
