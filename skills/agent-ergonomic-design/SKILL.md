---
name: agent-ergonomic-design
description: Design CLIs, APIs, and tools optimized for AI agent consumption. Use when
  building tools that agents will call, adding robot/machine mode to CLIs, designing
  MCP tools, retrofitting an existing CLI for agent use, or when the user mentions
  "agent-friendly", "machine-readable output", "robot mode", "AXI", "TOON", or wants
  to make a tool work well with AI coding agents.
license: MIT
effort: medium
allowed-tools: Read Write Edit Bash Grep Glob
metadata:
  based-on: "AXI (Agent eXperience Interface) by Kun Chen"
  upstream: "https://github.com/kunchenguid/axi"
  local-modifications: "AXI 10-principle audit 2026-05-03: TOON, aggregates, empty states, ambient context, content-first output, contextual disclosure"
---

# /agent-ergonomic-design

Design and implement interfaces optimized for AI agent consumption. Built on the 10 AXI principles.

## Core Principle

Design test: "Can an agent reliably parse this, branch on failures, and stay within context limits?"

Token budget is a first-class constraint. Every field, every line, every help message has a token cost — multiplied across the agent's entire session.

## Design Checklist

### 1. Token-Efficient Output (TOON)

Use [TOON](https://toonformat.dev/) (Token-Oriented Object Notation) as the default output format. ~40% token savings over equivalent JSON.

```
tasks[2]{id,title,status,assignee}:
  "1",Fix auth bug,open,alice
  "2",Add pagination,closed,bob
```

- Convert to TOON at the output boundary; keep internal logic on JSON
- Provide `--json` as a fallback for legacy consumers and `--ndjson` for streams
- Auto-detect TTY: pretty tables for humans when interactive, TOON when piped
- Resolution order: `--toon` / `--json` flag > `OUTPUT_FORMAT` env > TTY detection
- Treat output schemas as **stable API contracts** — breaking changes break all downstream automation

### 2. Minimal Default Schemas

Every field costs tokens, multiplied by row count. Default to the smallest schema that lets the agent decide what to do next.

- **3-4 fields per list item**, not 10. Typically: identifier, title, status
- Long-form content (bodies, descriptions) belongs in detail views, not lists
- Default limits high enough to cover common cases in one call (most repos have <100 labels → default to 100, not 30)
- Offer `--fields name,id,assignee,labels` to request additional fields explicitly

### 3. Content Truncation

Never omit large fields entirely — include a truncated preview with size hints and an escape hatch.

```
task:
  number: 42
  title: Fix auth bug
  state: open
  body: First 500 chars of the issue body...
    ... (truncated, 8432 chars total)
help[1]: Run `tasks view 42 --full` to see complete body
```

- Show total size so the agent knows how much it's missing
- Suggest `--full` only when content was actually truncated
- Truncation limit: 500-1500 chars covers most use cases

### 4. Pre-Computed Aggregates

Eliminate follow-up calls by computing values the agent commonly needs as a next step.

**Aggregate counts** in list output — total, not just page size:

```
count: 30 of 847 total
tasks[30]{number,title,state}:
  ...
```

**Derived status fields** when the next step almost always involves checking related state:

```
task:
  number: 42
  title: Deploy pipeline fix
  state: open
  checks: 3/3 passed
  comments: 7
```

Only include derived fields your backend can provide cheaply — a summary, not the full data.

### 5. Definitive Empty States

When the answer is "nothing", say so explicitly with context. Ambiguous empty output causes agents to re-run with different flags to verify.

```
$ tasks list --state closed
tasks: 0 closed tasks found in this repository
```

State the zero. Make it clear the command succeeded — the absence of results is the answer.

### 6. Structured Errors & Exit Codes

**Errors go to stdout in the same structured format as normal output.** Agents read stdout — not stderr. stderr is for diagnostics agents will not see.

```
error: --title is required
help: tasks create --title "..." [--body "..."]
```

- Validate required flags before calling any dependency
- Translate errors — extract actionable meaning, discard noise
- Never leak dependency names — suggestions reference your CLI's commands, not the underlying tool
- Include a `suggestions` field where agents otherwise hallucinate fixes

**Idempotent mutations**: don't error when the desired state already exists. Acknowledge and exit 0.

```
$ tasks close 42
task: #42 already closed (no-op)    # exit 0
```

**No interactive prompts.** Every operation must be completable with flags alone. Suppress prompts from wrapped tools.

**Exit codes** — distinct codes so agents branch without parsing:

| Code | Meaning |
|---|---|
| 0 | Success (including no-ops) |
| 1 | General error |
| 2 | Usage error (invalid arguments) |
| 3 | Domain-specific failure |
| 4 | Network error |
| 5 | Auth failure |
| 6 | Rate limited |
| 10 | Dry-run completed |

Include exit code semantics in `schema` output.

### 7. Ambient Context via Session Hooks

Self-install into the agent's session lifecycle so every conversation starts with relevant state already visible — before the agent takes any action.

**Pattern:**

1. On first invocation, install hooks into the agent's configuration (idempotently)
2. At session start, the hook runs your tool and outputs a compact dashboard to stdout
3. The agent receives this as initial context and can act immediately

```
# Agent sees this at session start — no invocation needed:
specs[2]{id,title,status}:
  1,Fix auth bug,open
  2,Add pagination,in-progress

help[2]:
  Run `mytool specs view 1` for details
  Run `mytool specs create --title "..."` to add a spec
```

**Rules:**

- **Default targets**: Claude Code (`~/.claude/settings.json`) and Codex (`~/.codex/hooks.json` + `[features].codex_hooks = true` in `config.toml`)
- **Self-installing**: register hooks on first run — no manual setup
- **Path repair**: on every invocation, check existing hooks and update the executable path if it has changed (self-install becomes self-heal)
- **Idempotent**: repeated installs with the same path are silent no-ops
- **Directory-scoped**: show only state relevant to the current working directory
- **Token-budget-aware**: this loads on every session — ruthlessly minimize. Just enough for the agent to orient
- **Lifecycle capture**: use SessionEnd hooks to capture what happened, so future SessionStart context gets richer over time

### 8. Content-First Output

Running your CLI with no arguments shows the most relevant live content — not a usage manual. When an agent sees actual state it can act immediately. When it sees help text, it has to make a second call.

```
$ tasks
tasks[3]{id,title,status}:
  1,Fix auth bug,open
  2,Add pagination,open
  3,Update docs,closed
help[2]:
  Run `tasks view <id>` to see full details
  Run `tasks create --title "..."` to add a task
```

### 9. Contextual Disclosure

Include a few next steps that follow logically from the current output. The agent discovers your CLI's surface area organically by using it.

- **Relevant**: after an open item → suggest closing; after an empty list → suggest creating; after a list → suggest viewing
- **Actionable**: every suggestion is a complete command, carrying forward disambiguating flags from the current invocation
- **Parameterize dynamic values**: use `<id>` or `"<title>"` placeholders, not guessed concrete values
- **Omit when self-contained**: detail views, counts, confirmations don't need suggestions
- **Guide discovery, not workflows**: suggest variety, don't prescribe a fixed sequence
- **Reveal truncated lists**: when a list shows N of 47, hint how to see all
- **Resolve errors**: on errors, suggest the specific command that fixes the problem, not "see `--help`"

### 10. Consistent Help

The home view identifies the tool itself before the live data:

```
$ tasks
bin: ~/.local/bin/tasks
description: Manage project tasks in the current workspace
...
```

- Include the absolute path of the current executable, with `$HOME` collapsed to `~`
- One-sentence description of what this tool does
- Every subcommand supports `--help` with a concise reference: flags with defaults, required args, 2-3 examples
- `--help` under 100 tokens. Per-subcommand reference — don't dump the whole CLI manual
- Ship `mytool schema <command>` returning structured flags/args/types/exit-codes for programmatic discovery

## Beyond AXI: Error Tolerance

Not in AXI canon, but useful: when the intent of a command is clear but syntax is slightly wrong, honor it anyway with a hint.

- Accept `--format json` as alias for `--json`
- Precede the response with: `"hint": "Did you mean --json? Using structured output."`
- For unrecoverable errors, include 2 example correct invocations in the error response

## When NOT to Apply

- Internal library APIs consumed by your own code (standard API design applies)
- Human-only tools with no agent use case
- Exploratory/interactive tools (REPLs, editors)

## Implementation Order

When retrofitting an existing CLI:

1. **TOON or `--json`** on the most-used commands first
2. **Structured errors** on stdout (biggest impact on agent success rates)
3. **Definitive empty states** and **content-first output** (cheap, high-impact)
4. **Schema introspection** (`mytool schema <command>`)
5. **Pre-computed aggregates** for the heaviest list endpoints
6. **Ambient context** via session hooks (medium effort, big payoff)
7. **Contextual disclosure** suggestions
8. **Token efficiency** optimizations (truncation, minimal schemas)
9. **Error tolerance** and fuzzy matching

## Reference Implementations

- [`gh-axi`](https://github.com/kunchenguid/gh-axi) — GitHub operations with compact, agent-oriented output
- [`chrome-devtools-axi`](https://github.com/kunchenguid/chrome-devtools-axi) — browser automation with TOON output and contextual next steps
