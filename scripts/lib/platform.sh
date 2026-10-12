#!/usr/bin/env bash
# platform.sh - what differs between systems: path forms, links, and how awk reads line endings.

# Return 0 when the helper runs in Git Bash on Windows.
sb_is_windows() {
  case "${OSTYPE:-}" in msys* | cygwin*) return 0 ;; esac
  return 1
}

# Print an absolute path that was read, in the shell's own form: on Windows C:\a and C:/a become /c/a.
sb_path_in() {
  local p="$1" d before upper="ABCDEFGHIJKLMNOPQRSTUVWXYZ" lower="abcdefghijklmnopqrstuvwxyz"
  if sb_is_windows; then
    p="${p//\\//}"
    case "$p" in [A-Za-z]:/* | [A-Za-z]:) p="/${p:0:1}${p:2}" ;; esac
    case "$p" in
      /[A-Za-z]/* | /[A-Za-z])
        d="${p:1:1}"
        before="${upper%%"$d"*}"
        [ "${#before}" -eq 26 ] || p="/${lower:${#before}:1}${p:2}"
        ;;
    esac
  fi
  printf '%s\n' "$p"
}

# Print an absolute path in the form the helper shows: on Windows the drive form, C:/a.
sb_path_out() {
  local p="$1" d before upper="ABCDEFGHIJKLMNOPQRSTUVWXYZ" lower="abcdefghijklmnopqrstuvwxyz"
  if sb_is_windows; then
    case "$p" in
      /[A-Za-z]/* | /[A-Za-z])
        d="${p:1:1}"
        before="${lower%%"$d"*}"
        [ "${#before}" -eq 26 ] || d="${upper:${#before}:1}"
        p="$d:${p:2}"
        [ "${#p}" -gt 2 ] || p="$p/"
        ;;
      /*) p="$(cygpath -m "$p")" || return 1 ;;
    esac
  fi
  printf '%s\n' "$p"
}

# Create one link at the second path that leads to the first: a symlink, or on Windows a junction
# to a folder. Return 1 when it cannot.
sb_mklink() {
  local to at
  if ! sb_is_windows; then
    ln -s "$1" "$2"
    return $?
  fi
  [ -d "$1" ] || return 1
  to="$(sb_path_out "$1")" && at="$(sb_path_out "$2")" || return 1
  # cmd takes the two paths and the quotes around them from its environment: a path given as an
  # argument is cut at an ampersand, and a quote given there reaches mklink with a backslash.
  SB_PLAT_Q='"' SB_PLAT_AT="${at//\//\\}" SB_PLAT_TO="${to//\//\\}" \
    cmd //d //v:off //c 'mklink /J %SB_PLAT_Q%%SB_PLAT_AT%%SB_PLAT_Q% %SB_PLAT_Q%%SB_PLAT_TO%%SB_PLAT_Q%' >/dev/null || return 1
}

# Remove one link and never what it leads to; return 1 when the path is not a link.
sb_rmlink() {
  [ -L "$1" ] || return 1
  rm -f "$1"
}

# On Windows awk reads in text mode and drops the CR of every line; run it in binary mode there.
if sb_is_windows; then
  awk() { command awk -v BINMODE=3 "$@"; }
fi
