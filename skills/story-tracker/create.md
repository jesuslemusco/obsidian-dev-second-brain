# Start a story

Start mode reads this after Step 0, the find (nothing found) and the branch check in `SKILL.md`.
Draft mode reads section 1 only, after Step 0.

## 1. Lock down the framing

Sources, in order: the user, the ticket itself (ask the user to paste it), the branch name and
commits, the files already in the task folder.

- **Summary** - 2-3 sentences: what the ticket is and why it exists.
- **Description** - three lines in exactly this shape, italic markers kept:
  `*As a* <persona>,` then `*I need to* <the concrete work>,` then `*so that* <the outcome>.`
  - The persona is the profile's `persona` key. Ask only when it is `-`.
  - `*so that*` is what the work proves, unblocks or prevents, not the action again.
  - Then 2-4 sentences of context: what is broken or missing, who asked, which environment, date
    or report raised it, where in the system it lives.
  - Name the actual functions, files or keys, one per line, never "the five missing ones".
- **Findings** - only when the story starts from evidence, such as an investigation or a bug
  found in triage.
  - At most 4 bullets, 1-2 lines each.
  - Conclusion first, then the evidence: which store and query, which `file:line`.
  - A ruled-out cause is a finding.
  - Keep a finding only when it changes what someone does next.
- **Acceptance criteria** - the top 4 that define done.
  - Each is checkable by someone else and maps to an artifact: a query result, a log line, a
    deployed change, an updated doc, a follow-up ticket.
  - A fifth folds into one of the four, becomes a follow-up ticket, or goes in the README as a
    detail.
- **Topics** - the folders under the topics root that the story is about, as topic tags.
  - Take the deepest folder that fits, and check it exists:
    `ls -d "<vault>/<project path>/<topics_root>/<folder>"`.
  - `second-brain profile <project> topics` holds only spelling exceptions.
  - A story about no single folder gets no topic tag.
- **Repo** - the one repo the story changes, when `second-brain repo <project>` lists more than
  one. Its branch check, its build and its validation run in that repo.
  - Ask which one, as `## Story rules` in `SKILL.md` says, with each listed repo as an option.
    The user, the ticket or a refinement draft may have named it already: take that one.
  - `second-brain profile <project> repos` says what each one holds.
  - In start mode, the repo settled is not the `repo:` line the branch check printed: run that
    check again with `--path "<path>"`, the path `second-brain repo <project> <name>` prints.
    That run gives section 2's ref, step 3's `branch=` and step 4's `**Branch:**` line, and every
    `second-brain branch` command of this file takes the same `--path`.
  - With one repo listed, or none, ask nothing and write no repo: a story with none takes the
    profile's first.

- Anything unclear or missing: ask for exactly that, as `## Story rules` in `SKILL.md` says. For
  example: "What has to be true for EX-123 to be done?", "Is EX-123 about docs/billing/invoices,
  or wider?"
- One pending detail may go in the file as `> OPEN: ...`. The rest must be real.
- The ticket holds no "Implementation notes", "Validation notes", "Out of scope" or "References".
  That depth goes in the README's Approach / Key decisions, Code verification and Verification
  sections, and in linked notes.

## 2. Verify against the code, read-only

- Edit no code, and write no file but the task README.
- Stay in the repository and on the ref the branch check settled.
- Say so when you read a file at another ref, with
  `second-brain branch <project> <ID> --show <ref> <file>`.
- Another repository the ticket touches: get its path as
  `## Branch check (start, update, recall)` in `SKILL.md` says, and add `--path "<repo path>"`
  to each `second-brain branch` command.
- Work has started: `second-brain branch <project> <ID> --started` prints the log and the diff
  stat of the ticket's branch against the base branch the branch check reads.
- Run no `git` yourself, and never diff a bare `HEAD`: it may be another ticket's branch.
- Read the files the ticket touches, and search for the functions and components it names.
- Confirm they exist and behave as the ticket assumes.
- Check the ticket against the docs `second-brain profile <project> docs` lists, not against
  memory.
- Note every mismatch between the ticket and the code.

## 3. Create the story

Show the owner the text from section 1 first, and write nothing until they approve it:

- Show it whole, then ask with AskUserQuestion whether to write it or change it. The owner says
  what to change in the free-text answer.
- A change: make it, show the changed text again, then ask again.
- Only the owner's approval counts. Never take a change, a question or silence for one.
- No AskUserQuestion, as in a subagent: show the text, end with the question, and write nothing.

A story the scrum-master's refinement got approved is approved already. Write it from that text,
as `planned`. Work on it has not started, so step 6 waits until it does.

Then, before step 1, look for a story that already does the same, and for the epic it could
join. Every new story gets this check, one from refinement too:

