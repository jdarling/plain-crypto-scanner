# Potentially Affected Products and Workflows

This document helps users identify software and workflows that may have pulled the compromised Axios releases during the March 31, 2026 npm supply-chain incident.

The useful question is not "what changed since last Friday." The higher-signal question is:

"What did you install, upgrade, or rebuild with npm, Yarn, or pnpm during the Axios compromise window on March 31, 2026, or what reused caches populated during that window?"

## Date Window

Public reporting places the malicious Axios releases in the npm registry during a narrow window on March 31, 2026:

- `axios@1.14.1` published at approximately `00:21 UTC`
- `axios@0.30.4` published at approximately `01:00 UTC`
- removals reported around `03:25 UTC` to `03:29 UTC`

That means the most relevant user activity is anything that fetched JavaScript dependencies during that period or reused caches populated from that period afterward.

## Commonly Used Products to Ask About

These products are examples of commonly used developer tools that are often installed or updated directly from npm. They are useful prompts for end users during triage.

### Global npm CLI tools

- Firebase CLI
  - Typical install: `npm install -g firebase-tools`
  - Source: https://firebase.google.com/docs/cli
- AWS CDK CLI
  - Typical install: `npm install -g aws-cdk`
  - Source: https://docs.aws.amazon.com/cdk/v2/guide/cli.html
- Netlify CLI
  - Typical install: `npm install -g netlify-cli`
  - Source: https://docs.netlify.com/api-and-cli-guides/cli-guides/get-started-with-cli/
- Vercel CLI
  - Typical install: `npm install -g vercel`
  - Source: https://www.npmjs.com/package/vercel
- Atlassian Forge CLI
  - Typical install: `npm install -g @forge/cli`
  - Source: https://www.npmjs.com/package/@forge/cli
- Gemini CLI
  - Typical install: `npm install -g @google/gemini-cli`
  - Source: https://www.npmjs.com/package/%40google/gemini-cli

These are examples, not a complete list. Any globally installed npm CLI is potentially relevant if it resolved Axios during the compromise window.

### Atlassian Forge and Marketplace app development

Atlassian explicitly warned Forge and Marketplace developers that if their app used Axios directly or transitively and developers ran installs or builds during the compromise window, the developer workstation or CI environment may have been compromised.

Source:

- https://community.developer.atlassian.com/t/action-required-for-marketplace-app-developers-axios-npm-supply-chain-compromise/99996

### CI/CD build pipelines

Ask whether any CI or build automation ran during the compromise window, especially:

- `npm install`
- `npm update`
- `yarn install`
- `yarn upgrade`
- `pnpm install`
- automated dependency refresh jobs
- image builds that warm package caches

This applies to:

- frontend web applications
- Node.js backends
- Electron applications
- internal developer tools
- monorepos

### Local project bootstrap and rebuild workflows

Users should also think about routine actions that may have looked harmless at the time:

- cloning a repo and running `npm install`
- pulling changes and refreshing dependencies
- rebuilding a local development environment
- reinstalling dependencies after deleting `node_modules`
- updating a local npm-delivered CLI

## Recommended User Prompt

This wording is appropriate for user-facing communication:

"Think about anything you installed or updated with npm, Yarn, or pnpm on Tuesday, March 31, 2026, especially developer CLIs, JavaScript projects, CI runners, and Forge or Marketplace app builds. Examples include Firebase CLI, AWS CDK, Netlify CLI, Vercel CLI, Forge CLI, Gemini CLI, and any local Node project that refreshed dependencies."

## Important Scope Note

This list should be presented as a triage aid, not as a confirmed list of infected products. The underlying risk model is broader:

- any product or workflow that resolved Axios during the compromise window may be relevant
- any cache created during that window may remain relevant later
- a product not named in this document can still be affected

## Sources

- GitLab Advisory Database, GHSA-fw8c-xr5c-95f9
  - https://advisories.gitlab.com/pkg/npm/axios/GHSA-fw8c-xr5c-95f9/
- Atlassian advisory for Marketplace and Forge developers
  - https://community.developer.atlassian.com/t/action-required-for-marketplace-app-developers-axios-npm-supply-chain-compromise/99996
- Firebase CLI documentation
  - https://firebase.google.com/docs/cli
- AWS CDK CLI documentation
  - https://docs.aws.amazon.com/cdk/v2/guide/cli.html
- Netlify CLI documentation
  - https://docs.netlify.com/api-and-cli-guides/cli-guides/get-started-with-cli/
- Vercel npm package page
  - https://www.npmjs.com/package/vercel
- Atlassian Forge CLI npm package page
  - https://www.npmjs.com/package/@forge/cli
- Gemini CLI npm package page
  - https://www.npmjs.com/package/%40google/gemini-cli
