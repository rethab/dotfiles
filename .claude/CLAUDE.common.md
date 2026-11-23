# General Notes

- When committing, don't set an author: the global git identity is used

- When giving code examples, prefer Java

- Use Context7 for library or API documentation and setup or configuration steps, without waiting for me to ask.

- Always ask before writing memory

- Do not write narrating comments (comments that restate what the next line does). Comments explain *why*, not *what*.

- Strip narrating comments before opening any PR.

## GitHub / gh cli

PR descriptions have no "Test Plan" or "Summary" sections. Say what changed and why, focusing on the why, at a high level rather than listing every change.

When fetching a PR or an issue from GitHub, use the CLI `gh`.

To add a screenshot or video to a PR or issue, use `gh pr edit|create|comment --attach ./shot.png` (same for `gh issue`). To place it inline, reference `![alt](./shot.png)` in the `--body-file` and attach the same file. Never commit images to a branch or host them elsewhere to link them.
