#!/usr/bin/env bash
FEDORA_VERSION=${FEDORA_VERSION:-44}

set -euo pipefail

if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi

PE_SIGNING_TOKEN=${PE_SIGNING_TOKEN:-}
PE_SIGNING_CERT=${PE_SIGNING_CERT:-}

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

if [ -n "${PE_SIGNING_TOKEN}" ] || [ -n "${PE_SIGNING_CERT}" ]; then
    [ -n "${PE_SIGNING_TOKEN}" ] || die "PE_SIGNING_TOKEN is required for signing"
    [ -n "${PE_SIGNING_CERT}" ] || die "PE_SIGNING_CERT is required for signing"
    [ -S /run/pcscd/pcscd.comm ] || die "pcscd socket not found at /run/pcscd/pcscd.comm"
    read -r -s -p "Enter Pin: " pin
    printf '\n'
    podman build \
        --build-arg "FEDORA_VERSION=${FEDORA_VERSION}" \
        --build-arg "PE_SIGNING_TOKEN=${PE_SIGNING_TOKEN}" \
        --build-arg "PE_SIGNING_CERT=${PE_SIGNING_CERT}" \
        --secret id=pe_signing_pin,src=<(printf '%s\n' "${pin}") \
        --volume /run/pcscd:/run/pcscd \
        --env "FEDORA_VERSION=${FEDORA_VERSION}" \
        -f Containerfile \
        -t "${RPM_IMAGE}" \
        .
else
    podman build \
        --build-arg "FEDORA_VERSION=${FEDORA_VERSION}" \
        --build-arg "PE_SIGNING_TOKEN=${PE_SIGNING_TOKEN}" \
        --build-arg "PE_SIGNING_CERT=${PE_SIGNING_CERT}" \
        --env "FEDORA_VERSION=${FEDORA_VERSION}" \
        -f Containerfile \
        -t "${RPM_IMAGE}" \
        .
fi

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
