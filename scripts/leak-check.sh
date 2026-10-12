#!/usr/bin/env bash
# Fails when a generic file carries something personal: a home path, a session id,
# or a word from the local list (.leak-words, one per line, never committed).
# Usage: scripts/leak-check.sh [extra-words-file]
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 2

files="$(find . -type f \
  -not -path './.git/*' -not -path './.scratch/*' -not -path './tmp/*' -not -path './.omc/*' -not -path './.claude/worktrees/*' \
  -not -name '.leak-words' -not -name 'leak-check.sh' | sort)"

fail=0
check() { # check <label> <extended regex> [grep flags]
  local label="$1" rx="$2" flags="${3:-}" hits
  hits="$(printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 grep -nIE $flags -- "$rx" 2>/dev/null)"
  if [ -n "$hits" ]; then
    fail=1
    printf 'LEAK (%s):\n%s\n' "$label" "$(printf '%s\n' "$hits" | head -20)"
  fi
}

check "home path"        '/(Users|home)/[A-Za-z0-9._-]+/'
check "synced-folder path" 'Library/CloudStorage'
check "session id"       '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'

for list in "$root/.leak-words" "${1:-}"; do
  [ -n "$list" ] && [ -f "$list" ] || continue
  while IFS= read -r word; do
    case "$word" in ''|'#'*) continue ;; esac
    check "word: $word" "$word" "-i"
  done < "$list"
done

[ "$fail" -eq 0 ] && echo "leak check: clean"
exit "$fail"
