#!/bin/sh
# Refuse to commit a transcript that carries a key, a token, or a host that is not the lab's.
# Usage: lab/check_secrets.sh [files...]   (default: every file under lab/agent-runs/)
# Exit 1 on any hit. Patterns are deliberately broad; a false positive costs a minute, a leak does not.
set -u
cd "$(dirname "$0")/.." || exit 2
files="$*"
[ -z "$files" ] && files=$(find lab/agent-runs -type f -name '*.md' ! -name README.md 2>/dev/null)
[ -z "$files" ] && { echo "check_secrets: nothing to check"; exit 0; }

pat='sk-ant-[A-Za-z0-9_-]{8,}|sk-proj-[A-Za-z0-9_-]{8,}|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{20,}|ghp_[A-Za-z0-9]{20,}|xox[bpa]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|Bearer [A-Za-z0-9._-]{16,}|x-api-key: *[A-Za-z0-9_-]{8,}|[a-z0-9-]+\.ts\.net|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|192\.168\.[0-9]+\.[0-9]+'
rc=0
for f in $files; do
  if grep -nE "$pat" "$f" >/dev/null 2>&1; then
    echo "check_secrets: REFUSED $f"
    grep -nE "$pat" "$f" | sed 's/^/    /' | cut -c1-120
    rc=1
  fi
done
[ $rc -eq 0 ] && echo "check_secrets: clean ($(echo $files | wc -w | tr -d ' ') file(s))"
exit $rc
