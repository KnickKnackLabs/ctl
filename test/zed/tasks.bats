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

@test "zed:tasks:upsert emits optional reveal shell and environment fields" {
  CTL_CALLER_PWD="$BATS_TEST_TMPDIR" run ctl zed:tasks:upsert \
    --label "comments: dispatch current file" \
    --command comments \
    --arg dispatch \
    --arg '$ZED_FILE' \
    --save current \
    --reveal never \
    --hide on_success \
    --shell-program /bin/zsh \
    --shell-arg=-f \
    --shell-arg=-l \
    --env COMMENT_CHAT_AS=or \
    --env 'GREETING=hello world'
  [ "$status" -eq 0 ]

  tasks="$BATS_TEST_TMPDIR/.zed/tasks.json"
  jq -e '.[0] == {
    "label": "comments: dispatch current file",
    "command": "comments",
    "args": ["dispatch", "$ZED_FILE"],
    "save": "current",
    "reveal": "never",
    "hide": "on_success",
    "shell": {"with_arguments": {"program": "/bin/zsh", "args": ["-f", "-l"]}},
    "env": {"COMMENT_CHAT_AS": "or", "GREETING": "hello world"}
  }' "$tasks"
}

@test "zed:tasks:upsert uses simple shell form and omits unused fields" {
  CTL_CALLER_PWD="$BATS_TEST_TMPDIR" run ctl zed:tasks:upsert \
    --label simple \
    --command true \
    --shell-program /bin/sh
  [ "$status" -eq 0 ]

  tasks="$BATS_TEST_TMPDIR/.zed/tasks.json"
  [ "$(jq -r '.[0].shell.program' "$tasks")" = "/bin/sh" ]
  [ "$(jq '.[0].args | length' "$tasks")" = "0" ]
  [ "$(jq '.[0] | has("reveal")' "$tasks")" = "false" ]
  [ "$(jq '.[0] | has("env")' "$tasks")" = "false" ]
}

@test "zed:tasks:upsert validates task policy enums before writing" {
  for specification in 'save=sometimes' 'reveal=on_success' 'hide=no_focus'; do
    field="${specification%%=*}"
    value="${specification#*=}"
    caller="$BATS_TEST_TMPDIR/$field"
    mkdir -p "$caller"

    run env CTL_CALLER_PWD="$caller" \
      mise -C "$REPO_DIR" run -q zed:tasks:upsert \
      --label invalid \
      --command true \
      "--$field" "$value"

    [ "$status" -ne 0 ]
    [[ "$output" == *"invalid $field value: $value"* ]]
    [ ! -e "$caller/.zed/tasks.json" ]
  done
}

@test "zed:tasks:upsert requires a shell program before shell arguments" {
  CTL_CALLER_PWD="$BATS_TEST_TMPDIR" run ctl zed:tasks:upsert \
    --label invalid \
    --command true \
    --shell-arg=-f

  [ "$status" -ne 0 ]
  [[ "$output" == *"--shell-arg requires --shell-program"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/.zed/tasks.json" ]
}

@test "zed:tasks:upsert validates environment entries before writing" {
  for entry in 'MISSING_EQUALS' 'BAD-NAME=value'; do
    caller="$BATS_TEST_TMPDIR/$(printf '%s' "$entry" | tr '=-' '__')"
    mkdir -p "$caller"

    CTL_CALLER_PWD="$caller" run ctl zed:tasks:upsert \
      --label invalid \
      --command true \
      --env "$entry"

    [ "$status" -ne 0 ]
    [ ! -e "$caller/.zed/tasks.json" ]
  done

  caller="$BATS_TEST_TMPDIR/duplicate"
  mkdir -p "$caller"
  CTL_CALLER_PWD="$caller" run ctl zed:tasks:upsert \
    --label invalid \
    --command true \
    --env NAME=one \
    --env NAME=two

  [ "$status" -ne 0 ]
  [[ "$output" == *"duplicate environment name: NAME"* ]]
  [ ! -e "$caller/.zed/tasks.json" ]
}

@test "zed:tasks:upsert replaces the whole environment for a matching label" {
  mkdir -p "$BATS_TEST_TMPDIR/.zed"
  cat > "$BATS_TEST_TMPDIR/.zed/tasks.json" <<'JSON'
[
  {
    "label": "review",
    "command": "old",
    "env": {"OLD": "value"}
  }
]
JSON

  CTL_CALLER_PWD="$BATS_TEST_TMPDIR" run ctl zed:tasks:upsert \
    --label review \
    --command comments \
    --env NEW=value
  [ "$status" -eq 0 ]

  tasks="$BATS_TEST_TMPDIR/.zed/tasks.json"
  [ "$(jq -r '.[0].env.NEW' "$tasks")" = "value" ]
  [ "$(jq '.[0].env | has("OLD")' "$tasks")" = "false" ]
}

@test "doctor reports optional pre-commit hook state" {
  run ctl doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"pre-commit"* ]]
}
