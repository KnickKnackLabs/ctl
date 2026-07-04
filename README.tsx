/** @jsxImportSource jsx-md */

import { existsSync, readFileSync, readdirSync, statSync } from "fs";
import { join, resolve } from "path";

import {
  Badge,
  Badges,
  Bold,
  Cell,
  Center,
  Code,
  CodeBlock,
  Details,
  HR,
  Heading,
  Item,
  LineBreak,
  Link,
  List,
  Paragraph,
  Raw,
  Section,
  Sub,
  Table,
  TableHead,
  TableRow,
} from "readme";

const PROJECT = {
  name: "ctl",
  oneLine: "Small command-line control surfaces for app and editor integrations.",
  tagline: "Boring JSON surgery for tools that should not each own it.",
  license: "MIT",
};

const REPO_DIR = resolve(import.meta.dirname);
const TASK_DIR = join(REPO_DIR, ".mise/tasks");
const TEST_DIR = join(REPO_DIR, "test");
const WORKFLOW = join(REPO_DIR, ".github/workflows/test.yml");

interface TaskInfo {
  name: string;
  description: string;
}

function read(path: string): string {
  return readFileSync(path, "utf8");
}

function walkFiles(dir: string, predicate: (path: string) => boolean): string[] {
  if (!existsSync(dir)) return [];

  const results: string[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkFiles(full, predicate));
    } else if (predicate(full)) {
      results.push(full);
    }
  }
  return results;
}

function discoverTasks(dir = TASK_DIR, prefix = ""): TaskInfo[] {
  if (!existsSync(dir)) return [];

  const tasks: TaskInfo[] = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith(".")) continue;
    const full = join(dir, entry.name);
    const name = prefix ? `${prefix}:${entry.name}` : entry.name;

    if (entry.isDirectory()) {
      tasks.push(...discoverTasks(full, name));
      continue;
    }

    const mode = statSync(full).mode;
    if ((mode & 0o111) === 0) continue;

    const src = read(full);
    const description = src.match(/^#MISE description="(.+)"$/m)?.[1] ?? "";
    tasks.push({ name, description });
  }

  return tasks.sort((a, b) => a.name.localeCompare(b.name));
}

function countBatsTests(): number {
  return walkFiles(TEST_DIR, (path) => path.endsWith(".bats"))
    .map(read)
    .join("\n")
    .match(/@test\s+"/g)?.length ?? 0;
}

function configuredLints(): string[] {
  const miseToml = read(join(REPO_DIR, "mise.toml"));
  const start = miseToml.indexOf("[_.codebase]");
  if (start === -1) return [];

  const lines = miseToml.slice(start).split("\n");
  const block: string[] = [];
  for (const [index, line] of lines.entries()) {
    if (index > 0 && line.startsWith("[")) break;
    block.push(line);
  }

  const list = block.join("\n").match(/lint\s*=\s*\[([\s\S]*?)\]/)?.[1] ?? "";
  return [...list.matchAll(/"([^"]+)"/g)].map((match) => match[1]);
}

function workflowOses(): string[] {
  if (!existsSync(WORKFLOW)) return [];
  const match = read(WORKFLOW).match(/os:\s*\[([^\]]+)\]/);
  if (!match) return [];
  return match[1].split(",").map((os) => os.trim()).filter(Boolean);
}

function status(path: string): string {
  return existsSync(join(REPO_DIR, path)) ? "✓" : "missing";
}

const tasks = discoverTasks();
const testCount = countBatsTests();
const lints = configuredLints();
const oses = workflowOses();

const inventory = [
  ["mise.toml", "tools, settings, and codebase lint config"],
  ["README.tsx", "programmable README source"],
  ["CONTRIBUTING.md", "repo-entry orientation surface"],
  [".mise/tasks/zed/tasks/", "Zed tasks.json commands"],
  ["lib/zed_tasks.sh", "shared Zed task JSON helpers"],
  ["test/", "BATS coverage through mise"],
  [".github/workflows/test.yml", "Ubuntu/macOS CI"],
];

