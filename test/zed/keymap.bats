#!/usr/bin/env bats

load ../test_helper

@test "zed:keymap:path prints Zed keymap path" {
  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:path
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/zed-config/keymap.json" ]
}

@test "zed:keymap:bind-task creates keymap.json" {
  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:bind-task \
    --keystroke cmd-shift-d \
    --task "comments: dispatch current file"
  [ "$status" -eq 0 ]

  keymap="$BATS_TEST_TMPDIR/zed-config/keymap.json"
  [ -f "$keymap" ]
  [ "$(jq -r '.[0].context' "$keymap")" = "Workspace" ]
  [ "$(jq -r '.[0].bindings["cmd-shift-d"][0]' "$keymap")" = "task::Spawn" ]
  [ "$(jq -r '.[0].bindings["cmd-shift-d"][1].task_name' "$keymap")" = "comments: dispatch current file" ]
}

@test "zed:keymap:bind-rerun creates reevaluating rerun binding" {
  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:bind-rerun \
    --keystroke cmd-shift-r
  [ "$status" -eq 0 ]

  keymap="$BATS_TEST_TMPDIR/zed-config/keymap.json"
  [ "$(jq -r '.[0].bindings["cmd-shift-r"][0]' "$keymap")" = "task::Rerun" ]
  [ "$(jq -r '.[0].bindings["cmd-shift-r"][1].reevaluate_context' "$keymap")" = "true" ]
}

@test "zed:keymap bindings preserve existing workspace bindings" {
  mkdir -p "$BATS_TEST_TMPDIR/zed-config"
  cat > "$BATS_TEST_TMPDIR/zed-config/keymap.json" <<'JSON'
[
  {
    "context": "Workspace",
    "bindings": {
      "cmd-k": "workspace::Open"
    }
  }
]
JSON

  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:bind-task \
    --keystroke cmd-shift-d \
    --task "comments: dispatch current file"
  [ "$status" -eq 0 ]

  keymap="$BATS_TEST_TMPDIR/zed-config/keymap.json"
  [ "$(jq -r '.[0].bindings["cmd-k"]' "$keymap")" = "workspace::Open" ]
  [ "$(jq -r '.[0].bindings["cmd-shift-d"][1].task_name' "$keymap")" = "comments: dispatch current file" ]
}

@test "zed:keymap bindings append workspace context when absent" {
  mkdir -p "$BATS_TEST_TMPDIR/zed-config"
  cat > "$BATS_TEST_TMPDIR/zed-config/keymap.json" <<'JSON'
[
  {
    "context": "Editor",
    "bindings": {
      "cmd-k": "editor::SomeAction"
    }
  }
]
JSON

  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:bind-task \
    --keystroke cmd-shift-d \
    --task "comments: dispatch current file"
  [ "$status" -eq 0 ]

  keymap="$BATS_TEST_TMPDIR/zed-config/keymap.json"
  [ "$(jq 'length' "$keymap")" = "2" ]
  [ "$(jq -r '.[1].context' "$keymap")" = "Workspace" ]
}

@test "zed:keymap bindings are idempotent" {
  for _ in 1 2; do
    ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" ctl zed:keymap:bind-task \
      --keystroke cmd-shift-d \
      --task "comments: dispatch current file" >/dev/null
  done

  keymap="$BATS_TEST_TMPDIR/zed-config/keymap.json"
  [ "$(jq 'length' "$keymap")" = "1" ]
  [ "$(jq '.[0].bindings | keys | length' "$keymap")" = "1" ]
}

@test "zed:keymap binding refuses to clobber different existing binding" {
  mkdir -p "$BATS_TEST_TMPDIR/zed-config"
  cat > "$BATS_TEST_TMPDIR/zed-config/keymap.json" <<'JSON'
[
  {
    "context": "Workspace",
    "bindings": {
      "cmd-shift-d": "workspace::Open"
    }
  }
]
JSON

  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:bind-task \
    --keystroke cmd-shift-d \
    --task "comments: dispatch current file"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists with a different value"* ]]
  [ "$(jq -r '.[0].bindings["cmd-shift-d"]' "$BATS_TEST_TMPDIR/zed-config/keymap.json")" = "workspace::Open" ]
}