- Search the project's stories, open and done:
  `second-brain search <project> "<terms>" --in <tasks_root>`, with `tasks_root` from Step 0.
  - Search once by the title, once by the Summary and once by each acceptance criterion, in one
    Bash call, chained with `;` so that a search with no match stops none of the others.
  - A note matches only when it holds every term: give each search the 2 or 3 words that name
    its outcome. Exit 1, `no match in <folder>`: no note holds them.
- Each story README a search finds: `second-brain task head <ID>`, with the folder that holds it
  as the id, prints its title, status, parent and Summary. When the head leaves its outcome open,
  read its acceptance criteria with `second-brain outline` and a ranged read.
- A story matches when its outcome is the new story's, even in other words. Show each match: its
  id, title and status, and the outcome they share. Leave out an abandoned one.
- List the open epics the story could join, each `planned`, `in-progress` or `in-review` in its
  `task head`:
  - The parent each story the searches found names, on the `epic:` line of its head, `feature:`
    with `parent_label: feature`.
  - Each task the searches found that another task names as its parent:
    `second-brain search <project> "\"epic: <ID>\"" --in <tasks_root>` prints the `epic: <ID>`
    line of each child, chained with `;` as above. Exit 1: none does.
    - The key is `epic` in every project, `parent_label: feature` too.
    - A line with a longer id, such as `epic: <ID>0`, names another task.
  - For a story from refinement, the parent its approved draft names.
  - Each epic under `## Epics` in `<project path>/<topics_root>/planned-releases.md`, when the
    project has that note: `second-brain outline` and a ranged read.
  - Say epic or feature, as Step 0 of `SKILL.md` names it.
- Propose one of them, or none, with the reason: the epic whose outcome the new story serves, or
  why none needs it. For a story from refinement, propose the parent its approved draft names, or
  none for `-`.
- Ask the owner with AskUserQuestion to pick one:
  - Change the story that exists: show the change to it beside what it says now, and write it in
    update mode, as `## Edit an existing story` in `SKILL.md` says, only once the owner approves
    it. Write no new story, and say which story took its place, for a refinement to link.
    - A story from refinement whose draft names a parent: the change moves it under that parent,
      `second-brain task set <ID> epic=<parent>`, unless the owner keeps it under its own. Say
      which parent it is under, and the one it left.
  - File the new one under an epic: write it as the steps below say, with `epic=<ID>` in step 3.
  - Write it on its own: write it as the steps below say, with no `epic`.
  - With no match, offer the last two.
- Write nothing, no story, key or note, before the owner picks. No AskUserQuestion, as in a
  subagent: show the matches and the epics, end with the question, and write nothing.

1. `second-brain task new EX-123 --title "<title>" --topics billing/invoices`.
   - Topics are tags, comma separated. The folder `docs/billing/invoices` under the topics root
     `docs` is the tag `billing/invoices`.
   - Add `--project <P>` when the id's key does not name one project.
   - Add `--envs` for an environment set, and read `env-split.md`.
   - Add `--repo <name>` with the repo section 1 settled. With one repo listed, or none, no flag.
   - A folder with no README gets one.
2. When `task new` fails or warns:
   - Exit 6: the story exists, or the id is another story's alias. Switch to update mode.
   - Exit 5 with `--envs`: the profile lists no environments.
   - Exit 1 with `--repo`: the name is no repo of the project. Show
     `second-brain repo <project>` and ask.
   - `note: no folder for the topic tag ...` on stderr: run
     `second-brain task tag EX-123 remove <tag>` and ask the user.
3. `second-brain task set EX-123 status=<planned or in-progress> next="<the next action>"
   branch="<branch or none yet>"`, plus `epic=<ID>` when the owner filed it under a parent, the
   project's feature or epic, as Step 0 of `SKILL.md` names it.
   - With `task_layout: status` or `sprint`, the call moves the story into a folder named for its
     parent, and prints its new path after the keys.
4. Fill the sections the template leaves empty:
   - Summary, Description, Findings and Acceptance criteria come from section 1.
   - Each acceptance criterion is a `- [ ]` line.
   - Delete the Findings heading when the story has none.
   - The `**Branch:**` line follows the branch check.
   - Code verification holds what section 2 confirmed, with the ref.
   - Approach / Key decisions, Changes and Verification fill in as the work proceeds.
   - Add no section the README lacks: a project's own template may leave some out.
5. Every story written here was approved, here or in refinement: first
   `second-brain task note EX-123 "Planned: the owner approved this text." --session <session id from SKILL.md>`.
   - Work on it has started: then
     `second-brain task note EX-123 "<where the story stands>" --session <session id from SKILL.md>`.
6. Offer the build, as `## Building a story` in `SKILL.md` says.
