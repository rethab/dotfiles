# General Notes

- When committing with git, NEVER create a commit with your own name, but don't specify an author and assume there's a global one set

- When giving code examples, prefer Java

- Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.

- Always ask before writing memory

- Do not write narrating comments (comments that restate what the next line does). Comments explain *why*, not *what*.

- Strip narrating comments before opening any PR.

## GitHub / gh cli

**IMPORTANT**: When creating a PR, don't add "Test Plan" or "Summary" sections. Just write what was changed and why. Focus on the why. Don't include every single change, stay high level.

When fetching a PR or an issue from GitHub, use the CLI `gh`.

To add a screenshot or video to a PR or issue, use `gh pr edit|create|comment --attach ./shot.png` (same for `gh issue`). To place it inline, reference `![alt](./shot.png)` in the `--body-file` and attach the same file. Never commit images to a branch or host them elsewhere to link them.
