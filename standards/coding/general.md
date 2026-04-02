# General Coding Standards

## Purpose
Write code that is simple, clear, and easy to change.

## General Principles
- Prefer readability over cleverness. Clever code is bad code.
- Keep code concise and understandable; avoid unnecessary complexity.
- Favor small, focused functions that do one thing well.
- Use early returns to reduce nesting.
- Avoid else blocks when an early return or guard clause can simplify flow.
- Keep side effects isolated and explicit.
- Prefer pure helpers for computation and path building.
- Reduce duplication by extracting helper functions.
- Keep decisions in one place; pass flags to control behavior instead of branching in multiple places.
- Prefer explicit names over abbreviated or ambiguous names.
- Choose descriptive, human-friendly function names.

## Formatting
- Use 2 spaces for indentation.
- Do not use tabs unless the language requires them.
- Keep lines readable; wrap long expressions when needed.
- Use `.yaml` for YAML files (not `.yml`) unless a specific external tool requires an exact filename.

## Versioning
- Use semantic versioning (`MAJOR.MINOR.PATCH`) for all version fields and schema versions.

## Control Flow
- Use guard clauses and early returns.
- Avoid deep nesting; flatten logic with helpers and flags.
- Separate decision-making from side effects.
- Avoid mixing dry-run and live execution logic in multiple places.

## Functions and Structure
- Keep methods small and focused.
- Extract helpers for repeated logic (e.g., path resolution, command construction).
- Centralize shared logic to avoid inconsistencies.
- Prefer single-responsibility functions.
- Prefer composable helpers over inline branching.
- Avoid one-off logic in loops when a reusable formatter/normalizer can be extracted.
- Build behavior from small reusable units (parse -> normalize -> validate -> execute) instead of monolithic blocks.
- Treat duplication as a design problem; extract shared helper paths early.

## Commands and Execution
- Centralize command execution in helper functions.
- Separate dry-run output from real execution.
- Only add execution-time flags where needed; do not pollute dry-run output.

## Naming
- Avoid vague names like maybe_*.
- Use direct, descriptive names.
- Function names should reflect what they do, not how they do it.

## Error Handling
- Fail fast with clear error messages.
- Keep error handling consistent and close to the failure point.

## Testing and Safety
- Avoid hidden side effects.
- Prefer predictable, deterministic behavior.
