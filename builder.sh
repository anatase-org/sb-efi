#!/usr/bin/env bash
FEDORA_VERSION=${FEDORA_VERSION:-44}
ARCH=${ARCH:-$(uname -m)}
PUSH_IMAGE=${PUSH_IMAGE:-0}

set -euo pipefail

BUILDER_IMAGE="ghcr.io/anatase-org/sb-builder:f${FEDORA_VERSION}-${ARCH}"

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_bool() {
    case "${2}" in
        0|1)
            ;;
        *)
            die "${1} must be 0 or 1"
            ;;
    esac
}

case "${FEDORA_VERSION}" in
    ''|*[!0-9]*)
        die "FEDORA_VERSION must be a Fedora release number"
        ;;
esac

require_bool PUSH_IMAGE "${PUSH_IMAGE}"
command -v podman >/dev/null 2>&1 || die "podman is required"

printf 'Building builder image %s\n' "${BUILDER_IMAGE}"
podman build \
    --build-arg "FEDORA_VERSION=${FEDORA_VERSION}" \
    -f Containerfile.builder \
    -t "${BUILDER_IMAGE}" \
    .

if [ "${PUSH_IMAGE}" = 1 ]; then
    printf 'Pushing builder image %s\n' "${BUILDER_IMAGE}"
    podman push "${BUILDER_IMAGE}"
fi
