#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-wham-docker-template}"

if [ ! -d "${TARGET_DIR}" ]; then
  echo "[ERROR] Directory not found: ${TARGET_DIR}"
  exit 1
fi

ZIP_NAME="${TARGET_DIR}.zip"
rm -f "${ZIP_NAME}"
zip -r "${ZIP_NAME}" "${TARGET_DIR}"

echo "[INFO] Created ${ZIP_NAME}"