@test "zed:keymap binding --force replaces different existing binding" {
  mkdir -p "$BATS_TEST_TMPDIR/zed-config"
  cat > "$BATS_TEST_TMPDIR/zed-config/keymap.json" <<'JSON'
[
  {
    "context": "Workspace",
    "bindings": {
      "cmd-shift-d": "workspace::Open"
    }
  }
]
JSON

  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:bind-task \
    --keystroke cmd-shift-d \
    --task "comments: dispatch current file" \
    --force
  [ "$status" -eq 0 ]

  [ "$(jq -r '.[0].bindings["cmd-shift-d"][0]' "$BATS_TEST_TMPDIR/zed-config/keymap.json")" = "task::Spawn" ]
}

@test "zed:keymap operations fail without clobbering non-array keymap.json" {
  mkdir -p "$BATS_TEST_TMPDIR/zed-config"
  printf '{"bindings":{}}\n' > "$BATS_TEST_TMPDIR/zed-config/keymap.json"

  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:bind-task \
    --keystroke cmd-shift-d \
    --task "comments: dispatch current file"
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be a JSON array"* ]]
  [ "$(cat "$BATS_TEST_TMPDIR/zed-config/keymap.json")" = '{"bindings":{}}' ]
}

@test "zed:keymap:check-task succeeds when binding is absent" {
  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:check-task \
    --keystroke cmd-shift-d \
    --task "comments: dispatch current file"
  [ "$status" -eq 0 ]
  [[ "$output" == *"is available"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/zed-config/keymap.json" ]
}

@test "zed:keymap:check-task fails on conflicting binding without writing" {
  mkdir -p "$BATS_TEST_TMPDIR/zed-config"
  cat > "$BATS_TEST_TMPDIR/zed-config/keymap.json" <<'JSON'
[
  {
    "context": "Workspace",
    "bindings": {
      "cmd-shift-d": "workspace::Open"
    }
  }
]
JSON

  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:check-task \
    --keystroke cmd-shift-d \
    --task "comments: dispatch current file"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists with a different value"* ]]
  [ "$(jq -r '.[0].bindings["cmd-shift-d"]' "$BATS_TEST_TMPDIR/zed-config/keymap.json")" = "workspace::Open" ]
}

@test "zed:keymap:check-rerun succeeds for matching existing binding" {
  mkdir -p "$BATS_TEST_TMPDIR/zed-config"
  cat > "$BATS_TEST_TMPDIR/zed-config/keymap.json" <<'JSON'
[
  {
    "context": "Workspace",
    "bindings": {
      "cmd-shift-r": ["task::Rerun", {"reevaluate_context": true}]
    }
  }
]
JSON

  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:check-rerun \
    --keystroke cmd-shift-r
  [ "$status" -eq 0 ]
}

@test "zed:keymap:bind-snippet adds an inline snippet and preserves other contexts" {
  mkdir -p "$BATS_TEST_TMPDIR/zed-config"
  cat > "$BATS_TEST_TMPDIR/zed-config/keymap.json" <<'JSON'
[
  {
    "context": "Workspace",
    "bindings": {
      "cmd-shift-d": ["task::Spawn", {"task_name": "comments: dispatch current file"}]
    }
  }
]
JSON

  snippet='<!-- ! "@ikma ${1:feedback}" | mise comment -->$0'
  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:bind-snippet \
    --context 'Editor && extension == md' \
    --keystroke 'cmd-k i' \
    --snippet "$snippet"
  [ "$status" -eq 0 ]

  keymap="$BATS_TEST_TMPDIR/zed-config/keymap.json"
  [ "$(jq 'length' "$keymap")" = "2" ]
  [ "$(jq -r '.[0].bindings["cmd-shift-d"][0]' "$keymap")" = "task::Spawn" ]
  [ "$(jq -r '.[1].context' "$keymap")" = "Editor && extension == md" ]
  [ "$(jq -r '.[1].bindings["cmd-k i"][0]' "$keymap")" = "editor::InsertSnippet" ]
  [ "$(jq -r '.[1].bindings["cmd-k i"][1].snippet' "$keymap")" = "$snippet" ]
}

@test "zed:keymap:check-snippet accepts an identical binding without writing" {
  mkdir -p "$BATS_TEST_TMPDIR/zed-config"
  cat > "$BATS_TEST_TMPDIR/zed-config/keymap.json" <<'JSON'
[
  {
    "context": "Editor && extension == md",
    "bindings": {
      "cmd-k i": ["editor::InsertSnippet", {"snippet": "<!-- ! review -->$0"}]
    }
  }
]
JSON
  before="$(cat "$BATS_TEST_TMPDIR/zed-config/keymap.json")"

  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:check-snippet \
    --context 'Editor && extension == md' \
    --keystroke 'cmd-k i' \
    --snippet '<!-- ! review -->$0'
  [ "$status" -eq 0 ]
  [[ "$output" == *"is available"* ]]
  [ "$(cat "$BATS_TEST_TMPDIR/zed-config/keymap.json")" = "$before" ]
}

@test "zed:keymap:check-snippet rejects a conflicting binding without writing" {
  mkdir -p "$BATS_TEST_TMPDIR/zed-config"
  cat > "$BATS_TEST_TMPDIR/zed-config/keymap.json" <<'JSON'
[
  {
    "context": "Editor && extension == md",
    "bindings": {
      "cmd-k i": "editor::Format"
    }
  }
]
JSON
  before="$(cat "$BATS_TEST_TMPDIR/zed-config/keymap.json")"

  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:check-snippet \
    --context 'Editor && extension == md' \
    --keystroke 'cmd-k i' \
    --snippet '<!-- ! review -->$0'
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists with a different value"* ]]
  [ "$(cat "$BATS_TEST_TMPDIR/zed-config/keymap.json")" = "$before" ]
}

@test "zed:keymap:bind-snippet requires force to replace a conflicting binding" {
  mkdir -p "$BATS_TEST_TMPDIR/zed-config"
  cat > "$BATS_TEST_TMPDIR/zed-config/keymap.json" <<'JSON'
[
  {
    "context": "Editor && extension == md",
    "bindings": {
      "cmd-k i": "editor::Format"
    }
  }
]
JSON

  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:bind-snippet \
    --context 'Editor && extension == md' \
    --keystroke 'cmd-k i' \
    --snippet '<!-- ! review -->$0'
  [ "$status" -ne 0 ]
  [ "$(jq -r '.[0].bindings["cmd-k i"]' "$BATS_TEST_TMPDIR/zed-config/keymap.json")" = "editor::Format" ]

  ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" run ctl zed:keymap:bind-snippet \
    --context 'Editor && extension == md' \
    --keystroke 'cmd-k i' \
    --snippet '<!-- ! review -->$0' \
    --force
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0].bindings["cmd-k i"][0]' "$BATS_TEST_TMPDIR/zed-config/keymap.json")" = "editor::InsertSnippet" ]
}

@test "zed:keymap:bind-snippet is idempotent" {
  snippet='<!-- ! "@ikma ${1:feedback}" | mise comment -->$0'
  for _ in 1 2; do
    ZED_CONFIG_HOME="$BATS_TEST_TMPDIR/zed-config" ctl zed:keymap:bind-snippet \
      --context 'Editor && extension == md' \
      --keystroke 'cmd-k i' \
      --snippet "$snippet" >/dev/null
  done

  keymap="$BATS_TEST_TMPDIR/zed-config/keymap.json"
  [ "$(jq 'length' "$keymap")" = "1" ]
  [ "$(jq '.[0].bindings | keys | length' "$keymap")" = "1" ]
}
