# A story finishes

Read this in done mode only, after Step 0 of `SKILL.md`.

1. Update the story through the story-tracker skill first. It hands the story to `docs-keeper`,
   as its `## Edit an existing story` says.
2. Run `second-brain profile <project> --keys` and read `achievements_skill`. `-` means none: stop
   here.
3. A skill name: invoke it with the Skill tool by that exact name. Hand it the sprint note, when
   the project has one, and the finished story file as its source.
   - The skill takes the real outcome and impact from that file, not from your summary.
   - Take that file's path from the `path:` line of `second-brain task head <ID> --project <project>`.
   - Never build the path from the id.
4. Any doubt over what counts as the delivered outcome: confirm the achievement wording with the
   user before it is written.
5. Never log an achievement for work that is not done, or that you cannot tie to a finished story
   or a verifiable artifact.
6. Report the outcome, not the activity: what was delivered and its impact, from the finished
   story.
