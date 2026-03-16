lwt::terminal::resolve_driver() {
  local configured="${LWT_TERMINAL:-}"

  if [[ -z "$configured" ]]; then
    configured=$(lwt::config::get_effective "terminal" 2>/dev/null)
  fi

  if [[ -z "$configured" || "$configured" == "auto" ]]; then
    case "${TERM_PROGRAM:-}" in
      ghostty)
        configured="ghostty"
        ;;
      iTerm.app|iTerm2)
        configured="iterm2"
        ;;
      *)
        return 1
        ;;
    esac
  fi

  case "$configured" in
    ghostty)
      printf 'ghostty\n'
      ;;
    iterm|iterm2)
      printf 'iterm2\n'
      ;;
    *)
      return 1
      ;;
  esac
}

lwt::terminal::launch_ghostty() {
  local mode="$1"
  local target="$2"
  local command="$3"

  osascript - "$mode" "$target" "$command" <<'APPLESCRIPT'
on run argv
  set sessionMode to item 1 of argv
  set targetPath to item 2 of argv
  set shellCommand to item 3 of argv

  tell application "Ghostty"
    activate

    set baseWindow to front window
    set baseTab to selected tab of baseWindow
    set baseTerminal to focused terminal of baseTab
    set surfaceConfig to new surface configuration
    set initial working directory of surfaceConfig to targetPath

    if sessionMode is "split" then
      set newTerminal to split baseTerminal direction right with configuration surfaceConfig
    else
      set newTab to new tab in baseWindow with configuration surfaceConfig
      set newTerminal to focused terminal of newTab
    end if

    input text shellCommand to newTerminal
    send key "enter" to newTerminal
    focus baseTerminal
  end tell
end run
APPLESCRIPT
}

lwt::terminal::launch_iterm2() {
  local mode="$1"
  local target="$2"
  local command="$3"

  osascript - "$mode" "$target" "$command" <<'APPLESCRIPT'
on run argv
  set sessionMode to item 1 of argv
  set targetPath to item 2 of argv
  set shellCommand to item 3 of argv
  set fullCommand to "cd " & quoted form of targetPath & " && " & shellCommand

  tell application "iTerm2"
    activate

    tell current window
      set baseTab to current tab
      set baseSession to current session

      if sessionMode is "split" then
        tell baseSession
          set newSession to (split vertically with same profile)
        end tell
      else
        set newTab to (create tab with default profile)
        set newSession to current session of newTab
      end if

      tell newSession
        write text fullCommand
      end tell

      tell baseTab
        select
      end tell

      tell baseSession
        select
      end tell
    end tell
  end tell
end run
APPLESCRIPT
}

lwt::terminal::launch() {
  local driver="$1"
  local mode="$2"
  local target="$3"
  local command="$4"

  [[ -n "$driver" && -n "$mode" && -n "$target" && -n "$command" ]] || return 1

  if [[ "$(uname -s)" != "Darwin" ]]; then
    return 1
  fi

  if ! lwt::deps::has osascript; then
    return 1
  fi

  case "$driver" in
    ghostty)
      lwt::terminal::launch_ghostty "$mode" "$target" "$command"
      ;;
    iterm2)
      lwt::terminal::launch_iterm2 "$mode" "$target" "$command"
      ;;
    *)
      return 1
      ;;
  esac
}
