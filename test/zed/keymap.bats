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
