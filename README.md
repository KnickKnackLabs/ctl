<div align="center">

# ctl

**Small command-line control surfaces for app and editor integrations.**

Boring JSON surgery for tools that should not each own it.

![shape: mise + BATS](https://img.shields.io/badge/shape-mise%20%2B%20BATS-4EAA25?style=flat&logo=gnubash&logoColor=white)
[![tests: 23](https://img.shields.io/badge/tests-23-brightgreen?style=flat)](test/)
![lints: 9](https://img.shields.io/badge/lints-9-blue?style=flat)
![README: TSX](https://img.shields.io/badge/README-TSX-f472b6?style=flat)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat)](LICENSE)

</div>

<br />

## What this is

`ctl` is a shiv-installable CLI for app and editor integrations that need a small, reusable command surface. The first version manages project-local Zed tasks in `.zed/tasks.json`.

The immediate extraction target is `comments integrations zed`: it should not own generic Zed JSON upsert logic forever. `ctl zed tasks ...` gives that logic one home so other tools can reuse it.

This is intentionally not a plugin framework. Add the next app namespace only after a concrete workflow proves the shape.

## Install

```bash
shiv install ctl
```

## Zed tasks

```bash
# Print the caller project's Zed tasks file path.
ctl zed tasks path

# Print tasks as JSON. Missing file means [].
ctl zed tasks list

# Insert or replace one task by label.
ctl zed tasks upsert \
  --label "comments: dispatch current file" \
  --command comments \
  --arg dispatch \
  --arg '$ZED_FILE' \
  --save current \
  --hide on_success

# Remove tasks with a matching label.
ctl zed tasks remove --label "comments: dispatch current file"
```

All commands target the caller directory's `.zed/tasks.json`. Existing tasks are preserved. Upsert replaces tasks with the same `label` and appends when the label is new. Invalid JSON or a non-array tasks file fails without clobbering the file.

## Zed keymap

```bash
# Print the global Zed keymap file path.
ctl zed keymap path

# Check whether a binding can be installed without conflicts.
ctl zed keymap check-task   --keystroke cmd-shift-d   --task "comments: dispatch current file"

# Bind a key to spawn a named task.
ctl zed keymap bind-task   --keystroke cmd-shift-d   --task "comments: dispatch current file"

# Check/bind rerun with fresh Zed context.
ctl zed keymap check-rerun --keystroke cmd-shift-r
ctl zed keymap bind-rerun   --keystroke cmd-shift-r   --reevaluate-context
```

Keymap commands target Zed's global `keymap.json`. Existing bindings are preserved. If a requested keystroke already has a different binding in the target context, `ctl` fails without clobbering it unless `--force` is passed.

## Using from mise while developing

Shiv resolves space-separated commands to mise's colon-delimited task names. Inside this repo, call the tasks directly:

```bash
mise run zed:tasks:path
mise run zed:tasks:list
mise run zed:tasks:upsert --label example --command echo --arg hello
mise run zed:tasks:remove --label example
mise run zed:keymap:path
mise run zed:keymap:check-task --keystroke cmd-shift-d --task example
mise run zed:keymap:bind-task --keystroke cmd-shift-d --task example
mise run zed:keymap:check-rerun --keystroke cmd-shift-r
mise run zed:keymap:bind-rerun --keystroke cmd-shift-r
```

## Project-local path resolution

When installed by shiv, the shim exports `CTL_CALLER_PWD` before running the task. `ctl` uses that package-scoped variable to decide which project owns `.zed/tasks.json`. It does not read generic `CALLER_PWD`.

## Tasks

| Task                              | Description                                            |
| --------------------------------- | ------------------------------------------------------ |
| `mise run doctor`                 | Check local development setup                          |
| `mise run test`                   | Run BATS tests                                         |
| `mise run zed:keymap:bind-rerun`  | Bind a Zed key to rerun the last task                  |
| `mise run zed:keymap:bind-task`   | Bind a Zed key to spawn a named task                   |
| `mise run zed:keymap:check-rerun` | Check whether a Zed rerun key binding can be installed |
| `mise run zed:keymap:check-task`  | Check whether a Zed task key binding can be installed  |
| `mise run zed:keymap:path`        | Print the global Zed keymap.json path                  |
| `mise run zed:tasks:list`         | Print project-local Zed tasks as JSON                  |
| `mise run zed:tasks:path`         | Print the project-local Zed tasks.json path            |
| `mise run zed:tasks:remove`       | Remove a project-local Zed task by label               |
| `mise run zed:tasks:upsert`       | Insert or replace a project-local Zed task by label    |

## Repo inventory

| Path                         | Status | Purpose                                   |
| ---------------------------- | ------ | ----------------------------------------- |
| `mise.toml`                  | ✓      | tools, settings, and codebase lint config |
| `README.tsx`                 | ✓      | programmable README source                |
| `CONTRIBUTING.md`            | ✓      | repo-entry orientation surface            |
| `.mise/tasks/zed/tasks/`     | ✓      | Zed tasks.json commands                   |
| `.mise/tasks/zed/keymap/`    | ✓      | Zed keymap.json commands                  |
| `lib/zed/tasks.sh`           | ✓      | shared Zed task JSON helpers              |
| `lib/zed/keymap.sh`          | ✓      | shared Zed keymap JSON helpers            |
| `test/`                      | ✓      | BATS coverage through mise                |
| `.github/workflows/test.yml` | ✓      | Ubuntu/macOS CI                           |

<details>
<summary><b>Current convention checks</b></summary>

This repo asks [codebase](https://github.com/KnickKnackLabs/codebase) to run these lint rules:

```
mise-settings
bats-test-helper
bats-test-task
mcr-scope
or-true
shellcheck
gum-table
caller-pwd-contract
github-actions
```

</details>

## Validation

```bash
mise run test
mise run doctor
codebase lint "$PWD"
readme build --check
git diff --check
```

The suite currently has **23 tests** and **11 public tasks**. CI runs on **ubuntu-latest + macos-latest**.

<div align="center">

---

<sub>
This README was generated from `README.tsx` with [KnickKnackLabs/readme](https://github.com/KnickKnackLabs/readme).<br />Keep integrations boring until the second caller proves otherwise.
</sub></div>
