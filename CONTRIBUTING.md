# Contributing

`ctl` is a KnickKnackLabs shiv package for small, boring integrations with external apps and tools.

The first supported surface is deliberately narrow: project-local Zed task JSON management under `ctl zed tasks ...`.

## Structure

```text
ctl/
├── mise.toml                    # Tools, settings, codebase lint config
├── README.tsx                   # Source for generated README.md
├── README.md                    # Generated; keep in sync with README.tsx
├── CONTRIBUTING.md              # Repo orientation surface
├── .mise/tasks/test             # Canonical BATS runner
├── .mise/tasks/doctor           # Local health checks + optional hook status
├── .mise/tasks/zed/tasks/*      # Zed tasks.json commands
├── .mise/tasks/zed/keymap/*     # Zed keymap.json commands
├── lib/zed/tasks.sh             # Shared Zed task JSON helpers
├── lib/zed/keymap.sh            # Shared Zed keymap JSON helpers
└── test/                        # BATS tests and helpers
```

## Local setup

```bash
mise trust
mise install
mise run test
mise run doctor
```

`doctor` reports whether the optional local `codebase pre-commit` hook is installed.
Install it in your clone when you want convention lints to run before every commit:

```bash
codebase pre-commit
```

The hook lives under `.git/hooks/`, so it is intentionally not tracked by the repo.

## CLI contract

The intended installed CLI shape is space-separated through shiv:

```bash
ctl zed tasks path
ctl zed tasks list
ctl zed tasks upsert --label "comments: dispatch current file" --command comments --arg dispatch --arg '$ZED_FILE'
ctl zed tasks remove --label "comments: dispatch current file"
```

When running inside this repo with mise, use the colon-delimited task names:

```bash
mise run zed:tasks:path
mise run zed:tasks:list
mise run zed:tasks:upsert --label "example" --command echo --arg hello
mise run zed:tasks:remove --label "example"
```

Tasks that resolve project-local paths read the package-scoped `CTL_CALLER_PWD` variable exported by shiv. Tests set that variable explicitly and call tasks through `mise run`.

## Scope guard

Do not build a general extension/plugin architecture yet. Add integrations only when a concrete external workflow needs a boring command surface.

For now, keep the scope to `.zed/tasks.json`:

- preserve existing tasks;
- upsert by `label`;
- remove by `label`;
- fail without clobbering if `tasks.json` is invalid or not a JSON array.

## README workflow

Edit `README.tsx`, then regenerate and check the output:

```bash
readme build
readme build --check
```

CI also checks that `README.md` matches `README.tsx`.

## Validation before merge or release

```bash
mise run test
mise run doctor
codebase lint "$PWD"
readme build --check
git diff --check
```
