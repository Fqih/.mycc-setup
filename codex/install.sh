#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_SOURCE="${REPO_ROOT}/skills"
SKILL_DEST="${HOME}/.agents/skills"
CODEX_HOME_DIR="${CODEX_HOME:-${HOME}/.codex}"
CONFIG_DEST="${CODEX_HOME_DIR}/config.toml"

mkdir -p "${SKILL_DEST}" "${CODEX_HOME_DIR}"
cp -R "${SKILL_SOURCE}/." "${SKILL_DEST}/"

if [[ ! -e "${CONFIG_DEST}" ]]; then
  cp "${REPO_ROOT}/codex/config.toml.example" "${CONFIG_DEST}"
  echo "Created ${CONFIG_DEST}"
else
  echo "Kept existing ${CONFIG_DEST}"
fi

echo "Installed Codex skills to ${SKILL_DEST}"
echo "Repository instructions remain in ${REPO_ROOT}/AGENTS.md"
