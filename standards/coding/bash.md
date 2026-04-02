# Bash Coding Style Guide

This document is Bash-specific and extends `./general.md`.

## Core Standards

- Start scripts with `set -o errexit -o pipefail -o nounset` and an `ERR` trap that reports line, command, and exit code.
- Use `set -o noclobber` for overwrite safety when script outputs should not be replaced implicitly.
- Two-space indentation everywhere; no tabs.
- In `case` blocks, align `;;` like other closing tokens (`fi`, `done`, `esac`) at the branch-closing indentation level.
- Globals: declare and name in `UPPER_SNAKE_CASE`; initialize near the top.
- When declaring globals and locals, initialize in the same `declare` or `local` statement (no separate assignment).
- Locals: use `local` with `camelCase` names.
- Functions: prefer `camelCase` names; keep one responsibility per function; return early, return on errors instead of nesting `else`.
- Build command arguments with arrays and execute once via a helper for dry-run/real-run parity.
- Defaults: set once up front, override explicitly when flags are provided.
- In thin wrapper scripts, avoid heredocs when they obscure command construction.

## Required Script Context Vars

- Define these globals in all scripts (initialized near the top):
- `SCRIPT_NAME`: basename of the executed script.
- `SCRIPT_DIR`: physical directory of the script (after symlink resolution when needed).
- `WORK_DIR`: working directory where the script was invoked.
- `ROOT_DIR`: project root above repo folders.
- Keep these names stable so shared helpers and reviews can rely on them consistently.

## Reference Implementations

Use these scripts as the canonical patterns for working directory capture, script/tool/root resolution, and wrapper flow:

- `infra/up` (primary reference for compose wrapper flow, profiles/files, dry-run handling, and WSL-aware compose rewriting)
- `infra/down`
- `services/tools/service/new`
- `services/tools/service/build`
- `services/tools/service/run`
- `services/tools/service/update_libs`
- `services/tools/project/info/get`
- `services/tools/run/node`

## Input Handling

- Sanitize inputs before use: strip `\r`, trim whitespace.
- Skip blank lines and comments when reading files.
- Do not use raw `for item in $(...)` over unsanitized command output.
- If using `for ... in $(...)`, only iterate over sanitized token-like values that cannot contain internal spaces.
- Avoid `mapfile` and `IFS`-based array reads; they are not portable on macOS and routinely break under the project wrappers. Prefer explicit `sed`/`awk` picks or simple `for` loops over pre-trimmed lines.
- When you need multiple values from a small block, prefer a grouped `read` tuple over `mapfile`/IFS tricks. Example:
  ```bash
  local featureName chartName namespace extraArgs
  { read -r featureName; read -r chartName; read -r namespace; read -r extraArgs; } <<< "${featureConfig}"
  ```
- Centralize trimming/filtering in helpers (e.g., `trim`, `getLines`).

## Control Flow

- Use guard clauses to bail out early; avoid `else` when a guard can return.
- Keep the execution path flat and readable; small helpers rather than long blocks.
- Keep logging near the action; concise prefixes like `[+]`, `[✓]`, `[!]`.

## CLI / Help Patterns

- Provide a help function (`showHelp` preferred, `Showhelp` acceptable in legacy scripts) with usage, options, notes, and examples.
- Validate required flags before running main logic; emit clear errors and exit non-zero.
- Prefer `--flag value` patterns.
- Wrapper scripts may accept positional pass-through arguments when required by the wrapped command.
- For argument parsing loops, prefer `while [[ $# > 0 ]]; do` for broad shell compatibility in this project.

## Loops and Parsing

- Use `for item in $(sanitized_command); do ...; done` only after output is trimmed/filtered and values are guaranteed token-safe.
- Guard and `continue` for invalid lines.
- Reuse parsing helpers to keep behavior consistent across scripts.

## Output and Summary

- Keep status lines short and aligned with actions.
- Provide summary output when processing lists (counts and categories).
- Build structured payloads (e.g., JSON) as single-line strings to avoid heredocs.

## Error Handling and Safety

- Fail fast on missing inputs or invalid modes.
- Use `return` or `exit` with non-zero codes on errors.
- Avoid side effects inside parsing loops; keep cleanup explicit.

## Example Skeleton (pattern)

```bash
#!/bin/bash

set -o errexit -o pipefail -o nounset
# Optional, enable only for non-overwrite scripts:
# set -o noclobber

trap 'echo "ERROR: line=$LINENO cmd=$BASH_COMMAND exit=$?"' ERR

declare DEFAULT_CLUSTER="stage"
declare TARGET_FILE=""

function showHelp() {
  local exit_code=${1:-0}
  local error_msg=${2:-""}
  echo "Usage: ${0##*/} --file <path> [options]"
  echo ""
  echo "Options:"
  echo "  --file <path>        Path to input file (required)"
  echo "  --cluster <name>     Cluster name (default: ${DEFAULT_CLUSTER})"
  echo "  -h, --help           Show this help message"
  echo ""
  if [ -n "${error_msg}" ]; then
    echo "Error: ${error_msg}"
    echo ""
  fi
  exit "${exit_code}"
}

function trim() {
  local raw="$1"
  echo "$raw" | tr -d '\r\n'
}

function getLines() {
  local path="$1"
  sed -e 's/\r$//' \
      -e 's/^[[:space:]]*//;s/[[:space:]]*$//' \
      -e '/^$/d' \
      -e '/^#/d' "$path"
}

function parseArgs() {
  while [[ $# > 0 ]]; do
    case "$1" in
      --file)
        TARGET_FILE="$2"
        shift 2
        ;;
      --cluster)
        DEFAULT_CLUSTER="$2"
        shift 2
        ;;
      -h|--help)
        showHelp 0
        ;;
      *)
        showHelp 1 "Unknown option: $1"
        ;;
    esac
  done
}

function validateInputs() {
  [ -n "$TARGET_FILE" ] || showHelp 1 "--file is required"
  [ -f "$TARGET_FILE" ] || showHelp 1 "File not found: $TARGET_FILE"
}

function processLine() {
  local line="$(trim "$1")"
  # do work with "$line"
}

function processFile() {
  for line in $(getLines "$TARGET_FILE"); do
    processLine "$line"
  done
}

parseArgs "$@"
validateInputs
processFile
echo "[+] Done"
```

Use this as the baseline pattern for new scripts. Align status messages, summaries, and parsing helpers with this style to keep scripts consistent.
