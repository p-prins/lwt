# lwt — Light Worktrees

Shell-based CLI for managing git worktrees. `lwt.sh` is the public entrypoint and sources the implementation from `lib/*.sh`.

## Testing

After editing `lwt.sh` or any file in `lib/`, always test through the public entrypoint before considering the change done:

```bash
source lwt.sh && lwt <command> [args]
```

This catches runtime errors (bad math expressions, missing variables, syntax issues) that aren't visible from reading the code alone.

## Structure

Use `lwt.sh` as the only entrypoint. It sources these modules in order:

- `lib/core.sh`: globals, dependency checks, UI helpers, shared shell/utils
- `lib/git.sh`: repo detection, default branch resolution, stale fetch
- `lib/status.sh`: merge detection, per-worktree flags, gh mode
- `lib/worktree.sh`: worktree discovery, creation, display rows
- `lib/editor.sh`: editor resolution and launch
- `lib/project.sh`: package manager detection, script lookup, dependency install, dev command resolution
- `lib/terminal.sh`: terminal driver detection and split/tab automation
- `lib/agent.sh`: agent launch and command construction
- `lib/help.sh`: CLI help text
- `lib/commands.sh`: `lwt::cmd::*`, checkout helpers, and dispatch

Keep modules as pure function definitions and shared globals. Do not source individual `lib/*.sh` files directly in tests or docs.

## Dependencies

- Required: `git`, `fzf`, `zsh`
- Strongly recommended: `gh` (squash-merge detection, PR recreation on rename, PR tags in list)
- Optional: `claude`, `codex`, `gemini` CLIs
- Optional for split/tab automation: macOS, `osascript`, and Ghostty or iTerm2
