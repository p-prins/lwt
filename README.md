# Light Worktrees (`lwt`)

Git worktrees are powerful but clunky to manage — creating, switching, and cleaning them up involves too many git commands and zero visibility into what's safe to delete. `lwt` wraps the sharp edges into a small, opinionated CLI that stays out of your way.

One command to create a worktree. One command to remove it — with a clear safety summary showing merge status, dirty files, and unpushed commits so you never lose work by accident.

![lwt demo](assets/demo.gif)

## Install

Requires `zsh`, `git`, and `fzf`. You'll also want [`gh`](https://cli.github.com/) for full functionality (see [Requirements](#requirements)).

```bash
git clone https://github.com/linuz90/lwt.git ~/Code/lwt
echo 'source ~/Code/lwt/lwt.sh' >> ~/.zshrc
source ~/.zshrc
```

Verify everything is set up:

```bash
lwt doctor
```

Implementation note: `lwt.sh` remains the only entrypoint you source. It loads the implementation from `lib/*.sh` internally.

## Usage

```bash
lwt add (a)        [branch] [-s] [-e] [-yolo] [--claude|--codex|--gemini [prompt]]
                   [--split "cmd"] [--tab "cmd"] [--split-dev]
                   [--split-claude|--split-codex|--split-gemini [prompt]]
lwt checkout (co)  [query] [-e]
lwt switch (s)     [query] [-e]
lwt list (ls)
lwt remove (rm)    [query]
lwt clean          [-n]
lwt rename (rn)    <new-name>
lwt doctor
lwt help           [command]
```

Examples:

| Command                                              | Description                                                         |
| ---------------------------------------------------- | ------------------------------------------------------------------- |
| `lwt a feat-onboarding -s -e`                        | Start a new feature, install deps, and open it in your editor       |
| `lwt a feat-login --codex "fix the OAuth callback bug"` | Hand a bugfix straight to Codex in the new worktree              |
| `lwt a feat-api --codex "implement webhook retries" --split-dev` | Work with Codex while the app boots in a split        |
| `lwt a feat-search --split "pnpm test --watch" --tab "pnpm lint --watch"` | Open watch sessions alongside the new worktree |
| `lwt a feat-auth --claude "implement refresh token rotation" --split-codex "investigate edge cases in the current auth flow and suggest tests"` | Build with one agent while another investigates in parallel |
| `lwt a`                                              | Create a worktree with a random branch name                         |
| `lwt a existing-remote-branch`                       | Bring an existing local or remote branch under `lwt` management     |
| `lwt co restream`                                    | Pick an open PR matching `restream` and create its worktree         |
| `lwt s auth -e`                                      | Jump to a worktree and open it in your editor                       |
| `lwt clean -n`                                       | Preview merged worktrees before deleting anything                   |
| `lwt rn new-api-name`                                | Rename the current worktree and branch together                     |

## Remote-Aware Status

`lwt` fetches from remotes before showing status, so what you see is always current:

- **merged** — branch is merged (including squash-merge detection via `gh`)
- **dirty** — uncommitted changes in the worktree
- **unpushed** — local commits not yet on the remote
- **behind** — remote has commits you haven't pulled

This matters most during `remove` — you'll see exactly what you'd lose before confirming.

## AI Agent Launch

Spin up a worktree and immediately hand it off to an AI coding agent — one command:

```bash
lwt a feat-api --claude "add retries to webhook sender"
lwt a feat-api --codex "implement OAuth callback handling"
lwt a feat-ui --gemini "refactor profile page layout"
```

The worktree is created, your shell `cd`s into it, and the agent starts working. Each agent gets its own isolated worktree so it can't interfere with your main checkout.

The prompt is optional. Passing `--claude`, `--codex`, or `--gemini` by itself launches that agent interactively in the new worktree.

By default, agents launch in interactive mode. Pass `-yolo` to auto-approve all agent actions for that run, or set it globally:

```bash
git config --global lwt.agent-mode yolo
```

Split-agent flags follow the same agent behavior, but launch in a new split instead of the current shell:

```bash
lwt a feat-api --split-claude "review the auth flow"
lwt a feat-api --split-codex "investigate flaky tests"
lwt a feat-api --split-gemini "compare these approaches"
```

These differ from `--claude`, `--codex`, and `--gemini` in one important way:

- `--claude` / `--codex` / `--gemini` launch the agent in your current shell after `cd`-ing into the new worktree
- `--split-claude` / `--split-codex` / `--split-gemini` launch a second agent session in a new split, leaving your current shell free

