#!/usr/bin/env bash
# Shared fixtures for ctl tests.

# Run a repo task through mise so tests exercise the real task path.
ctl() {
  cd "$REPO_DIR" && CTL_CALLER_PWD="${CTL_CALLER_PWD:-$PWD}" mise run -q "$@"
}
export -f ctl
