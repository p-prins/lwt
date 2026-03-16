lwt::hooks::supported_events() {
  cat <<'EOF'
post-create
post-switch
pre-remove
post-remove
pre-rename
post-rename
pre-merge
post-merge
EOF
}

lwt::hooks::user_dir() {
  printf '%s\n' "${HOME}/.config/lwt/hooks"
}

lwt::hooks::repo_dir() {
  local repo_root="$1"
  [[ -n "$repo_root" ]] || return 1
  printf '%s\n' "$repo_root/.lwt/hooks"
}

lwt::hooks::count_for_root() {
  local root="$1"
  local count=0
  local path

  [[ -d "$root" ]] || {
    printf '0\n'
    return 0
  }

  while IFS= read -r path; do
    [[ -n "$path" ]] && ((count++))
  done < <(find "$root" \( -type f -o -type l \) ! -path '*/.*' 2>/dev/null | sort)

  printf '%s\n' "$count"
}

lwt::hooks::paths_for_event() {
  local event="$1"
  local repo_root="$2"
  local root direct dir
  local -a roots=()

  [[ -n "$event" ]] || return 1

  if [[ -n "${HOME:-}" ]]; then
    roots+=("$(lwt::hooks::user_dir)")
  fi

  if [[ -n "$repo_root" ]]; then
    roots+=("$(lwt::hooks::repo_dir "$repo_root")")
  fi

  for root in "${roots[@]}"; do
    [[ -d "$root" ]] || continue

    direct="$root/$event"
    if [[ -f "$direct" || -L "$direct" ]]; then
      printf '%s\n' "$direct"
    fi

    dir="$root/$event.d"
    if [[ -d "$dir" ]]; then
      find "$dir" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) ! -name '.*' 2>/dev/null | sort
    fi
  done
}

lwt::hooks::run_file() {
  local hook_path="$1"

  if [[ -x "$hook_path" ]]; then
    "$hook_path"
    return $?
  fi

  if lwt::deps::has zsh; then
    zsh "$hook_path"
  else
    sh "$hook_path"
  fi
}

lwt::hooks::run_command() {
  local command="$1"

  [[ -n "$command" ]] || return 0

  if lwt::deps::has zsh; then
    zsh -lc "$command"
  else
    sh -lc "$command"
  fi
}

lwt::hooks::config_commands() {
  local scope="$1"
  local event="$2"
  local config_key="lwt.hook.$event"

  case "$scope" in
    local)
      git config --local --get-all "$config_key" 2>/dev/null
      ;;
    global)
      git config --global --get-all "$config_key" 2>/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

