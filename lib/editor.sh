lwt::editor::resolve() {
  local override="$1"
  if [[ -n "$override" ]]; then
    printf '%s\n' "$override"
    return 0
  fi

  local from_git
  from_git=$(git config --get lwt.editor 2>/dev/null)
  [[ -n "$from_git" ]] && {
    printf '%s\n' "$from_git"
    return 0
  }

  [[ -n "$LWT_EDITOR" ]] && {
    printf '%s\n' "$LWT_EDITOR"
    return 0
  }

  [[ -n "$VISUAL" ]] && {
    printf '%s\n' "$VISUAL"
    return 0
  }

  [[ -n "$EDITOR" ]] && {
    printf '%s\n' "$EDITOR"
    return 0
  }

  return 1
}

lwt::editor::open() {
  local target="$1"
  local override="$2"
  local editor_cmd

  editor_cmd=$(lwt::editor::resolve "$override") || {
    lwt::ui::hint "No editor configured. Set one with: git config --global lwt.editor \"zed\""
    lwt::ui::hint "Or set LWT_EDITOR, VISUAL, or EDITOR."
    return 0
  }
  if [[ -z "$editor_cmd" ]]; then
    lwt::ui::warn "Editor configuration is empty."
    return 0
  fi

  local -a cmd_parts
  # zsh-aware shell-like splitting for editor commands such as: code -n
  # shellcheck disable=SC2296
  cmd_parts=("${(z)editor_cmd}")
  if [[ ${#cmd_parts[@]} -eq 0 ]]; then
    lwt::ui::warn "Editor configuration is empty."
    return 0
  fi

  "${cmd_parts[@]}" "$target"
}
