# plain-crypto-check TODO

This file tracks completed work and next steps for the `plain-crypto-check` project. It is written so development can resume from a fresh machine or after an interrupted session without needing prior conversation history.

## Current Project State

- Repository path: `/home/jdarling/plain-crypto-check`
- Primary script: `scan-plain-crypto-js.sh`
- Supporting docs:
  - `README.md`
  - `LICENSE`
  - `client-summary.txt`
  - `affected-products.md`

The project currently focuses on detecting indicators tied to the March 31, 2026 Axios npm supply-chain compromise involving `plain-crypto-js`.
The next phase should assume the scanner has already been made faster and should focus on validation, tuning, and any follow-up output decisions.

## Completed

- [x] Create a portable Bash scanner for Linux, macOS, and Windows WSL environments.
  - Script discovers common cache paths for npm, Yarn, pnpm, and Bun.
  - Script also accepts repeated `--project <path>` and `--folder <path>` arguments.

- [x] Scan for the primary malicious package and tainted Axios references.
  - Current content patterns include:
    - `plain-crypto-js`
    - `axios@1.14.1`
    - `axios@0.30.4`
    - `axios@latest`
    - `axios@legacy`
    - version string references to `1.14.1` and `0.30.4`

- [x] Add compact default output.
  - Default mode prints `file:line:` plus a short snippet around the matched token.
  - This was added because full-context output was too noisy for normal use.

- [x] Add verbose mode.
  - `--verbose` and `-v*` now print fuller matching output with surrounding context.
  - Compact summary data is still collected in verbose mode.

- [x] Add an end-of-run summary.
  - Summary shows:
    - filename
    - file location
    - matched pattern
  - Example format:
    - `yarn.lock | /path/to/yarn.lock:3 | 0.30.4`

- [x] Refactor the script to match local project standards.
  - Applied conventions from:
    - `standards/coding/bash.md`
    - `standards/coding/general.md`
  - Notable refactor decisions:
    - strict shell options
    - error trap
    - stable script context globals
    - camelCase function names
    - flattened control flow
    - removal of associative arrays for macOS Bash compatibility

- [x] Create a client-facing incident summary.
  - File: `client-summary.txt`
  - Format follows `standards/docs/client-summary.md`
  - Includes problem, solution, specific results, technical evidence, next action, and source list

- [x] Research and document commonly used products and workflows users should think about.
  - File: `affected-products.md`
  - Includes:
    - correct compromise date window
    - examples of global npm CLIs
    - Forge / Marketplace app guidance
    - CI/CD and local rebuild workflow prompts
    - source citations

- [x] Add project documentation and license.
  - `README.md` created
  - `LICENSE` created with MIT text

- [x] Cross-reference documents.
  - `README.md` references `client-summary.txt` and `affected-products.md`
  - `client-summary.txt` references `affected-products.md`

- [x] Improve scanner performance by reducing duplicated traversal.
  - The scanner now collects candidate files in one pass per target directory.
  - It filters that candidate set before content inspection instead of running a separate recursive filename scan and recursive content scan.

- [x] Narrow content scans to likely relevant files.
  - The current scan favors lockfiles, manifests, and common source / metadata file types.
  - It avoids a broad content scan across every file in the cache tree.

- [x] Exclude more expensive irrelevant file types.
  - The current candidate collection skips common archive, binary, image, and bundle-oriented extensions.
  - Existing directory pruning for `.git` and `node_modules` is preserved.

## Open Work

- [ ] Validate the performance refactor against large real-world caches.
  - Confirm the scanner still finds the same indicators after the refactor.
  - Measure runtime on a representative npm cache, Yarn cache, and at least one project tree.
  - Capture before/after notes so the team can tell whether the change is materially faster.

- [ ] Confirm compact output still carries enough context for incident triage.
  - Check that default output remains readable when multiple matches appear in the same file.
  - Verify that verbose mode remains the path for full context dumps.
  - Decide whether the current summary lines are sufficient for handoffs and reports.

- [ ] Decide whether any additional speedups are still worth doing.
  - If the current scan is fast enough for incident work, stop here.
  - If it is still too slow on large caches, prioritize the remaining items below.

- [ ] Add a staged scan strategy.
  - Stage 1:
    - quick scan for likely hits in lockfiles, manifests, cache metadata, and suspicious filenames
    - keep this stage optimized for speed and broad coverage
    - allow this stage to produce possible hits rather than final high-confidence conclusions
  - Stage 2:
    - run deeper validation only for files and packages flagged by stage 1
    - confirm whether the hit is actually related to Axios or plain-crypto-js
    - use package-aware validation rules for npm metadata so unrelated packages with matching version numbers are not treated as confirmed hits
  - This should make clean scans much faster while reducing false positives in large caches.

