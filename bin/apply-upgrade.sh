#!/usr/bin/env bash
set -euo pipefail
#
# apply-upgrade.sh
# Utility to insert 'source ./bin/common.sh' into scripts and to replace direct 'docker exec mariadb' uses
#
# Usage:
#  bash bin/apply-upgrade.sh --preview   # show diffs but do not write
#  bash bin/apply-upgrade.sh             # apply in place (make backups via git)
#
PREVIEW=false
if [ "${1:-}" = "--preview" ]; then
  PREVIEW=true
fi

echo "Scanning bin/ and bin/container/ for .sh files..."
FILES=$(find bin -type f -name '*.sh' -o -path "bin/container/*" -print | sort -u)
if [ -z "$FILES" ]; then
  echo "No shell scripts found under bin/ to process."
  exit 0
fi

apply_patch_to_file() {
  file="$1"
  tmp="$(mktemp)"
  cp "$file" "$tmp"

  # Insert source common.sh after shebang if not present
  if ! grep -q "source ./bin/common.sh" "$tmp"; then
    if head -n1 "$tmp" | grep -q '^#!'; then
      ( head -n1 "$tmp" && echo "source ./bin/common.sh 2>/dev/null || source .env 2>/dev/null || true" && tail -n +2 "$tmp" ) > "${tmp}.new"
    else
      ( echo "source ./bin/common.sh 2>/dev/null || source .env 2>/dev/null || true" && cat "$tmp" ) > "${tmp}.new"
    fi
    mv "${tmp}.new" "$tmp"
  fi

  # Replace direct docker exec mariadb occurrences
  sed -i \
    -e 's/docker exec -i mariadb/${DOCKER_CMD} exec -i "${DB_CONTAINER}"/g' \
    -e 's/docker exec mariadb/${DOCKER_CMD} exec "${DB_CONTAINER}"/g' \
    -e 's/${DOCKER_CMD} exec mariadb/${DOCKER_CMD} exec "${DB_CONTAINER}"/g' \
    -e 's/${COMPOSE_CMD} exec mariadb/${COMPOSE_CMD} exec ${DB_CONTAINER}/g' \
    "$tmp"

  if [ "$PREVIEW" = true ]; then
    echo "==== Preview: $file ===="
    git --no-pager diff --no-index -- "$file" "$tmp" || true
    rm -f "$tmp"
  else
    mv "$tmp" "$file"
    chmod +x "$file"
    echo "Patched: $file"
  fi
}

for f in $FILES; do
  apply_patch_to_file "$f"
done

echo "Done. If you ran without --preview, review changes with git diff, then commit and push."