## Terminal Automation

`lwt add` can also open extra sessions in your terminal after the worktree is ready:

```bash
lwt a feat-api --split "pnpm test --watch"
lwt a feat-api --tab "pnpm lint --watch"
lwt a feat-api --codex "fix auth" --split-dev
```

What each flag does:

- `--split "cmd"` runs any command in a new terminal split inside the new worktree
- `--tab "cmd"` runs any command in a new terminal tab inside the new worktree
- `--split-dev` resolves the repo's dev command and runs it in a split
- `--split-claude [prompt]` launches Claude in a split, optionally with an initial prompt
- `--split-codex [prompt]` launches Codex in a split, optionally with an initial prompt
- `--split-gemini [prompt]` launches Gemini in a split, optionally with an initial prompt

You can combine multiple session flags in one command if you want several extra sessions opened for the same worktree.

Recommended workflows:

```bash
# You code in the current shell, app boots in a split
lwt a feat-checkout --split-dev

# Codex works in the current shell, dev server runs beside it
lwt a feat-billing --codex "fix invoice retry handling" --split-dev

# One extra split for tests, one extra tab for linting
lwt a feat-search --split "pnpm test --watch" --tab "pnpm lint --watch"

# Use a second agent to investigate in parallel while the first one builds
lwt a feat-auth --claude "implement refresh token rotation" --split-codex "investigate edge cases in the current auth flow and suggest tests"
```

Today this supports Ghostty and iTerm2 on macOS. `lwt` auto-detects the current terminal from `TERM_PROGRAM`, or you can pin one explicitly:

```bash
git config --global lwt.terminal ghostty
```

Use `lwt doctor` to confirm whether terminal automation is available and which driver was detected.

## Dependency Setup

New worktrees don't share `node_modules` with your main checkout. Pass `-s`/`--setup` to auto-install dependencies after creating a worktree:

```bash
lwt a feat-api -s                # create worktree + install deps
```

`lwt` detects your package manager from the lockfile — pnpm, bun, yarn, or npm.

When using an agent flag (`--claude`, `--codex`, `--gemini`, `--split-claude`, `--split-codex`, `--split-gemini`), dependencies are always installed automatically since agents need a working environment.

`--split-dev` also forces setup before launching the dev command in a split. The dev command resolves in this order:

1. `git config lwt.dev-cmd`
2. Root `package.json` `scripts.dev`, run with the detected package manager

For monorepos or custom workflows, set it explicitly:

```bash
git config --global lwt.dev-cmd "pnpm --filter web dev"
```

## Worktree Layout

`lwt add` creates worktrees in:

```text
../.worktrees/<project>/<branch>
```

This keeps your project root and sibling repos clean while making worktrees easy to find and bulk-manage.

## Safe Removal

`lwt remove` never silently deletes work:

- Shows a safety summary first (merge status, dirty state, push state)
- Uses `git worktree remove` as the primary path
- Only forces removal after explicit confirmation
- Offers local and remote branch cleanup after removal

## Bulk Cleanup

`lwt clean` finds all merged worktrees and removes them in one go — worktrees, local branches, and remote branches. Uses the same merge detection as `lwt list` (including squash-merge via `gh`).

Use `lwt clean -n` to preview what would be removed without deleting anything.

## Rename

`lwt rename <new-name>` renames a worktree's branch and moves its directory to match — atomically. If called from inside a linked worktree, it renames that one. Otherwise an fzf picker is shown.

If the branch has been pushed, you'll be prompted to rename the remote branch too. When `gh` is available, open PRs are automatically recreated on the new branch (the old PR is closed with a cross-reference). If an AI agent is running in the worktree, you'll be warned that it will need to be restarted after the rename.

## Editor Integration

Pass `-e` to open the worktree in your editor after creating or switching.

Resolution order:

1. `--editor-cmd "..."` (per command)
2. `git config lwt.editor`
3. `LWT_EDITOR`
4. `VISUAL`
5. `EDITOR`

Recommended setup:

```bash
git config --global lwt.editor zed
```

## Requirements

Required: `git`, `fzf`, `zsh`

Strongly recommended:

- `gh` — used by `list`, `remove`, `clean`, and `rename`. Enables squash-merge detection so merged worktrees are correctly identified, and recreates open PRs when renaming branches. Without `gh`, these features degrade gracefully but you lose visibility and risk orphaned PRs.

Optional:

- `claude`, `codex`, `gemini` CLIs — for agent launch
- macOS + `osascript` + Ghostty or iTerm2 — for split/tab automation

## License

MIT
