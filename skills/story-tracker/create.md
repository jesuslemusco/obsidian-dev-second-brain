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
- Say so when you read a file at another ref.
- Another repository the ticket touches: get its path as
  `## Branch check (start, update, recall)` in `SKILL.md` says.
- Work has started: run `git -C "<repo path>" log --oneline <base>..<branch>` and
  `git -C "<repo path>" diff <base>...<branch>`, with `<base>` the `base_branch` the branch
  check reads.
- Never diff a bare `HEAD`: it may be another ticket's branch.
- Read the files the ticket touches, and search for the functions and components it names.
- Confirm they exist and behave as the ticket assumes.
- Check the ticket against the docs `second-brain profile <project> docs` lists, not against
  memory.
- Note every mismatch between the ticket and the code.

## 3. Create the story

1. `second-brain task new EX-123 --title "<title>" --topics billing/invoices`.
   - Topics are tags, comma separated. The folder `docs/billing/invoices` under the topics root
     `docs` is the tag `billing/invoices`.
   - Add `--project <P>` when the id's key does not name one project.
   - Add `--envs` for an environment set, and read `env-split.md`.
   - Add `--subproject <name>` with the name on the `subproject:` line of `second-brain context`
     from Step 0, or the subproject the user named.
   - No such line, while `second-brain subproject <project>` lists subprojects:
     ask which one the story is in, or none, and pass the answer.
   - A project with no subproject gets no flag.
   - A folder with no README gets one.
2. When `task new` fails or warns:
   - Exit 6: the story exists, or the id is another story's alias. Switch to update mode.
   - Exit 5 with `--envs`: the profile lists no environments.
   - Exit 1 with `--subproject`: the name is no subproject. Show
     `second-brain subproject <project>` and ask.
   - `note: no folder for the topic tag ...` on stderr: run
     `second-brain task tag EX-123 remove <tag>` and ask the user.
3. `second-brain task set EX-123 status=<planned or in-progress> next="<the next action>"
   branch="<branch or none yet>"`, plus `epic=<ID>` when there is one.
4. Fill the sections the template leaves empty:
   - Summary, Description, Findings and Acceptance criteria come from section 1.
   - Each acceptance criterion is a `- [ ]` line.
   - Delete the Findings heading when the story has none.
   - The `**Branch:**` line follows the branch check.
   - Code verification holds what section 2 confirmed, with the ref.
   - Approach / Key decisions, Changes and Verification fill in as the work proceeds.
5. `second-brain task note EX-123 "<where the story stands>" --session <session id from SKILL.md>`.
6. Weigh how the story is built, as `## Spec-driven stories` in `SKILL.md` says.
