#!/usr/bin/env bash
# obsidian.sh - the Obsidian CLI wrapper: find the binary, guard every call with a time limit.

# Print the Obsidian CLI binary, or return 1. SECOND_BRAIN_OBSIDIAN overrides it; "none" disables it.
sb_ob_bin() {
  local b="${SECOND_BRAIN_OBSIDIAN:-}"
  if [ -n "$b" ]; then
    if [ "$b" != "none" ] && [ -x "$b" ]; then
      printf '%s\n' "$b"
      return 0
    fi
    return 1
  fi
  b="$(command -v obsidian 2>/dev/null)"
  if [ -n "$b" ]; then
    printf '%s\n' "$b"
    return 0
  fi
  b="/Applications/Obsidian.app/Contents/MacOS/Obsidian"
  if [ -x "$b" ]; then
    printf '%s\n' "$b"
    return 0
  fi
  return 1
}

# Run a command with a time limit in seconds.
sb_timeout() {
  local secs="$1"
  shift
  if command -v perl >/dev/null 2>&1; then
    perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
  elif command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  else
    "$@"
  fi
}

# Run the CLI without the availability check; drop its startup lines. Returns 3 on no answer.
sb_ob_raw() {
  local bin out rc
  bin="$(sb_ob_bin)" || return 3
  if [ -n "${SB_OB_VAULT_ARG:-}" ]; then
    out="$(sb_timeout "${SB_OB_SECS:-${SECOND_BRAIN_OB_TIMEOUT:-20}}" "$bin" "$SB_OB_VAULT_ARG" "$@" 2>/dev/null </dev/null)"
  else
    out="$(sb_timeout "${SB_OB_SECS:-${SECOND_BRAIN_OB_TIMEOUT:-20}}" "$bin" "$@" 2>/dev/null </dev/null)"
  fi
  rc=$?
  case "$rc" in 124 | 137 | 142) return 3 ;; esac
  [ -n "$out" ] || return 0
  printf '%s\n' "$out" | grep -v -e 'Loaded main app package' -e 'Loaded updated app' -e '^Your Obsidian installer is out of date'
  return 0
}

# Return 0 when two paths are the same folder.
sb_same_dir() {
  [ -n "$1" ] && [ -d "$1" ] && [ "$(cd -P "$1" 2>/dev/null && pwd -P)" = "$2" ]
}

# Return 0 when the CLI answers for this vault; sets SB_OB_STATE to up, down or missing.
sb_ob_up() {
  case "${SB_OB_STATE:-}" in
    up) return 0 ;;
    down | missing) return 1 ;;
  esac
  local root got secs=6
  SB_OB_STATE=missing
  SB_OB_VAULT_ARG=""
  sb_ob_bin >/dev/null || return 1
  SB_OB_STATE=down
  root="$(sb_root 2>/dev/null)" || return 1
  # The CLI binary is the app itself: skip the call when no app process is running.
  if [ -z "${SECOND_BRAIN_OBSIDIAN:-}" ] && command -v pgrep >/dev/null 2>&1; then
    pgrep -xi obsidian >/dev/null 2>&1 || return 1
  fi
  case "${SECOND_BRAIN_OB_TIMEOUT:-}" in [1-5]) secs="$SECOND_BRAIN_OB_TIMEOUT" ;; esac
  got="$(SB_OB_SECS="$secs" sb_ob_raw vault info=path)" || return 1
  if sb_same_dir "$(printf '%s\n' "$got" | head -1)" "$root"; then
    SB_OB_STATE=up
    return 0
  fi
  # Another vault is in front: ask for this one by its folder name.
  SB_OB_VAULT_ARG="vault=$(basename "$root")"
  got="$(SB_OB_SECS="$secs" sb_ob_raw vault info=path)" || got=""
  if sb_same_dir "$(printf '%s\n' "$got" | head -1)" "$root"; then
    SB_OB_STATE=up
    return 0
  fi
  SB_OB_VAULT_ARG=""
  return 1
}

# Run the Obsidian CLI against this vault; return 3 when it is unavailable.
sb_ob() {
  sb_ob_up || return 3
  sb_ob_raw "$@"
}

# Pass arguments straight to the Obsidian CLI.
cmd_ob() {
  [ $# -gt 0 ] || sb_die 5 "usage: second-brain ob <obsidian cli args>"
  sb_need_root
  if ! sb_ob_up; then
    if [ "$SB_OB_STATE" = "missing" ]; then
      sb_die 3 "the Obsidian CLI was not found (obsidian on PATH, or the app bundle on macOS)"
    fi
    sb_die 3 "Obsidian is not running, or it does not have this vault open"
  fi
  SB_OB_SECS="${SECOND_BRAIN_OB_TIMEOUT:-60}" sb_ob_raw "$@" || sb_die 3 "the Obsidian CLI did not answer in time"
}
