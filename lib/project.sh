lwt::project::package_manager() {
  if [[ -f "pnpm-lock.yaml" ]]; then
    printf 'pnpm\n'
  elif [[ -f "bun.lockb" || -f "bun.lock" ]]; then
    printf 'bun\n'
  elif [[ -f "yarn.lock" ]]; then
    printf 'yarn\n'
  elif [[ -f "package-lock.json" ]]; then
    printf 'npm\n'
  else
    return 1
  fi
}

lwt::project::run_script_command() {
  local script="$1"
  local package_manager

  package_manager=$(lwt::project::package_manager) || return 1
  printf '%s run %s\n' "$package_manager" "$script"
}

lwt::project::has_script() {
  local script="$1"
  [[ -f "package.json" ]] || return 1

  if lwt::deps::has node; then
    node -e 'const fs=require("fs"); const script=process.argv[1]; const pkg=JSON.parse(fs.readFileSync("package.json","utf8")); const value=pkg?.scripts?.[script]; process.exit(typeof value==="string" && value.trim() ? 0 : 1)' "$script" >/dev/null 2>&1
    return $?
  fi

  if lwt::deps::has bun; then
    bun -e 'const script=process.argv[1]; const pkg=JSON.parse(await Bun.file("package.json").text()); const value=pkg?.scripts?.[script]; process.exit(typeof value==="string" && value.trim() ? 0 : 1)' "$script" >/dev/null 2>&1
    return $?
  fi

  if lwt::deps::has python3; then
    python3 - "$script" >/dev/null 2>&1 <<'PY'
import json
import sys

script = sys.argv[1]
with open("package.json", "r", encoding="utf-8") as handle:
    pkg = json.load(handle)

value = pkg.get("scripts", {}).get(script)
raise SystemExit(0 if isinstance(value, str) and value.strip() else 1)
PY
    return $?
  fi

  return 1
}

lwt::project::dev_command() {
  local configured

  configured=$(lwt::config::get_raw "dev-cmd" 2>/dev/null)
  if [[ -n "$configured" && "$configured" != "auto" ]]; then
    printf '%s\n' "$configured"
    return 0
  fi

  if lwt::project::has_script "dev"; then
    lwt::project::run_script_command "dev"
    return $?
  fi

  return 1
}

lwt::utils::install_dependencies() {
  local package_manager

  package_manager=$(lwt::project::package_manager) || return 0
  lwt::ui::step "Installing dependencies..."

  if [[ "$package_manager" == "pnpm" ]]; then
    pnpm install
  elif [[ "$package_manager" == "bun" ]]; then
    bun install
  elif [[ "$package_manager" == "yarn" ]]; then
    yarn install
  else
    npm install
  fi
}
