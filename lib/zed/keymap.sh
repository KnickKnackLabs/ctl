#!/usr/bin/env bash
# Shared helpers for Zed keymap.json management.

zed_config_dir() {
  local config_dir
  if [ -n "${ZED_CONFIG_HOME:-}" ]; then
    config_dir="$ZED_CONFIG_HOME"
  else
    config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
  fi

  printf '%s\n' "$config_dir"
}

zed_keymap_path() {
  printf '%s/keymap.json\n' "$(zed_config_dir)"
}

zed_keymap_validate_array() {
  local keymap_file="$1"

  [ -e "$keymap_file" ] || return 0

  if ! jq -e 'type == "array"' "$keymap_file" >/dev/null; then
    echo "ctl zed keymap: $keymap_file must be a JSON array" >&2
    return 1
  fi
}

zed_keymap_binding_exists_with_different_value() {
  local keymap_file="$1"
  local context="$2"
  local keystroke="$3"
  local binding_json="$4"

  [ -e "$keymap_file" ] || return 1

  jq -e \
    --arg context "$context" \
    --arg keystroke "$keystroke" \
    --argjson binding "$binding_json" \
    'any(.[]?; (.context == $context) and ((.bindings // {}) | has($keystroke)) and (.bindings[$keystroke] != $binding))' \
    "$keymap_file" >/dev/null
}

zed_keymap_check_binding_json() {
  local context="$1"
  local keystroke="$2"
  local binding_json="$3"
  local keymap_file

  keymap_file=$(zed_keymap_path)
  zed_keymap_validate_array "$keymap_file"

  if zed_keymap_binding_exists_with_different_value "$keymap_file" "$context" "$keystroke" "$binding_json"; then
    echo "ctl zed keymap: $context binding '$keystroke' already exists with a different value; rerun with --force to replace it" >&2
    return 1
  fi

  printf 'ctl zed keymap: %s binding %s is available\n' "$context" "$keystroke"
}

zed_keymap_upsert_binding_json() {
  local context="$1"
  local keystroke="$2"
  local binding_json="$3"
  local force="$4"
  local keymap_file keymap_dir tmp

  keymap_file=$(zed_keymap_path)
  keymap_dir=$(dirname "$keymap_file")
  mkdir -p "$keymap_dir"

  if [ "$force" != "true" ]; then
    zed_keymap_check_binding_json "$context" "$keystroke" "$binding_json" >/dev/null
  else
    zed_keymap_validate_array "$keymap_file"
  fi

  tmp=$(mktemp)
  if [ -e "$keymap_file" ]; then
    jq \
      --arg context "$context" \
      --arg keystroke "$keystroke" \
      --argjson binding "$binding_json" \
      'if any(.[]?; .context == $context) then
         map(if .context == $context then
           . + {bindings: ((.bindings // {}) + {($keystroke): $binding})}
         else
           .
         end)
       else
         . + [{context: $context, bindings: {($keystroke): $binding}}]
       end' "$keymap_file" > "$tmp"
  else
    jq -n \
      --arg context "$context" \
      --arg keystroke "$keystroke" \
      --argjson binding "$binding_json" \
      '[{context: $context, bindings: {($keystroke): $binding}}]' > "$tmp"
  fi

  mv "$tmp" "$keymap_file"
  printf 'ctl zed keymap: wrote %s\n' "$keymap_file"
}
