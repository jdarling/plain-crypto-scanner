#!/usr/bin/env bash

set -o errexit -o pipefail -o nounset

trap 'echo "[!] ERROR: line=${LINENO} cmd=${BASH_COMMAND} exit=$?" >&2' ERR

declare SCRIPT_NAME="$(basename "$0")"
declare SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
declare WORK_DIR="$(pwd -P)"
declare ROOT_DIR="${SCRIPT_DIR}"
declare SEARCH_PATTERN='plain-crypto-js|axios[^[:alnum:]]*(1\.14\.1|0\.30\.4|latest|legacy)|version["'\'']?[[:space:]:=]+["'\'']?(1\.14\.1|0\.30\.4)'
declare CONTEXT_LINES="2"
declare SNIPPET_CONTEXT_CHARS="16"
declare VERBOSE="0"
declare -a CONTENT_FILE_NAMES=(
  "package.json"
  "package-lock.json"
  "npm-shrinkwrap.json"
  "yarn.lock"
  "pnpm-lock.yaml"
  "bun.lock"
  "bun.lockb"
)
declare -a CONTENT_FILE_GLOBS=(
  "*.json"
  "*.js"
  "*.cjs"
  "*.mjs"
  "*.ts"
  "*.mts"
  "*.cts"
  "*.yaml"
  "*.yml"
  "*.txt"
)

declare -a SEARCH_DIRS=()
declare -a EXTRA_DIRS=()
declare -a SUMMARY_LINES=()
declare FALSE_POSITIVE_COUNT="0"

function showHelp() {
  local exitCode="${1:-0}"
  local errorMessage="${2:-""}"

  echo "Usage: ${SCRIPT_NAME} [--project <path>] [--folder <path>]..."
  echo ""
  echo "Scan common JavaScript package caches and optional folders for"
  echo "plain-crypto-js and tainted axios references."
  echo ""
  echo "Options:"
  echo "  --project <path>     Add a project directory to scan"
  echo "  --folder <path>      Add any directory to scan"
  echo "  --verbose            Show full matching lines with surrounding context"
  echo "  -v, -vv, -vvv        Same as --verbose"
  echo "  -h, --help           Show this help message"
  echo ""
  echo "Notes:"
  echo "  - Scans npm, Yarn, pnpm, and Bun cache locations on Linux and macOS."
  echo "  - On WSL, also checks common Windows cache paths under /mnt/c/Users."
  echo "  - Default output shows compact snippets around each match."
  echo "  - Verbose mode shows surrounding context for each match."
  echo ""
  echo "Examples:"
  echo "  ${SCRIPT_NAME}"
  echo "  ${SCRIPT_NAME} --project /repo/app --folder /tmp/cache-copy"

  if [[ -n "${errorMessage}" ]]; then
    echo ""
    echo "Error: ${errorMessage}" >&2
  fi

  exit "${exitCode}"
}

function trim() {
  local rawValue="$1"
  printf '%s' "${rawValue}" | sed -e 's/\r//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

function runCommand() {
  "$@"
}

function logInfo() {
  echo "[+] $1"
}

function logSuccess() {
  echo "[✓] $1"
}

function logWarn() {
  echo "[!] $1" >&2
}

function addSummaryLine() {
  local summaryLine="$1"
  local existingLine=""

  for existingLine in "${SUMMARY_LINES[@]}"; do
    [[ "${existingLine}" == "${summaryLine}" ]] && return 0
  done

  SUMMARY_LINES+=("${summaryLine}")
}

function fileContains() {
  local filePath="$1"
  local pattern="$2"
  local grepExitCode="0"

  grepExitCode=0
  runCommand grep -I -a -E -q "${pattern}" "${filePath}" 2>/dev/null || grepExitCode="$?"
  [[ "${grepExitCode}" -eq 0 ]]
}

function isWsl() {
  [[ -r /proc/version ]] || return 1
  grep -qi microsoft /proc/version
}

function pathExistsInSearchDirs() {
  local candidatePath="$1"
  local existingPath=""

  for existingPath in "${SEARCH_DIRS[@]}"; do
    [[ "${existingPath}" == "${candidatePath}" ]] && return 0
  done

  return 1
}

function addSearchDir() {
  local candidatePath="$(trim "$1")"

  [[ -n "${candidatePath}" ]] || return 0

  if [[ ! -d "${candidatePath}" ]]; then
    return 0
  fi

  if pathExistsInSearchDirs "${candidatePath}"; then
    return 0
  fi

  SEARCH_DIRS+=("${candidatePath}")
}

function addCommonDirsForHome() {
  local homeDir="$1"

  addSearchDir "${homeDir}/.npm"
  addSearchDir "${homeDir}/.cache/npm"
  addSearchDir "${homeDir}/.cache/yarn"
  addSearchDir "${homeDir}/.cache/yarn/v6"
  addSearchDir "${homeDir}/.yarn"
  addSearchDir "${homeDir}/.yarn-cache"
  addSearchDir "${homeDir}/.config/yarn"
  addSearchDir "${homeDir}/.pnpm-store"
  addSearchDir "${homeDir}/.local/share/pnpm/store"
  addSearchDir "${homeDir}/.bun/install/cache"

  addSearchDir "${homeDir}/Library/Caches/npm"
  addSearchDir "${homeDir}/Library/Caches/Yarn"
  addSearchDir "${homeDir}/Library/Caches/pnpm"
  addSearchDir "${homeDir}/Library/Caches/Bun"
  addSearchDir "${homeDir}/Library/pnpm/store"

  addSearchDir "${homeDir}/AppData/Local/npm-cache"
  addSearchDir "${homeDir}/AppData/Local/Yarn/Cache"
  addSearchDir "${homeDir}/AppData/Local/pnpm/store"
  addSearchDir "${homeDir}/AppData/Local/Bun/install/cache"
}

function discoverSearchDirs() {
  local extraDir=""
  local localAppData="${LOCALAPPDATA:-""}"
  local xdgCacheHome="${XDG_CACHE_HOME:-""}"

  addCommonDirsForHome "${HOME}"

  if [[ -n "${xdgCacheHome}" ]]; then
    addSearchDir "${xdgCacheHome}/npm"
    addSearchDir "${xdgCacheHome}/yarn"
    addSearchDir "${xdgCacheHome}/yarn/v6"
    addSearchDir "${xdgCacheHome}/pnpm"
    addSearchDir "${xdgCacheHome}/bun"
  fi

  if [[ -n "${localAppData}" ]]; then
    addSearchDir "${localAppData}/npm-cache"
    addSearchDir "${localAppData}/Yarn/Cache"
    addSearchDir "${localAppData}/pnpm/store"
    addSearchDir "${localAppData}/Bun/install/cache"
  fi

  if isWsl; then
    local linuxUser="$(basename "${HOME}")"
    local windowsHome="/mnt/c/Users/${linuxUser}"
    addCommonDirsForHome "${windowsHome}"
  fi

  for extraDir in "${EXTRA_DIRS[@]}"; do
    addSearchDir "${extraDir}"
  done
}

function createTempFile() {
  mktemp
}

function cleanupTempFile() {
  local tempPath="$1"
  [[ -n "${tempPath}" && -f "${tempPath}" ]] || return 0
  rm -f "${tempPath}"
}

function printFileWithContext() {
  local outputPath="$1"
  cat "${outputPath}"
  echo ""
}

function isSuspiciousFilename() {
  local filePath="$1"
  local baseName="$(basename "${filePath}")"

  [[ "${baseName}" == *plain-crypto-js* ]] && return 0
  [[ "${baseName}" == *axios*1.14.1* ]] && return 0
  [[ "${baseName}" == *axios*0.30.4* ]] && return 0
  [[ "${baseName}" == *axios*latest* ]] && return 0
  [[ "${baseName}" == *axios*legacy* ]] && return 0

  return 1
}

function isLikelyContentCandidate() {
  local filePath="$1"
  local baseName="$(basename "${filePath}")"
  local fileNamePattern=""
  local fileGlob=""

  for fileNamePattern in "${CONTENT_FILE_NAMES[@]}"; do
    [[ "${baseName}" == "${fileNamePattern}" ]] && return 0
  done

  for fileGlob in "${CONTENT_FILE_GLOBS[@]}"; do
    [[ "${baseName}" == ${fileGlob} ]] && return 0
  done

  [[ "${filePath}" == *"/_cacache/"* ]] && return 0
  [[ "${filePath}" == *"/content-v2/"* ]] && return 0
  [[ "${filePath}" == *"/index-v5/"* ]] && return 0
  [[ "${filePath}" == *"/Cache/v6/"* ]] && return 0
  [[ "${filePath}" == *"/.pnpm-store/"* ]] && return 0
  [[ "${filePath}" == *"/pnpm/store/"* ]] && return 0
  [[ "${filePath}" == *"/bun/install/cache/"* ]] && return 0

  return 1
}

function collectCandidateFiles() {
  local targetPath="$1"
  local outputPath="$2"
  local tempPath="$(createTempFile)"
  local candidatePath=""
  local -a findArgs=(
    "${targetPath}"
    \( -path '*/.git' -o -path '*/node_modules' \) -prune -o
    -type f
    \(
      -iname 'package.json' -o
      -iname 'package-lock.json' -o
      -iname 'npm-shrinkwrap.json' -o
      -iname 'yarn.lock' -o
      -iname 'pnpm-lock.yaml' -o
      -iname 'bun.lock' -o
      -iname 'bun.lockb' -o
      -iname '*.json' -o
      -iname '*.js' -o
      -iname '*.cjs' -o
      -iname '*.mjs' -o
      -iname '*.ts' -o
      -iname '*.mts' -o
      -iname '*.cts' -o
      -iname '*.yaml' -o
      -iname '*.yml' -o
      -iname '*.txt' -o
      -path '*/_cacache/*' -o
      -path '*/content-v2/*' -o
      -path '*/index-v5/*' -o
      -path '*/Cache/v6/*' -o
      -path '*/.pnpm-store/*' -o
      -path '*/pnpm/store/*' -o
      -path '*/bun/install/cache/*' -o
      -iname '*plain-crypto-js*' -o
      -iname '*axios*1.14.1*' -o
      -iname '*axios*0.30.4*' -o
      -iname '*axios*latest*' -o
      -iname '*axios*legacy*'
    \)
    -print
  )

  runCommand find "${findArgs[@]}" > "${tempPath}" 2>/dev/null || true

  while IFS= read -r candidatePath; do
    [[ -n "${candidatePath}" ]] || continue

    if isSuspiciousFilename "${candidatePath}" || isLikelyContentCandidate "${candidatePath}"; then
      echo "${candidatePath}" >> "${outputPath}"
    fi
  done < "${tempPath}"

  cleanupTempFile "${tempPath}"
}

function getMatchedPattern() {
  local rawLine="$1"

  if [[ "${rawLine}" == *"plain-crypto-js"* ]]; then
    echo "plain-crypto-js"
    return 0
  fi

  if [[ "${rawLine}" == *"axios@latest"* ]]; then
    echo "axios@latest"
    return 0
  fi

  if [[ "${rawLine}" == *"axios@legacy"* ]]; then
    echo "axios@legacy"
    return 0
  fi

  if [[ "${rawLine}" == *"1.14.1"* ]]; then
    echo "1.14.1"
    return 0
  fi

  if [[ "${rawLine}" == *"0.30.4"* ]]; then
    echo "0.30.4"
    return 0
  fi

  echo "unknown"
}

function getValidationPattern() {
  local infectionType="$1"

  case "${infectionType}" in
    plain-crypto-js|filename:plain-crypto-js)
      echo 'plain-crypto-js'
      ;;
    filename:axios@1.14.1|axios@1.14.1|"axios@latest->1.14.1")
      echo 'axios@1\.14\.1|"name":"axios"|"version":"1\.14\.1"|axios@latest|version["'\'']?[[:space:]]+["'\'']1\.14\.1'
      ;;
    filename:axios@0.30.4|axios@0.30.4|"axios@legacy->0.30.4")
      echo 'axios@0\.30\.4|"name":"axios"|"version":"0\.30\.4"|axios@legacy|version["'\'']?[[:space:]]+["'\'']0\.30\.4'
      ;;
    *)
      echo 'plain-crypto-js|axios'
      ;;
  esac
}

