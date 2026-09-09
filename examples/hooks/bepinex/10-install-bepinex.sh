#!/usr/bin/env bash
set -euo pipefail

if [[ "${BEPINEX_ENABLED:-0}" != "1" ]]; then
  echo "BepInEx installer hook disabled (set BEPINEX_ENABLED=1 to enable)."
  exit 0
fi

if [[ -z "${BEPINEX_URL:-}" ]]; then
  echo "BEPINEX_URL is required when BEPINEX_ENABLED=1." >&2
  exit 1
fi

mkdir -p "${ASKA_SERVER_DIR}"
tmp_dir="$(mktemp -d)"
archive_path="${tmp_dir}/bepinex.zip"
cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

echo "Downloading BepInEx package from ${BEPINEX_URL}"
curl -fL "${BEPINEX_URL}" -o "${archive_path}"

if [[ -n "${BEPINEX_SHA256:-}" ]]; then
  echo "${BEPINEX_SHA256}  ${archive_path}" | sha256sum -c -
fi

echo "Extracting BepInEx into ${ASKA_SERVER_DIR}"
unzip -o "${archive_path}" -d "${ASKA_SERVER_DIR}"

if [[ -n "${BEPINEX_POST_INSTALL_CMD:-}" ]]; then
  echo "Running BEPINEX_POST_INSTALL_CMD"
  bash -lc "${BEPINEX_POST_INSTALL_CMD}"
fi

echo "BepInEx installer hook completed."
