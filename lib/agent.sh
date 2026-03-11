lwt::agent::supported_list() {
  printf 'claude\ncodex\ngemini\n'
}

lwt::agent::is_supported() {
  case "$1" in
    claude|codex|gemini)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

lwt::agent::normalize_spec() {
  local spec="$1"
  local expanded="${spec//,/ }"
  local token=""
  local agent=""
  local -A requested=()
  local -a tokens=()

  expanded="${expanded//-/ }"
  [[ -n "$expanded" ]] || return 1
  tokens=(${=expanded})

  for token in "${tokens[@]}"; do
    if ! lwt::agent::is_supported "$token"; then
      return 1
    fi

    requested[$token]=1
  done

  [[ ${#requested[@]} -gt 0 ]] || return 1

  while IFS= read -r agent; do
    [[ -n "${requested[$agent]:-}" ]] && printf '%s\n' "$agent"
  done < <(lwt::agent::supported_list)

  return 0
}

lwt::agent::command_string() {
  local agent="$1"
  local prompt="$2"
  local yolo="$3"
  local cmd=""

  [[ -z "$agent" ]] && return 1

  if ! lwt::deps::has "$agent"; then
    return 1
  fi

  case "$agent" in
    claude)
      cmd="claude"
      [[ "$yolo" == "true" ]] && cmd="$cmd --dangerously-skip-permissions"
      ;;
    codex)
      cmd="codex"
      [[ "$yolo" == "true" ]] && cmd="$cmd --yolo"
      ;;
    gemini)
      cmd="gemini"
      [[ "$yolo" == "true" ]] && cmd="$cmd --yolo"
      ;;
    *)
      return 1
      ;;
  esac

  if [[ -n "$prompt" ]]; then
    printf '%s %s\n' "$cmd" "$(lwt::shell::quote "$prompt")"
  else
    printf '%s\n' "$cmd"
  fi
}
lwt::agent::launch() {
  local agent="$1"
  local prompt="$2"
  local yolo="$3"
  [[ -z "$agent" ]] && return 0

  if ! lwt::deps::has "$agent"; then
    lwt::ui::warn "$agent is not installed; skipping AI launch."
    return 0
  fi

  # Resolve yolo mode: flag > git config > default (off)
  if [[ "$yolo" != "true" ]]; then
    local configured
    configured=$(git config --get lwt.agent-mode 2>/dev/null)
    [[ "$configured" == "yolo" ]] && yolo=true
  fi

  lwt::ui::step "Launching $agent..."
  case "$agent" in
    claude)
      if [[ "$yolo" == "true" ]]; then
        if [[ -n "$prompt" ]]; then
          claude --dangerously-skip-permissions "$prompt"
        else
          claude --dangerously-skip-permissions
        fi
      else
        if [[ -n "$prompt" ]]; then
          claude "$prompt"
        else
          claude
        fi
      fi
      ;;
    codex)
      if [[ "$yolo" == "true" ]]; then
        if [[ -n "$prompt" ]]; then
          codex --yolo "$prompt"
        else
          codex --yolo
        fi
      else
        if [[ -n "$prompt" ]]; then
          codex "$prompt"
        else
          codex
        fi
      fi
      ;;
    gemini)
      if [[ "$yolo" == "true" ]]; then
        if [[ -n "$prompt" ]]; then
          gemini --yolo "$prompt"
        else
          gemini --yolo
        fi
      else
        if [[ -n "$prompt" ]]; then
          gemini "$prompt"
        else
          gemini
        fi
      fi
      ;;
  esac
}
