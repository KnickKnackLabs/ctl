#!/usr/bin/env bash
# Shared fixtures for ctl tests.

if [ -z "${REPO_DIR:-}" ]; then
  TEST_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_DIR="$(cd "$TEST_HELPER_DIR/.." && pwd)"
  export REPO_DIR

  bats_libexec="${BATS_LIBEXEC:-}"
  eval "$(cd "$REPO_DIR" && mise env)"
  if [ -n "$bats_libexec" ]; then
    export PATH="$bats_libexec:$PATH"
  fi
fi

# Run a repo task through mise so tests exercise the real task path.
ctl() {
  cd "$REPO_DIR" && CTL_CALLER_PWD="${CTL_CALLER_PWD:-$PWD}" mise run -q "$@"
}
export -f ctl