const readme = (
  <>
    <Center>
      <Heading level={1}>{PROJECT.name}</Heading>

      <Paragraph>
        <Bold>{PROJECT.oneLine}</Bold>
      </Paragraph>

      <Paragraph>{PROJECT.tagline}</Paragraph>

      <Badges>
        <Badge label="shape" value="mise + BATS" color="4EAA25" logo="gnubash" logoColor="white" />
        <Badge label="tests" value={`${testCount}`} color="brightgreen" href="test/" />
        <Badge label="lints" value={`${lints.length}`} color="blue" />
        <Badge label="README" value="TSX" color="f472b6" />
        <Badge label="License" value={PROJECT.license} color="blue" href="LICENSE" />
      </Badges>
    </Center>

    <LineBreak />

    <Section title="What this is">
      <Paragraph>
        <Code>ctl</Code>
        {" is a shiv-installable CLI for app and editor integrations that need a small, reusable command surface. The first version manages project-local Zed tasks in "}
        <Code>.zed/tasks.json</Code>
        {"."}
      </Paragraph>

      <Paragraph>
        {"The immediate extraction target is "}
        <Code>comments integrations zed</Code>
        {": it should not own generic Zed JSON upsert logic forever. "}
        <Code>ctl zed tasks ...</Code>
        {" gives that logic one home so other tools can reuse it."}
      </Paragraph>

      <Paragraph>
        {"This is intentionally not a plugin framework. Add the next app namespace only after a concrete workflow proves the shape."}
      </Paragraph>
    </Section>

    <Section title="Install">
      <CodeBlock lang="bash">{`shiv install ctl`}</CodeBlock>
    </Section>

    <Section title="Zed tasks">
      <CodeBlock lang="bash">{`# Print the caller project's Zed tasks file path.
ctl zed tasks path

# Print tasks as JSON. Missing file means [].
ctl zed tasks list

# Insert or replace one task by label.
ctl zed tasks upsert \\
  --label "comments: dispatch current file" \\
  --command comments \\
  --arg dispatch \\
  --arg '$ZED_FILE' \\
  --save current \\
  --hide on_success

# Remove tasks with a matching label.
ctl zed tasks remove --label "comments: dispatch current file"`}</CodeBlock>

      <Paragraph>
        {"All commands target the caller directory's "}
        <Code>.zed/tasks.json</Code>
        {". Existing tasks are preserved. Upsert replaces tasks with the same "}
        <Code>label</Code>
        {" and appends when the label is new. Invalid JSON or a non-array tasks file fails without clobbering the file."}
      </Paragraph>
    </Section>

    <Section title="Using from mise while developing">
      <Paragraph>
        {"Shiv resolves space-separated commands to mise's colon-delimited task names. Inside this repo, call the tasks directly:"}
      </Paragraph>

      <CodeBlock lang="bash">{`mise run zed:tasks:path
mise run zed:tasks:list
mise run zed:tasks:upsert --label example --command echo --arg hello
mise run zed:tasks:remove --label example`}</CodeBlock>
    </Section>

    <Section title="Project-local path resolution">
      <Paragraph>
        {"When installed by shiv, the shim exports "}
        <Code>CTL_CALLER_PWD</Code>
        {" before running the task. "}
        <Code>ctl</Code>
        {" uses that package-scoped variable to decide which project owns "}
        <Code>.zed/tasks.json</Code>
        {". It does not read generic "}
        <Code>CALLER_PWD</Code>
        {"."}
      </Paragraph>
    </Section>

    <Section title="Tasks">
      <Table>
        <TableHead>
          <Cell>Task</Cell>
          <Cell>Description</Cell>
        </TableHead>
        {tasks.map((task) => (
          <TableRow>
            <Cell><Code>{`mise run ${task.name}`}</Code></Cell>
            <Cell>{task.description}</Cell>
          </TableRow>
        ))}
      </Table>
    </Section>

    <Section title="Repo inventory">
      <Table>
        <TableHead>
          <Cell>Path</Cell>
          <Cell>Status</Cell>
          <Cell>Purpose</Cell>
        </TableHead>
        {inventory.map(([path, purpose]) => (
          <TableRow>
            <Cell><Code>{path}</Code></Cell>
            <Cell>{status(path)}</Cell>
            <Cell>{purpose}</Cell>
          </TableRow>
        ))}
      </Table>
    </Section>

    <Details summary="Current convention checks">
      <Paragraph>
        {"This repo asks "}
        <Link href="https://github.com/KnickKnackLabs/codebase">codebase</Link>
        {" to run these lint rules:"}
      </Paragraph>
      <CodeBlock>{lints.join("\n")}</CodeBlock>
    </Details>

    <Section title="Validation">
      <CodeBlock lang="bash">{`mise run test
mise run doctor
codebase lint "$PWD"
readme build --check
git diff --check`}</CodeBlock>

      <Paragraph>
        {"The suite currently has "}
        <Bold>{`${testCount} tests`}</Bold>
        {" and "}
        <Bold>{`${tasks.length} public tasks`}</Bold>
        {". CI runs on "}
        <Bold>{oses.join(" + ") || "configured platforms"}</Bold>
        {"."}
      </Paragraph>
    </Section>

    <Center>
      <HR />
      <Sub>
        {"This README was generated from "}
        <Code>README.tsx</Code>
        {" with "}
        <Link href="https://github.com/KnickKnackLabs/readme">KnickKnackLabs/readme</Link>
        {"."}
        <Raw>{"<br />"}</Raw>
        {"Keep integrations boring until the second caller proves otherwise."}
      </Sub>
    </Center>
  </>
);

console.log(readme);