function buildCompactSnippet() {
  local rawLine="$1"
  local matchToken="$2"
  local cleanLine="$(printf '%s' "${rawLine}" | sed -e 's/\r//g' -e 's/[[:space:]]\+/ /g')"
  local prefix="${cleanLine%%"${matchToken}"*}"
  local suffix="${cleanLine#*"${matchToken}"}"
  local prefixLength="${#prefix}"
  local suffixLength="${#suffix}"
  local prefixStart="0"
  local suffixLengthToShow="${SNIPPET_CONTEXT_CHARS}"

  if [[ "${prefixLength}" -gt "${SNIPPET_CONTEXT_CHARS}" ]]; then
    prefixStart="$((prefixLength - SNIPPET_CONTEXT_CHARS))"
  fi

  if [[ "${suffixLength}" -lt "${SNIPPET_CONTEXT_CHARS}" ]]; then
    suffixLengthToShow="${suffixLength}"
  fi

  local prefixSnippet="${prefix:${prefixStart}}"
  local suffixSnippet="${suffix:0:${suffixLengthToShow}}"
  local leftEllipsis=""
  local rightEllipsis=""

  if [[ "${prefixStart}" -gt 0 ]]; then
    leftEllipsis="..."
  fi

  if [[ "${suffixLength}" -gt "${suffixLengthToShow}" ]]; then
    rightEllipsis="..."
  fi

  echo "${leftEllipsis}${prefixSnippet}${matchToken}${suffixSnippet}${rightEllipsis}"
}

