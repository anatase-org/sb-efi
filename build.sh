#!/usr/bin/env bash
FEDORA_VERSION=${FEDORA_VERSION:-44}
ARCH=${ARCH:-$(uname -m)}

set -euo pipefail

if [ -f .env ]; then
    set -a
    . ./.env
    set +a
fi

PE_SIGNING_TOKEN=${PE_SIGNING_TOKEN:-}
PE_SIGNING_CERT=${PE_SIGNING_CERT:-}
PE_SIGNING_PIN=${PE_SIGNING_PIN:-0}
GCP_KMS_KEY=${GCP_KMS_KEY:-}
GCP_KMS_CERT=${GCP_KMS_CERT:-}
PUSH_IMAGE=${PUSH_IMAGE:-0}

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

RPM_IMAGE="ghcr.io/anatase-org/sb-efi:f${FEDORA_VERSION}-${ARCH}"

command -v podman >/dev/null 2>&1 || die "podman is required"

printf 'Using builder image %s\n' "${BUILDER_IMAGE}"

printf 'Building RPM artifact image %s\n' "${RPM_IMAGE}"

if [ -n "${GCP_KMS_KEY}" ]; then
    [ -n "${PE_SIGNING_TOKEN}" ] || die "PE_SIGNING_TOKEN is required for signing"
    [ -n "${PE_SIGNING_CERT}" ] || die "PE_SIGNING_CERT is required for signing"
    require_bool PE_SIGNING_PIN "${PE_SIGNING_PIN}"
    [ "${PE_SIGNING_PIN}" = 0 ] || die "PE_SIGNING_PIN must be 0 when using GCP_KMS_KEY"
    [ -n "${GCP_KMS_CERT}" ] || die "GCP_KMS_CERT is required when using GCP_KMS_KEY"
    [ -f "${GCP_KMS_CERT}" ] || die "GCP_KMS_CERT does not exist: ${GCP_KMS_CERT}"

    case "${GCP_KMS_KEY}" in
        projects/*/locations/*/keyRings/*/cryptoKeys/*)
            gcp_kms_key_ring="${GCP_KMS_KEY%%/cryptoKeys/*}"
            ;;
        *)
            die "GCP_KMS_KEY must look like projects/PROJECT/locations/LOCATION/keyRings/RING/cryptoKeys/KEY[/cryptoKeyVersions/VERSION]"
            ;;
    esac

    adc_file="${GOOGLE_APPLICATION_CREDENTIALS:-${HOME}/.config/gcloud/application_default_credentials.json}"
    [ -f "${adc_file}" ] || die "Google ADC file not found at ${adc_file}; run gcloud auth application-default login or set GOOGLE_APPLICATION_CREDENTIALS"

    build_cmd=(
        podman build
        --pull=always
        --build-arg "FEDORA_VERSION=${FEDORA_VERSION}"
        --build-arg "ARCH=${ARCH}"
        --build-arg "BUILDER_IMAGE=${BUILDER_IMAGE}"
        --build-arg "PE_SIGNING_TOKEN=${PE_SIGNING_TOKEN}"
        --build-arg "PE_SIGNING_CERT=${PE_SIGNING_CERT}"
        --build-arg "PE_SIGNING_PIN=${PE_SIGNING_PIN}"
        --build-arg "GCP_KMS_KEY_RING=${gcp_kms_key_ring}"
        --env "FEDORA_VERSION=${FEDORA_VERSION}"
        -f Containerfile
        -t "${RPM_IMAGE}"
        --secret "id=gcp_kms_certificate,src=${GCP_KMS_CERT}"
        --secret "id=google_application_credentials,src=${adc_file}"
    )

    "${build_cmd[@]}" .
elif [ -n "${PE_SIGNING_TOKEN}" ] || [ -n "${PE_SIGNING_CERT}" ]; then
    [ -n "${PE_SIGNING_TOKEN}" ] || die "PE_SIGNING_TOKEN is required for signing"
    [ -n "${PE_SIGNING_CERT}" ] || die "PE_SIGNING_CERT is required for signing"
    require_bool PE_SIGNING_PIN "${PE_SIGNING_PIN}"
    [ -z "${GCP_KMS_CERT}" ] || die "GCP_KMS_CERT requires GCP_KMS_KEY"
    [ -S /run/pcscd/pcscd.comm ] || die "pcscd socket not found at /run/pcscd/pcscd.comm"

    build_cmd=(
        podman build
        --pull=always
        --build-arg "FEDORA_VERSION=${FEDORA_VERSION}"
        --build-arg "ARCH=${ARCH}"
        --build-arg "BUILDER_IMAGE=${BUILDER_IMAGE}"
        --build-arg "PE_SIGNING_TOKEN=${PE_SIGNING_TOKEN}"
        --build-arg "PE_SIGNING_CERT=${PE_SIGNING_CERT}"
        --build-arg "PE_SIGNING_PIN=${PE_SIGNING_PIN}"
        --env "FEDORA_VERSION=${FEDORA_VERSION}"
        -f Containerfile
        -t "${RPM_IMAGE}"
        --volume /run/pcscd:/run/pcscd
    )

    if [ "${PE_SIGNING_PIN}" = 1 ]; then
        read -r -s -p "Enter Pin: " PIN
        printf '\n'
        export PIN
        build_cmd=(
            "${build_cmd[@]}"
            --secret "id=pe_signing_pin,env=PIN"
        )
    fi

    "${build_cmd[@]}" .
else
    [ "${PE_SIGNING_PIN}" = 0 ] || die "PE_SIGNING_PIN=1 requires PE_SIGNING_TOKEN and PE_SIGNING_CERT"
    [ -z "${GCP_KMS_CERT}" ] || die "GCP_KMS_CERT requires GCP_KMS_KEY"
    podman build \
        --pull=always \
        --build-arg "FEDORA_VERSION=${FEDORA_VERSION}" \
        --build-arg "ARCH=${ARCH}" \
        --build-arg "BUILDER_IMAGE=${BUILDER_IMAGE}" \
        --build-arg "PE_SIGNING_TOKEN=${PE_SIGNING_TOKEN}" \
        --build-arg "PE_SIGNING_CERT=${PE_SIGNING_CERT}" \
        --build-arg "PE_SIGNING_PIN=${PE_SIGNING_PIN}" \
        --env "FEDORA_VERSION=${FEDORA_VERSION}" \
        -f Containerfile \
        -t "${RPM_IMAGE}" \
        .
fi

if [ "${PUSH_IMAGE}" = 1 ]; then
    printf 'Pushing RPM artifact image %s\n' "${RPM_IMAGE}"
    podman push "${RPM_IMAGE}"
fi
