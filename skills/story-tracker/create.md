# Start a story

Start mode, after Step 0, the find (nothing found) and the branch check in `SKILL.md`. Draft
mode reads section 1 alone, after Step 0.

## 1. Lock down the framing

Sources, in order: the user, the ticket itself (ask the user to paste it), the branch name and
commits, files already in the task folder.

- **Summary** - 2-3 sentences: what the ticket is and why it exists.
- **Description** - three lines in exactly this shape, italic markers kept: `*As a* <persona>,`
  then `*I need to* <the concrete work>,` then `*so that* <the outcome>.` The persona is the
  profile's `persona` key; ask only when it is `-`. `*so that*` is what the work proves, unblocks
  or prevents, not the action again. Follow with the context: what is broken or missing, who
  asked, which environment, date or report raised it, where in the system it lives. Name the
  actual functions, files or keys, one per line, never "the five missing ones".
- **Findings** (optional) - only when the story starts from evidence, such as an investigation or
  a bug found in triage. Conclusion first, then the evidence: which store and query, which
  `file:line`. A ruled-out cause is a finding.
- **Acceptance criteria** - the top 4. Each is checkable by someone else and maps to an artifact:
  a query result, a log line, a deployed change, an updated doc, a follow-up ticket. A fifth folds
  into one of the four, becomes a follow-up ticket, or goes in the README as a detail.
- **Topics** - the folders under the topics root that the story is about, as topic tags. Take the
  deepest that fits and check it exists: `ls -d "<vault>/<project path>/<topics_root>/<folder>"`.
  `second-brain profile <project> topics` only holds spelling exceptions. A story about no single
  folder gets no topic tag.

Anything unclear or missing: ask for exactly that ("What has to be true for EX-123 to be done?",
"Is EX-123 about docs/billing/invoices, or wider?"). Never invent acceptance criteria or a topic.
One pending detail may go in the file as `> OPEN: ...`; the rest must be real.

### Keep stories short

These limits hold for the README's framing and for ticket text, which `SKILL.md` covers.

| Part | Limit |
|---|---|
| Whole ticket description | one screen, about 40 lines |
| Three-part opening | 1 line each, 3 in total |
| Context | 2-4 sentences |
| Findings | max 4 bullets, 1-2 lines each |
| Acceptance criteria | max 4 bullets, the top 4 that define done |

- No "Implementation notes", "Validation notes", "Out of scope" or "References" in the ticket.
  That depth lives in the README (Approach / Key decisions, Code verification, Verification) and
  in linked notes.
- Cut what only proves how much work the investigation was. A finding earns its place by changing
  what someone does next.

## 2. Verify against the code, read-only

Ground the ticket in the code before writing. No code edits, no new file except the task README.

- Stay in the repository and on the ref settled in the branch check. If you read a file at
  another ref, say so. Another repository the ticket touches: `second-brain repo <project> <name>`
  gives its path; on exit 1 say which case it is and ask, never guess a path.
- Work has started: `git -C "<repo path>" log --oneline <base>..<branch>` and
  `git -C "<repo path>" diff <base>...<branch>`, with the profile's `base_branch`. Never diff a
  bare `HEAD`; it may be another ticket's branch.
- Read the files the ticket touches. Search for the functions and components it names. Confirm
  they exist and behave as the ticket assumes.
- Cross-check the docs the profile points to (`second-brain profile <project> docs`), not memory.
- Note every mismatch between the ticket and the code. It is often the story.

## 3. Create the story

1. `second-brain task new EX-123 --title "<title>" --topics billing/invoices`. Topics are tags,
   comma separated: the folder `docs/billing/invoices` under the topics root `docs` is
   `billing/invoices`. Add `--project <P>` when the id's key does not name one project, and
   `--envs` for an environment set (read `env-split.md`). A folder with no README gets one.
2. Exit 6: the story exists, or the id is another story's alias; switch to update mode. Exit 5
   with `--envs`: the profile lists no environments. A `note: no folder for the topic tag ...` on
   stderr: run `second-brain task tag EX-123 remove <tag>` and ask the user.
3. `second-brain task set EX-123 status=<planned or in-progress> next="<the next action>"
   branch="<branch or none yet>"`, plus `epic=<ID>` when there is one.
4. Fill the sections the template leaves empty. Summary, Description, Findings (delete the heading
   when unused) and Acceptance criteria (`- [ ]` lines) come from section 1. Branch follows the
   branch check. Code verification holds what section 2 confirmed, with the ref. Approach / Key
   decisions, Changes and Verification fill in as the work proceeds.
5. `second-brain task note EX-123 "<where the story stands>" --session <session id from SKILL.md>`.
