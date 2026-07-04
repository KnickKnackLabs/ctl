#!/usr/bin/env bash
# Shared helpers for Zed tasks.json management.

ctl_caller_dir() {
  local caller resolved
  caller="${CTL_CALLER_PWD:-${MISE_ORIGINAL_CWD:-$PWD}}"

  if ! resolved=$(cd "$caller" && pwd -P); then
    echo "ctl: caller directory not found: $caller" >&2
    return 1
  fi

  printf '%s\n' "$resolved"
}

zed_tasks_path() {
  local caller
  caller=$(ctl_caller_dir)
  printf '%s/.zed/tasks.json\n' "$caller"
}

zed_tasks_validate_array() {
  local tasks_file="$1"

  [ -e "$tasks_file" ] || return 0

  if ! jq -e 'type == "array"' "$tasks_file" >/dev/null; then
    echo "ctl zed tasks: $tasks_file must be a JSON array" >&2
    return 1
  fi
}

zed_tasks_list_json() {
  local tasks_file
  tasks_file=$(zed_tasks_path)

  if [ ! -e "$tasks_file" ]; then
    printf '[]\n'
    return 0
  fi

  zed_tasks_validate_array "$tasks_file"
  jq '.' "$tasks_file"
}

zed_tasks_upsert_json() {
  local task_json="$1"
  local tasks_file zed_dir tmp

  tasks_file=$(zed_tasks_path)
  zed_dir=$(dirname "$tasks_file")
  mkdir -p "$zed_dir"

  zed_tasks_validate_array "$tasks_file"

  tmp=$(mktemp)
  if [ -e "$tasks_file" ]; then
    jq --argjson task "$task_json" '
      if any(.[]?; .label == $task.label) then
        map(if .label == $task.label then $task else . end)
      else
        . + [$task]
      end
    ' "$tasks_file" > "$tmp"
  else
    jq -n --argjson task "$task_json" '[$task]' > "$tmp"
  fi

  mv "$tmp" "$tasks_file"
  printf 'ctl zed tasks upsert: wrote %s\n' "$tasks_file"
}

zed_tasks_remove_label() {
  local label="$1"
  local tasks_file tmp

  tasks_file=$(zed_tasks_path)
  if [ ! -e "$tasks_file" ]; then
    printf 'ctl zed tasks remove: no tasks file at %s\n' "$tasks_file"
    return 0
  fi

  zed_tasks_validate_array "$tasks_file"

  tmp=$(mktemp)
  jq --arg label "$label" 'map(select(.label != $label))' "$tasks_file" > "$tmp"
  mv "$tmp" "$tasks_file"
  printf 'ctl zed tasks remove: wrote %s\n' "$tasks_file"
}
