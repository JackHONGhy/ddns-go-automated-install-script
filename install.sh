#!/usr/bin/env bash
set -euo pipefail

DDNS_GO_REPO="${DDNS_GO_REPO:-jeessy2/ddns-go}"
INSTALL_DIR="${INSTALL_DIR:-/opt/ddns-go}"
SERVICE_NAME="${SERVICE_NAME:-ddns-go}"
LATEST_URL="https://github.com/${DDNS_GO_REPO}/releases/latest"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
  echo "This installer must be run as root." >&2
  exit 1
fi

if [ "$(uname -s)" != "Linux" ]; then
  echo "This installer supports Linux only. Current system: $(uname -s)" >&2
  exit 1
fi

SYSTEM_ARCH="$(uname -m)"
case "${SYSTEM_ARCH}" in
  x86_64|amd64)
    ASSET_ARCH="x86_64"
    ;;
  aarch64|arm64)
    ASSET_ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: ${SYSTEM_ARCH}" >&2
    echo "Supported architectures: x86_64/amd64, aarch64/arm64" >&2
    exit 1
    ;;
esac

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_cmd curl
need_cmd tar
need_cmd systemctl
need_cmd grep
need_cmd find

echo "System detected: Linux"
echo "System architecture detected: ${SYSTEM_ARCH}"
echo "Matched ddns-go package architecture: linux_${ASSET_ARCH}"
echo

echo "Fetching latest ddns-go release version..."
if ! EFFECTIVE_URL="$(curl -fsSL --retry 3 --connect-timeout 15 -o /dev/null -w '%{url_effective}' "${LATEST_URL}")"; then
  echo "Unable to access ddns-go latest release page: ${LATEST_URL}" >&2
  exit 1
fi

VERSION="${EFFECTIVE_URL##*/}"

if [ -z "${VERSION}" ] || [ "${VERSION}" = "latest" ] || ! printf '%s' "${VERSION}" | grep -Eq '^v?[0-9]'; then
  echo "Unable to resolve latest ddns-go version from: ${EFFECTIVE_URL}" >&2
  exit 1
fi

VERSION_NUMBER="${VERSION#v}"
ASSET_NAME="ddns-go_${VERSION_NUMBER}_linux_${ASSET_ARCH}.tar.gz"
ASSET_URL="https://github.com/${DDNS_GO_REPO}/releases/download/${VERSION}/${ASSET_NAME}"
echo "Latest version: ${VERSION}"
echo "Selected package: ${ASSET_NAME}"
echo

if ! curl -fIL --retry 3 --connect-timeout 15 -o /dev/null "${ASSET_URL}"; then
  echo "Unable to access ddns-go package: ${ASSET_URL}" >&2
  exit 1
fi

read -r -p "Enter ddns-go web port, for example 50897: " WEB_PORT
WEB_PORT="${WEB_PORT#:}"
if ! printf '%s' "${WEB_PORT}" | grep -Eq '^[0-9]{1,5}$' || [ "${WEB_PORT}" -lt 1 ] || [ "${WEB_PORT}" -gt 65535 ]; then
  echo "Invalid port: ${WEB_PORT}" >&2
  exit 1
fi
LISTEN_ADDR=":${WEB_PORT}"

echo
echo "Installing ddns-go ${VERSION} for linux_${ASSET_ARCH}..."
echo "Web listen address: ${LISTEN_ADDR}"
echo

curl -fL --retry 3 --connect-timeout 15 -o "${TMP_DIR}/${ASSET_NAME}" "${ASSET_URL}"
tar -xzf "${TMP_DIR}/${ASSET_NAME}" -C "${TMP_DIR}"

DDNS_BIN="$(find "${TMP_DIR}" -type f -name ddns-go | head -n 1)"
if [ -z "${DDNS_BIN}" ]; then
  echo "Unable to find ddns-go binary in ${ASSET_NAME}." >&2
  exit 1
fi

if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
  echo "Stopping existing ${SERVICE_NAME} service..."
  systemctl stop "${SERVICE_NAME}"
fi

mkdir -p "${INSTALL_DIR}"
install -m 0755 "${DDNS_BIN}" "${INSTALL_DIR}/ddns-go"
ln -sf "${INSTALL_DIR}/ddns-go" /usr/local/bin/ddns-go

echo "Installing systemd service..."
"${INSTALL_DIR}/ddns-go" -s install -l "${LISTEN_ADDR}"
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"

echo
echo "ddns-go installed successfully."
echo "Version: ${VERSION}"
echo "Architecture: linux_${ASSET_ARCH}"
echo "Install directory: ${INSTALL_DIR}"
echo "Web address: http://SERVER_IP${LISTEN_ADDR}"
echo
echo "Useful commands:"
echo "  systemctl status ${SERVICE_NAME} --no-pager -l"
echo "  journalctl -u ${SERVICE_NAME}.service -e --no-pager -f"
echo "  ddns-go -h"