- [ ] Add a fast filename-first mode internally.
  - First identify files or paths containing likely tokens such as:
    - `plain-crypto-js`
    - `axios`
    - `1.14.1`
    - `0.30.4`
    - `latest`
    - `legacy`
  - Then run deeper content inspection only where useful.
  - This does not need to be user-visible as a new flag unless desired.

- [ ] Tighten hit validation rules to reduce false positives from unrelated package versions.
  - Current issue:
    - unrelated npm metadata blobs can match because some packages legitimately use version numbers like `1.14.1` or `0.30.4`
  - Validation direction:
    - only treat version `1.14.1` or `0.30.4` as high-confidence when the package metadata is clearly for `axios`
    - keep `plain-crypto-js` as a direct high-confidence indicator
    - treat raw `axios@latest` or `axios@legacy` references as suspicious only when they appear in lockfiles, dependency specs, or Axios package metadata
  - Likely implementation shape:
    - stage 1 quick scan finds candidates
    - stage 2 reads candidate files and confirms package name plus matched version or tag relationship

- [ ] Reduce subprocess overhead.
  - Current script frequently shells out to:
    - `sed`
    - `grep`
    - `find`
    - `basename`
    - `cat`
    - `mktemp`
  - Review which parsing steps can be collapsed or combined.
  - Keep portability in mind for macOS Bash.

- [ ] Evaluate safe parallel scanning of independent directories.
  - Each top-level cache directory can likely be scanned independently.
  - This could improve runtime on SSD-backed systems.
  - Needs careful design to preserve:
    - deterministic summary output
    - readable logging
    - portable behavior

- [ ] Consider adding an explicit quick-scan mode if the current scan is still too slow.
  - Possible future flag:
    - `--quick`
  - Intended behavior:
    - inspect only lockfiles, metadata, and suspicious filenames
    - report possible hits quickly
    - skip deeper validation unless requested
  - Related model:
    - quick scan finds candidates
    - normal or deep scan confirms candidates
  - This is now both a product decision and a false-positive reduction strategy.

- [ ] Review exit code behavior.
  - Current behavior:
    - `0` when indicators are found
    - `1` when no indicators are found or when no valid scan targets exist
  - This may be intentional for incident workflows, but it is slightly unusual.
  - Decide whether “clean scan” and “scan error / no targets” should remain conflated.

- [ ] Review summary output for deduplication and grouping.
  - Current summary is line-oriented and can include multiple entries from the same file.
  - Possible improvements:
    - group by file
    - sort output
    - aggregate matched patterns per file
  - Do not implement until output expectations are clarified.

- [ ] Decide whether JSON output is needed.
  - This was mentioned as a possible future enhancement.
  - Useful for:
    - automation
    - CI ingestion
    - incident tracking systems

## Research Context Already Collected

- Axios compromise date window:
  - March 31, 2026
  - malicious packages reported live roughly from `00:21 UTC` to `03:25-03:29 UTC`

- Confirmed malicious package relationship:
  - `axios@1.14.1`
  - `axios@0.30.4`
  - hidden dependency on `plain-crypto-js@4.2.1`

- Security references already used in project docs:
  - GitLab Advisory Database, `GHSA-fw8c-xr5c-95f9`
  - StepSecurity Axios compromise writeup
  - Snyk Axios compromise writeup
  - Datadog Security Labs writeup
  - OSV incident entries
  - Axios GitHub issue thread
  - Atlassian Marketplace / Forge advisory

## Validation Already Performed

- [x] `bash -n scan-plain-crypto-js.sh`
- [x] Synthetic test for default compact output
- [x] Synthetic test for verbose output
- [x] Synthetic test for summary output
- [x] Synthetic test confirming `node_modules` pruning still works after the performance refactor

## Useful Resume Points

If resuming performance work later, start here:

1. Read `scan-plain-crypto-js.sh`
2. Focus on `collectCandidateFiles`, `scanCollectedCandidates`, and `scanPath`
3. Benchmark the current single-walk candidate collection before making deeper changes
4. Re-run `bash -n scan-plain-crypto-js.sh`
5. Recreate the synthetic fixtures under `/tmp` to compare output before and after refactors

## Suggested Next Implementation Order

- [ ] First: benchmark and verify the refactor on realistic caches
- [ ] Second: implement quick-scan candidate detection plus deep validation for flagged hits
- [ ] Third: tighten Axios-specific validation so unrelated package metadata is not flagged
- [ ] Fourth: evaluate optional parallelism only if sequential performance is still insufficient
- [ ] Fifth: revisit output grouping and machine-readable output if downstream users need it
