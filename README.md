# plain-crypto-check

`plain-crypto-check` is a small Bash-based incident response utility for detecting indicators tied to the March 31, 2026 Axios npm compromise.

The project currently includes:

- `scan-plain-crypto-js.sh`: scans common JavaScript package cache locations and optional project folders for indicators related to `plain-crypto-js` and tainted Axios releases.
- `client-summary.txt`: client-facing incident summary with source citations.
- `affected-products.md`: triage guidance for commonly used tools and workflows that may have resolved the compromised Axios releases.
- `todo.md`: running backlog for follow-up work, including performance-oriented next steps.

## Background

Security researchers reported that malicious Axios releases `1.14.1` and `0.30.4` introduced a hidden dependency on `plain-crypto-js@4.2.1`. The dependency executed a `postinstall` flow that delivered a cross-platform remote access trojan. This repository provides a fast local scanner to help identify whether cached package content or project files contain known indicators from that incident.

This project is intended to support triage and evidence collection. It is not a cleanup or remediation tool.

## Features

- Scans common `npm`, `Yarn`, `pnpm`, and `Bun` cache locations
- Supports Linux, macOS, and Windows environments through WSL path discovery
- Accepts one or more `--project` and `--folder` paths for targeted scanning
- Uses a faster staged file-selection path instead of broad repeated recursive scans
- Prints compact snippets by default and full surrounding context in verbose mode
- Adds a summary of potential files, locations, and matched patterns at the end
- Returns a non-zero exit code when no indicators are found or when no scan targets are available

## Requirements

- Bash
- Standard Unix tools available in most developer environments:
  - `grep`
  - `find`
  - `sed`
  - `mktemp`

The script is written for portability and avoids Bash features that commonly break on older macOS installations.

## Performance Notes

The scanner is intended for incident triage, not for exhaustive high-speed inventory across very large caches. The current backlog in [`todo.md`](./todo.md) tracks the next performance-oriented follow-up items, including scan-scope narrowing, staged inspection, and parallel execution where it can be done safely.

## Usage

Run the scanner with default cache discovery:

```bash
./scan-plain-crypto-js.sh
```

Scan one or more specific projects or folders in addition to cache locations:

```bash
./scan-plain-crypto-js.sh --project /path/to/repo
./scan-plain-crypto-js.sh --project /path/to/repo --folder /tmp/cache-copy
./scan-plain-crypto-js.sh --folder /opt/build-cache --folder /srv/ci/workspace
```

Show help:

```bash
./scan-plain-crypto-js.sh --help
./scan-plain-crypto-js.sh --verbose --project /path/to/repo
```

Run directly from a hosted raw script URL:

**wget**

```bash
wget -qO- 'https://raw.githubusercontent.com/jdarling/plain-crypto-scanner/refs/heads/main/scan-plain-crypto-js.sh' | bash
```

**curl**

```bash
curl -fsSL 'https://raw.githubusercontent.com/jdarling/plain-crypto-scanner/refs/heads/main/scan-plain-crypto-js.sh' | bash
```

## What It Detects

The scanner looks for content and filenames associated with:

- `plain-crypto-js`
- `axios@1.14.1`
- `axios@0.30.4`
- `axios@latest`
- `axios@legacy`

The content scan also attempts to surface version references commonly found in lockfiles and cached package metadata.

## Output

When indicators are found, the script prints:

- The directory being scanned
- In default mode, a compact snippet around each matched token
- In verbose mode, the full matching line with surrounding context
- A final summary with file name, location, and matched pattern

Example:

```text
[+] Scanning 2 directories from /workspace

==> Matches in: /tmp/plain-crypto-home/.npm
/tmp/plain-crypto-home/.npm/suspect.txt:1: ...before plain-crypto-js after...

[!] Potential indicators found. scanned=2 matched=1
Potential Files Summary:
suspect.txt | /tmp/plain-crypto-home/.npm/suspect.txt:1 | plain-crypto-js
```

## Exit Codes

- `0`: one or more potential indicators were found
- `1`: no indicators were found, or no valid scan targets were available

## Incident Guidance

If the scanner finds a match, do not treat it as a harmless package hygiene issue. Public advisories for this incident recommend treating affected systems as potentially fully compromised. Response actions should be performed from a clean machine and typically include:

- credential rotation
- secret and API key replacement
- rebuilding affected workstations or CI runners
- broader incident response review for exposed data and access

## Sources

- GitLab Advisory Database: `GHSA-fw8c-xr5c-95f9`
- StepSecurity: Axios Compromised on npm - Malicious Versions Drop Remote Access Trojan
- Snyk: Axios npm Package Compromised: Supply Chain Attack Delivers Cross-Platform RAT
- Datadog Security Labs: Compromised axios npm package delivers cross-platform RAT
- Axios issue tracker: `axios@1.14.1 and axios@0.30.4 are compromised`

See [`client-summary.txt`](./client-summary.txt) for a concise client-facing summary with direct source links.
See [`affected-products.md`](./affected-products.md) for a user-facing triage list of common products and workflows to ask about during incident review.
See [`todo.md`](./todo.md) for the current backlog and optimization notes.

## License

This project is licensed under the MIT License. See [`LICENSE`](./LICENSE) for details.
