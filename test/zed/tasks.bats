#!/usr/bin/env bats

load ../test_helper

@test "zed:tasks:path prints caller-local tasks.json path" {
  expected="$(cd "$BATS_TEST_TMPDIR" && pwd -P)/.zed/tasks.json"

  CTL_CALLER_PWD="$BATS_TEST_TMPDIR" run ctl zed:tasks:path
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

@test "zed:tasks:list prints empty array when tasks.json is absent" {
  CTL_CALLER_PWD="$BATS_TEST_TMPDIR" run ctl zed:tasks:list
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "zed:tasks:upsert creates .zed/tasks.json in caller directory" {
  CTL_CALLER_PWD="$BATS_TEST_TMPDIR" run ctl zed:tasks:upsert \
    --label "comments: dispatch current file" \
    --command comments \
    --arg dispatch \
    --arg '$ZED_FILE' \
    --save current \
    --hide on_success
  [ "$status" -eq 0 ]
  [[ "$output" == *".zed/tasks.json"* ]]

  tasks="$BATS_TEST_TMPDIR/.zed/tasks.json"
  [ -f "$tasks" ]
  [ "$(jq 'length' "$tasks")" = "1" ]
  [ "$(jq -r '.[0].label' "$tasks")" = "comments: dispatch current file" ]
  [ "$(jq -r '.[0].command' "$tasks")" = "comments" ]
  [ "$(jq -r '.[0].args[0]' "$tasks")" = "dispatch" ]
  [ "$(jq -r '.[0].args[1]' "$tasks")" = '$ZED_FILE' ]
  [ "$(jq -r '.[0].save' "$tasks")" = "current" ]
  [ "$(jq -r '.[0].hide' "$tasks")" = "on_success" ]
}

@test "zed:tasks:upsert appends to existing tasks" {
  mkdir -p "$BATS_TEST_TMPDIR/.zed"
  cat > "$BATS_TEST_TMPDIR/.zed/tasks.json" <<'JSON'
[
  {
    "label": "existing task",
    "command": "echo",
    "args": ["hello"]
  }
]
JSON

  CTL_CALLER_PWD="$BATS_TEST_TMPDIR" run ctl zed:tasks:upsert \
    --label "comments: dispatch current file" \
    --command comments \
    --arg dispatch
  [ "$status" -eq 0 ]

  tasks="$BATS_TEST_TMPDIR/.zed/tasks.json"
  [ "$(jq 'length' "$tasks")" = "2" ]
  [ "$(jq -r '.[0].label' "$tasks")" = "existing task" ]
  [ "$(jq -r '.[1].label' "$tasks")" = "comments: dispatch current file" ]
}

@test "zed:tasks:upsert replaces an existing task with the same label" {
  mkdir -p "$BATS_TEST_TMPDIR/.zed"
  cat > "$BATS_TEST_TMPDIR/.zed/tasks.json" <<'JSON'
[
  {
    "label": "comments: dispatch current file",
    "command": "old-comments",
    "args": ["old"]
  }
]
JSON

  CTL_CALLER_PWD="$BATS_TEST_TMPDIR" run ctl zed:tasks:upsert \
    --label "comments: dispatch current file" \
    --command comments \
    --arg dispatch
  [ "$status" -eq 0 ]

  tasks="$BATS_TEST_TMPDIR/.zed/tasks.json"
  [ "$(jq 'length' "$tasks")" = "1" ]
  [ "$(jq -r '.[0].command' "$tasks")" = "comments" ]
  [ "$(jq -r '.[0].args[0]' "$tasks")" = "dispatch" ]
}

@test "zed:tasks:upsert is idempotent" {
  for _ in 1 2; do
    CTL_CALLER_PWD="$BATS_TEST_TMPDIR" ctl zed:tasks:upsert \
      --label "comments: dispatch current file" \
      --command comments \
      --arg dispatch \
      --arg '$ZED_FILE' >/dev/null
  done

  tasks="$BATS_TEST_TMPDIR/.zed/tasks.json"
  [ "$(jq 'length' "$tasks")" = "1" ]
  [ "$(jq -r '.[0].args[1]' "$tasks")" = '$ZED_FILE' ]
}

@test "zed:tasks:list prints existing tasks" {
  mkdir -p "$BATS_TEST_TMPDIR/.zed"
  cat > "$BATS_TEST_TMPDIR/.zed/tasks.json" <<'JSON'
[
  {
    "label": "existing task",
    "command": "echo"
  }
]
JSON

  CTL_CALLER_PWD="$BATS_TEST_TMPDIR" run ctl zed:tasks:list
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | jq -r '.[0].label')" = "existing task" ]
}

@test "zed:tasks:remove removes a matching task" {
  mkdir -p "$BATS_TEST_TMPDIR/.zed"
  cat > "$BATS_TEST_TMPDIR/.zed/tasks.json" <<'JSON'
[
  {"label": "keep", "command": "echo"},
  {"label": "remove", "command": "false"}
]
JSON

  CTL_CALLER_PWD="$BATS_TEST_TMPDIR" run ctl zed:tasks:remove --label remove
  [ "$status" -eq 0 ]

  tasks="$BATS_TEST_TMPDIR/.zed/tasks.json"
  [ "$(jq 'length' "$tasks")" = "1" ]
  [ "$(jq -r '.[0].label' "$tasks")" = "keep" ]
}

@test "zed:tasks:remove succeeds when tasks.json is absent" {
  CTL_CALLER_PWD="$BATS_TEST_TMPDIR" run ctl zed:tasks:remove --label missing
  [ "$status" -eq 0 ]
  [[ "$output" == *"no tasks file"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/.zed/tasks.json" ]
}

@test "zed:tasks operations fail without clobbering non-array tasks.json" {
  mkdir -p "$BATS_TEST_TMPDIR/.zed"
  printf '{"label":"not an array"}\n' > "$BATS_TEST_TMPDIR/.zed/tasks.json"

  CTL_CALLER_PWD="$BATS_TEST_TMPDIR" run ctl zed:tasks:upsert \
    --label "comments: dispatch current file" \
    --command comments
  [ "$status" -ne 0 ]
  [[ "$output" == *"must be a JSON array"* ]]
  [ "$(cat "$BATS_TEST_TMPDIR/.zed/tasks.json")" = '{"label":"not an array"}' ]
}

@test "doctor reports optional pre-commit hook state" {
  run ctl doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"pre-commit"* ]]
}
