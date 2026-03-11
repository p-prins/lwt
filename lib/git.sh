lwt::git::ensure_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    lwt::ui::error "Not inside a Git repository."
    return 1
  fi
}

lwt::git::resolve_default_branch() {
  local origin_head
  origin_head=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)

  if [[ -n "$origin_head" ]]; then
    LWT_DEFAULT_BRANCH="${origin_head#origin/}"
  elif git show-ref --verify --quiet refs/heads/main || git show-ref --verify --quiet refs/remotes/origin/main; then
    LWT_DEFAULT_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master || git show-ref --verify --quiet refs/remotes/origin/master; then
    LWT_DEFAULT_BRANCH="master"
  else
    LWT_DEFAULT_BRANCH=$(git branch --show-current 2>/dev/null)
  fi

  [[ -z "$LWT_DEFAULT_BRANCH" ]] && LWT_DEFAULT_BRANCH="main"

  if git show-ref --verify --quiet "refs/remotes/origin/$LWT_DEFAULT_BRANCH"; then
    LWT_DEFAULT_BASE_REF="origin/$LWT_DEFAULT_BRANCH"
  elif git show-ref --verify --quiet "refs/heads/$LWT_DEFAULT_BRANCH"; then
    LWT_DEFAULT_BASE_REF="$LWT_DEFAULT_BRANCH"
  else
    LWT_DEFAULT_BASE_REF="HEAD"
  fi
}

lwt::git::fetch_if_stale() {
  local git_dir threshold_sec="${1:-60}"
  git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return 0

  local fetch_head="$git_dir/FETCH_HEAD"
  if [[ -f "$fetch_head" ]]; then
    local now last_fetch age
    now=$(date +%s)
    last_fetch=$(stat -f %m "$fetch_head" 2>/dev/null) || last_fetch=0
    age=$(( now - last_fetch ))
    (( age < threshold_sec )) && return 0
  fi

  git fetch --all --quiet 2>/dev/null
}