lwt::hooks::describe_event() {
  local event="$1"
  local repo_root="$2"
  local repo_dir=""
  local user_dir=""
  local repo_file="no"
  local user_file="no"
  local repo_dir_count=0
  local user_dir_count=0
  local local_cfg_count=0
  local global_cfg_count=0

  [[ -n "$event" ]] || return 1

  user_dir=$(lwt::hooks::user_dir)
  if [[ -f "$user_dir/$event" || -L "$user_dir/$event" ]]; then
    user_file="yes"
  fi
  if [[ -d "$user_dir/$event.d" ]]; then
    user_dir_count=$(find "$user_dir/$event.d" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
  fi

  if [[ -n "$repo_root" ]]; then
    repo_dir=$(lwt::hooks::repo_dir "$repo_root")
    if [[ -f "$repo_dir/$event" || -L "$repo_dir/$event" ]]; then
      repo_file="yes"
    fi
    if [[ -d "$repo_dir/$event.d" ]]; then
      repo_dir_count=$(find "$repo_dir/$event.d" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
    fi
  fi

  local_cfg_count=$(lwt::hooks::config_commands "local" "$event" | wc -l | tr -d ' ')
  global_cfg_count=$(lwt::hooks::config_commands "global" "$event" | wc -l | tr -d ' ')

  printf '%s\trepo-file:%s\trepo-dir:%s\tlocal-config:%s\tuser-file:%s\tuser-dir:%s\tglobal-config:%s\n' \
    "$event" "$repo_file" "${repo_dir_count:-0}" "${local_cfg_count:-0}" "$user_file" "${user_dir_count:-0}" "${global_cfg_count:-0}"
}

lwt::hooks::run() {
  local event="$1"
  local cwd="$2"
  local repo_root="$3"
  local branch="$4"
  shift 4 || return 1

  local hook_path key value extra_idx configured_command
  local ran_any=false
  local -a extra_env=("$@")

  [[ -n "$event" ]] || return 1
  [[ -n "$cwd" ]] || cwd="$repo_root"
  [[ -n "$cwd" ]] || return 1

  while IFS= read -r hook_path; do
    [[ -n "$hook_path" ]] || continue
    ran_any=true

    lwt::ui::step "Running $event hook: $(basename "$hook_path")"
    (
      cd "$cwd" || exit 1

      export LWT_HOOK_EVENT="$event"
      export LWT_REPO_ROOT="$repo_root"
      export LWT_WORKTREE_PATH="$cwd"
      export LWT_BRANCH="$branch"
      export LWT_DEFAULT_BRANCH="$LWT_DEFAULT_BRANCH"
      export LWT_DEFAULT_BASE_REF="$LWT_DEFAULT_BASE_REF"

      extra_idx=1
      while (( extra_idx <= ${#extra_env[@]} )); do
        key="${extra_env[$extra_idx]}"
        value="${extra_env[$((extra_idx + 1))]}"
        ((extra_idx += 2))
        export "$key=$value"
      done

      lwt::hooks::run_file "$hook_path"
    ) || {
      lwt::ui::error "Hook failed: $hook_path"
      return 1
    }
  done < <(lwt::hooks::paths_for_event "$event" "$repo_root")

  while IFS= read -r configured_command; do
    [[ -n "$configured_command" ]] || continue
    ran_any=true

    lwt::ui::step "Running $event hook from repo config"
    (
      cd "$cwd" || exit 1

      export LWT_HOOK_EVENT="$event"
      export LWT_REPO_ROOT="$repo_root"
      export LWT_WORKTREE_PATH="$cwd"
      export LWT_BRANCH="$branch"
      export LWT_DEFAULT_BRANCH="$LWT_DEFAULT_BRANCH"
      export LWT_DEFAULT_BASE_REF="$LWT_DEFAULT_BASE_REF"

      extra_idx=1
      while (( extra_idx <= ${#extra_env[@]} )); do
        key="${extra_env[$extra_idx]}"
        value="${extra_env[$((extra_idx + 1))]}"
        ((extra_idx += 2))
        export "$key=$value"
      done

      lwt::hooks::run_command "$configured_command"
    ) || {
      lwt::ui::error "Hook failed from repo config: $event"
      return 1
    }
  done < <(lwt::hooks::config_commands "local" "$event")

  while IFS= read -r configured_command; do
    [[ -n "$configured_command" ]] || continue
    ran_any=true

    lwt::ui::step "Running $event hook from global config"
    (
      cd "$cwd" || exit 1

      export LWT_HOOK_EVENT="$event"
      export LWT_REPO_ROOT="$repo_root"
      export LWT_WORKTREE_PATH="$cwd"
      export LWT_BRANCH="$branch"
      export LWT_DEFAULT_BRANCH="$LWT_DEFAULT_BRANCH"
      export LWT_DEFAULT_BASE_REF="$LWT_DEFAULT_BASE_REF"

      extra_idx=1
      while (( extra_idx <= ${#extra_env[@]} )); do
        key="${extra_env[$extra_idx]}"
        value="${extra_env[$((extra_idx + 1))]}"
        ((extra_idx += 2))
        export "$key=$value"
      done

      lwt::hooks::run_command "$configured_command"
    ) || {
      lwt::ui::error "Hook failed from global config: $event"
      return 1
    }
  done < <(lwt::hooks::config_commands "global" "$event")

  $ran_any || return 0
}
