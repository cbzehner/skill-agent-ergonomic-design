---
name: agent-ergonomic-design
description: Design CLIs, APIs, and tools optimized for AI agent consumption. Use when
  building tools that agents will call, adding robot/machine mode to CLIs, designing
  MCP tools, or when the user mentions "agent-friendly", "machine-readable output",
  "robot mode", or wants to make a tool work well with AI coding agents.
license: MIT
effort: medium
allowed-tools: Read Write Edit Bash Grep Glob
metadata:
  based-on: "AXI (Agent eXperience Interface) by Kun Chen"
  upstream: "https://github.com/kunchenguid/axi"
---

# /agent-ergonomic-design

Design and implement interfaces optimized for AI agent consumption.

## Core Principle

Design test: "Can an agent reliably parse this, branch on failures, and stay within context limits?"

## Design Checklist

### 1. Structured Output

- Add `--json` flag to every command. Route structured data to stdout, human messages to stderr.
- Support `OUTPUT_FORMAT=json` environment variable for session-wide control.
- Auto-detect TTY: pretty tables for humans when interactive, JSON when piped.
- Resolution order: `--json` flag > `--human` flag > `OUTPUT_FORMAT` env > TTY detection.
- Treat output schemas as **stable API contracts**. Breaking changes break all downstream automation.

### 2. Token Efficiency

- **Minimal default fields**: Return 3-4 fields per list item, not 10+. Provide `--fields name,id,status` to request more.
- **Truncation with hints**: Truncate large text fields, append size: `(truncated, 2847 chars -- use --full for complete body)`.
- **Streaming for large results**: Use NDJSON (one JSON object per line) via `--ndjson`.
- **No decorative output**: Skip ASCII art, progress bars, color codes, spinners in machine mode.

### 3. Structured Errors

Model after RFC 7807 Problem Details:

```json
{"error_code": "INVALID_PRICE", "detail": "Field 'price' must be positive. Got: -5", "suggestions": ["Use a positive decimal, e.g. 9.99"]}
```

- **Typed error kinds**: Machine-readable `error_code` field. Agents branch on type, not regex on message text.
- **Recovery actions**: Include `suggestions` array. Agents hallucinate fixes without explicit guidance.
- **Rate limit headers**: Include `X-RateLimit-Remaining` and `Retry-After`.

### 4. Exit Codes

Use distinct codes so agents branch without parsing stderr:

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Domain-specific failure |
| 4 | Network error |
| 5 | Auth failure |
| 6 | Rate limited |
| 10 | Dry-run completed |

Include exit code semantics in `schema` output.

### 5. Discoverability

- Ship `mytool schema <command>` returning JSON with flags, args, types, required fields, exit codes.
- `mytool --help` should be under 100 tokens. Dense, structured, no prose.
- Include example invocations in help output: `mytool users list --json --fields id,name`.

### 6. Idempotency and Safety

- Mutations should support `--dry-run` returning what would change.
- Reads are always safe to retry. Document which writes are idempotent.
- Include `--confirm` / `--yes` flags for destructive operations.
- Never require interactive input (prompts, password entry, Y/n). Provide flag alternatives for everything.

### 7. Error Tolerance

When the intent of a command is clear but syntax is slightly wrong:
- Honor the command anyway (e.g., accept `--format json` as alias for `--json`)
- Precede the response with a note: `"hint": "Did you mean --json? Using structured output."`
- For unrecoverable errors, include 2 example correct invocations in the error response

## When NOT to Apply

- Internal library APIs consumed by your own code (standard API design applies)
- Human-only tools with no agent use case
- Exploratory/interactive tools (REPLs, editors)

## Implementation Order

When retrofitting an existing CLI:
1. `--json` flag on the most-used commands first
2. Structured errors (biggest impact on agent success rates)
3. Schema introspection
4. Token efficiency optimizations
5. Error tolerance and fuzzy matching