function printCompactMatches() {
  local outputPath="$1"
  local matchLine=""
  local filePath=""
  local lineNumber=""
  local rawLine=""
  local matchToken=""
  local snippet=""

  while IFS= read -r matchLine; do
    [[ -n "${matchLine}" ]] || continue

    filePath="${matchLine%%:*}"
    lineNumber="${matchLine#*:}"
    lineNumber="${lineNumber%%:*}"
    rawLine="${matchLine#*:*:}"
    matchToken="$(getMatchedPattern "${rawLine}")"
    snippet="$(buildCompactSnippet "${rawLine}" "${matchToken}")"

    echo "${filePath}:${lineNumber}: ${snippet}"
  done < "${outputPath}"

  echo ""
}

function printSummary() {
  local summaryLine=""

  echo "Infected Files Summary:"

  if [[ ${#SUMMARY_LINES[@]} -eq 0 ]]; then
    echo "none"
    if [[ "${FALSE_POSITIVE_COUNT}" -gt 0 ]]; then
      echo "Note: ${FALSE_POSITIVE_COUNT} possible targets were validated and determined to be false positives."
    fi
    return 0
  fi

  for summaryLine in "${SUMMARY_LINES[@]}"; do
    echo "${summaryLine}"
  done

  if [[ "${FALSE_POSITIVE_COUNT}" -gt 0 ]]; then
    echo "Note: ${FALSE_POSITIVE_COUNT} possible targets were validated and determined to be false positives."
  fi
}

function hasBroadCandidateSignal() {
  local candidatePath="$1"
  local grepExitCode="0"

  if isSuspiciousFilename "${candidatePath}"; then
    return 0
  fi

  grepExitCode=0
  runCommand grep -I -a -E -q "${SEARCH_PATTERN}" "${candidatePath}" 2>/dev/null || grepExitCode="$?"
  [[ "${grepExitCode}" -eq 0 ]]
}

function detectInfectionType() {
  local candidatePath="$1"
  local baseName="$(basename "${candidatePath}")"

  [[ "${baseName}" == *plain-crypto-js* ]] && {
    echo "filename:plain-crypto-js"
    return 0
  }

  [[ "${baseName}" == *axios*1.14.1* ]] && {
    echo "filename:axios@1.14.1"
    return 0
  }

  [[ "${baseName}" == *axios*0.30.4* ]] && {
    echo "filename:axios@0.30.4"
    return 0
  }

  if fileContains "${candidatePath}" 'plain-crypto-js'; then
    echo "plain-crypto-js"
    return 0
  fi

  if fileContains "${candidatePath}" '"name":"axios"'; then
    if fileContains "${candidatePath}" '"version":"1\.14\.1"'; then
      echo "axios@1.14.1"
      return 0
    fi

    if fileContains "${candidatePath}" '"version":"0\.30\.4"'; then
      echo "axios@0.30.4"
      return 0
    fi

    if fileContains "${candidatePath}" '"dist-tags":\{[^}]*"latest":"1\.14\.1"'; then
      echo "axios@latest->1.14.1"
      return 0
    fi

    if fileContains "${candidatePath}" '"dist-tags":\{[^}]*"legacy":"0\.30\.4"'; then
      echo "axios@legacy->0.30.4"
      return 0
    fi
  fi

  if fileContains "${candidatePath}" 'axios@1\.14\.1'; then
    echo "axios@1.14.1"
    return 0
  fi

  if fileContains "${candidatePath}" 'axios@0\.30\.4'; then
    echo "axios@0.30.4"
    return 0
  fi

  if fileContains "${candidatePath}" 'axios@latest' && fileContains "${candidatePath}" 'version["'\'']?[[:space:]]+["'\'']1\.14\.1'; then
    echo "axios@latest->1.14.1"
    return 0
  fi

  if fileContains "${candidatePath}" 'axios@legacy' && fileContains "${candidatePath}" 'version["'\'']?[[:space:]]+["'\'']0\.30\.4'; then
    echo "axios@legacy->0.30.4"
    return 0
  fi

  return 1
}

function recordSummaryForInfection() {
  local candidatePath="$1"
  local infectionType="$2"

  addSummaryLine "$(basename "${candidatePath}") | ${candidatePath} | ${infectionType}"
}

function printValidatedMatches() {
  local candidatePath="$1"
  local infectionType="$2"
  local outputPath="$(createTempFile)"
  local validationPattern="$(getValidationPattern "${infectionType}")"
  local grepExitCode="0"
  local -a grepArgs=(
    -I -a -n -H -E
    "${validationPattern}"
    "${candidatePath}"
  )

  if [[ "${VERBOSE}" -eq 1 ]]; then
    grepArgs=(
      -I -a -n -H -E
      -C "${CONTEXT_LINES}"
      "${validationPattern}"
      "${candidatePath}"
    )
  fi

  grepExitCode=0
  runCommand grep "${grepArgs[@]}" > "${outputPath}" 2>/dev/null || grepExitCode="$?"

  if [[ "${grepExitCode}" -eq 0 ]]; then
    if [[ "${VERBOSE}" -eq 1 ]]; then
      printFileWithContext "${outputPath}"
    else
      printCompactMatches "${outputPath}"
    fi
  fi

  cleanupTempFile "${outputPath}"
}

function scanCandidateContent() {
  local candidatePath="$1"
  hasBroadCandidateSignal "${candidatePath}"
}

function scanCollectedCandidates() {
  local targetPath="$1"
  local candidateListPath="$2"
  local candidatePath=""
  local infectionType=""
  local foundMatch="1"

  while IFS= read -r candidatePath; do
    [[ -n "${candidatePath}" ]] || continue

    if ! scanCandidateContent "${candidatePath}"; then
      continue
    fi

    echo "Possible target identified for further scan: ${candidatePath}"
    echo "Validating target: ${candidatePath}"

    infectionType="$(detectInfectionType "${candidatePath}" || true)"

    if [[ -z "${infectionType}" ]]; then
      FALSE_POSITIVE_COUNT="$((FALSE_POSITIVE_COUNT + 1))"
      echo "[ ] False positive: ${candidatePath}"
      continue
    fi

    echo "[!] Confirmed infected target: ${candidatePath} (${infectionType})"
    printValidatedMatches "${candidatePath}" "${infectionType}"
    recordSummaryForInfection "${candidatePath}" "${infectionType}"
    foundMatch="0"
  done < "${candidateListPath}"
  echo ""
  return "${foundMatch}"
}

function scanPath() {
  local targetPath="$1"
  local candidateListPath="$(createTempFile)"
  local foundMatch="1"

  collectCandidateFiles "${targetPath}" "${candidateListPath}"
  [[ -s "${candidateListPath}" ]] || {
    cleanupTempFile "${candidateListPath}"
    return 1
  }

  if scanCollectedCandidates "${targetPath}" "${candidateListPath}"; then
    foundMatch="0"
  fi

  cleanupTempFile "${candidateListPath}"
  return "${foundMatch}"
}

function parseArgs() {
  local optionName=""
  local optionValue=""

  while [[ $# > 0 ]]; do
    case "$1" in
      --project|--folder)
        [[ $# -ge 2 ]] || showHelp 1 "Missing value for $1"
        optionName="$1"
        optionValue="$(trim "$2")"
        [[ -n "${optionValue}" ]] || showHelp 1 "Empty value for ${optionName}"
        EXTRA_DIRS+=("${optionValue}")
        shift 2
        ;;
      --verbose)
        VERBOSE="1"
        shift
        ;;
      -v*)
        VERBOSE="1"
        shift
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
  local extraDir=""

  for extraDir in "${EXTRA_DIRS[@]}"; do
    if [[ -d "${extraDir}" ]]; then
      continue
    fi
    showHelp 1 "Directory not found: ${extraDir}"
  done
}

function main() {
  local searchDir=""
  local scannedCount="0"
  local matchedCount="0"

  parseArgs "$@"
  validateInputs
  discoverSearchDirs

  if [[ ${#SEARCH_DIRS[@]} -eq 0 ]]; then
    logWarn "No known cache or project directories were found to scan."
    exit 1
  fi

  logInfo "Scanning ${#SEARCH_DIRS[@]} directories from ${WORK_DIR}"
  echo ""

  for searchDir in "${SEARCH_DIRS[@]}"; do
    scannedCount="$((scannedCount + 1))"
    logInfo "Scanning directory ${scannedCount}/${#SEARCH_DIRS[@]}: ${searchDir}"
    if ! scanPath "${searchDir}"; then
      continue
    fi
    matchedCount="$((matchedCount + 1))"
  done

  if [[ "${matchedCount}" -eq 0 ]]; then
    logSuccess "No infected files found. scanned=${scannedCount} infected=${matchedCount}"
    printSummary
    exit 1
  fi

  echo "[!] Confirmed infected files found. scanned=${scannedCount} infected=${matchedCount}"
  printSummary
}

main "$@"
