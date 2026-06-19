#!/usr/bin/env bash
FEDORA_VERSION=${FEDORA_VERSION:-44}

set -euo pipefail

BUILDER_IMAGE="sb-builder:f${FEDORA_VERSION}"
RPM_IMAGE="sb-rpms:f${FEDORA_VERSION}"
RPM_OUTPUT_DIR="rpms"

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

case "${FEDORA_VERSION}" in
    ''|*[!0-9]*)
        die "FEDORA_VERSION must be a Fedora release number"
        ;;
esac

command -v podman >/dev/null 2>&1 || die "podman is required"

if podman image exists "${BUILDER_IMAGE}"; then
    printf 'Using existing builder image %s\n' "${BUILDER_IMAGE}"
else
    printf 'Building builder image %s\n' "${BUILDER_IMAGE}"
    podman build \
        --build-arg "FEDORA_VERSION=${FEDORA_VERSION}" \
        --env "FEDORA_VERSION=${FEDORA_VERSION}" \
        -f Containerfile.builder \
        -t "${BUILDER_IMAGE}" \
        .
fi

printf 'Building RPM artifact image %s\n' "${RPM_IMAGE}"
podman build \
    --build-arg "FEDORA_VERSION=${FEDORA_VERSION}" \
    --env "FEDORA_VERSION=${FEDORA_VERSION}" \
    -f Containerfile \
    -t "${RPM_IMAGE}" \
    .

container_id=''
cleanup() {
    if [ -n "${container_id}" ]; then
        podman rm -f "${container_id}" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

mkdir -p "${RPM_OUTPUT_DIR}"
container_id="$(podman create "${RPM_IMAGE}")"
podman cp "${container_id}:/rpms/." "${RPM_OUTPUT_DIR}/"

printf 'Built %s and copied RPMs to ./%s/\n' "${RPM_IMAGE}" "${RPM_OUTPUT_DIR}"
