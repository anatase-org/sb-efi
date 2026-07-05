ARG BUILDER_IMAGE
FROM ${BUILDER_IMAGE} AS fwupd-efi-build

ARG FEDORA_VERSION=44
ARG PE_SIGNING_TOKEN=
ARG PE_SIGNING_CERT=
ARG PE_SIGNING_PIN=0
ARG GCP_KMS_KEY_RING=
COPY . /work
WORKDIR /work/fwupd-efi

RUN --mount=type=secret,id=pe_signing_pin \
    --mount=type=secret,id=google_application_credentials \
    --mount=type=secret,id=gcp_kms_certificate \
    set -eux; \
    if [ -n "${PE_SIGNING_TOKEN:-}" ] || [ -n "${PE_SIGNING_CERT:-}" ]; then \
        : > /root/.rpmmacros; \
        if [ -n "${PE_SIGNING_TOKEN:-}" ]; then printf '%%pe_signing_token %s\n' "${PE_SIGNING_TOKEN}" >> /root/.rpmmacros; fi; \
        if [ -n "${PE_SIGNING_CERT:-}" ]; then printf '%%pe_signing_cert %s\n' "${PE_SIGNING_CERT}" >> /root/.rpmmacros; fi; \
        printf '%%_pesign /usr/local/bin/pesign-with-pin\n' >> /root/.rpmmacros; \
        rm -f /run/pesign/socket /var/run/pesign/socket; \
        if [ -n "${GCP_KMS_KEY_RING}" ]; then \
            install -d -m 0700 /run/kmsp11; \
            { \
                printf '%s\n' '---' 'tokens:' "  - key_ring: \"${GCP_KMS_KEY_RING}\"" "    label: \"${PE_SIGNING_TOKEN}\""; \
                if [ -s /run/secrets/gcp_kms_certificate ]; then \
                    printf '%s\n' '    certs:' '      - |'; \
                    sed 's/^/        /' /run/secrets/gcp_kms_certificate; \
                fi; \
            } > /run/kmsp11/config.yaml; \
            chmod 0600 /run/kmsp11/config.yaml; \
            export KMS_PKCS11_CONFIG=/run/kmsp11/config.yaml; \
            if [ -s /run/secrets/google_application_credentials ]; then export GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/google_application_credentials; fi; \
        fi; \
        if [ "${PE_SIGNING_PIN}" = 1 ]; then \
            [ -s /run/secrets/pe_signing_pin ]; \
            printf '#!/usr/bin/env bash\nexec /usr/bin/pesign --pinfile /run/secrets/pe_signing_pin "$@"\n' > /usr/local/bin/pesign-with-pin; \
        else \
            [ "${PE_SIGNING_PIN}" = 0 ]; \
            printf '#!/usr/bin/env bash\nexec /usr/bin/pesign "$@"\n' > /usr/local/bin/pesign-with-pin; \
        fi; \
        chmod 0755 /usr/local/bin/pesign-with-pin; \
    fi; \
    mkdir -p \
        /build/fwupd-efi/BUILD \
        /build/fwupd-efi/BUILDROOT \
        /build/fwupd-efi/RPMS \
        /build/fwupd-efi/SOURCES \
        /build/fwupd-efi/SPECS \
        /build/fwupd-efi/SRPMS \
        /srpms \
        /rpms; \
    fedpkg --release "f${FEDORA_VERSION}" --name fwupd-efi --namespace rpms sources; \
    rpmbuild -ba fwupd-efi.spec \
        --define "_topdir /build/fwupd-efi" \
        --define "_builddir /build/fwupd-efi/BUILD" \
        --define "_buildrootdir /build/fwupd-efi/BUILDROOT" \
        --define "_rpmdir /build/fwupd-efi/RPMS" \
        --define "_sourcedir /work/fwupd-efi" \
        --define "_specdir /work/fwupd-efi" \
        --define "_srcrpmdir /build/fwupd-efi/SRPMS"; \
    find /build/fwupd-efi/SRPMS -type f -name '*.rpm' -exec cp -t /srpms {} +; \
    find /build/fwupd-efi/RPMS -type f -name '*.rpm' -exec cp -t /rpms {} +

FROM ${BUILDER_IMAGE} AS grub2-build

ARG FEDORA_VERSION=44
ARG PE_SIGNING_TOKEN=
ARG PE_SIGNING_CERT=
ARG PE_SIGNING_PIN=0
ARG GCP_KMS_KEY_RING=
COPY . /work
WORKDIR /work/grub2

RUN --mount=type=secret,id=pe_signing_pin \
    --mount=type=secret,id=google_application_credentials \
    --mount=type=secret,id=gcp_kms_certificate \
    set -eux; \
    if [ -n "${PE_SIGNING_TOKEN:-}" ] || [ -n "${PE_SIGNING_CERT:-}" ]; then \
        : > /root/.rpmmacros; \
        if [ -n "${PE_SIGNING_TOKEN:-}" ]; then printf '%%pe_signing_token %s\n' "${PE_SIGNING_TOKEN}" >> /root/.rpmmacros; fi; \
        if [ -n "${PE_SIGNING_CERT:-}" ]; then printf '%%pe_signing_cert %s\n' "${PE_SIGNING_CERT}" >> /root/.rpmmacros; fi; \
        printf '%%_pesign /usr/local/bin/pesign-with-pin\n' >> /root/.rpmmacros; \
        rm -f /run/pesign/socket /var/run/pesign/socket; \
        if [ -n "${GCP_KMS_KEY_RING}" ]; then \
            install -d -m 0700 /run/kmsp11; \
            { \
                printf '%s\n' '---' 'tokens:' "  - key_ring: \"${GCP_KMS_KEY_RING}\"" "    label: \"${PE_SIGNING_TOKEN}\""; \
                if [ -s /run/secrets/gcp_kms_certificate ]; then \
                    printf '%s\n' '    certs:' '      - |'; \
                    sed 's/^/        /' /run/secrets/gcp_kms_certificate; \
                fi; \
            } > /run/kmsp11/config.yaml; \
            chmod 0600 /run/kmsp11/config.yaml; \
            export KMS_PKCS11_CONFIG=/run/kmsp11/config.yaml; \
            if [ -s /run/secrets/google_application_credentials ]; then export GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/google_application_credentials; fi; \
        fi; \
        if [ "${PE_SIGNING_PIN}" = 1 ]; then \
            [ -s /run/secrets/pe_signing_pin ]; \
            printf '#!/usr/bin/env bash\nexec /usr/bin/pesign --pinfile /run/secrets/pe_signing_pin "$@"\n' > /usr/local/bin/pesign-with-pin; \
        else \
            [ "${PE_SIGNING_PIN}" = 0 ]; \
            printf '#!/usr/bin/env bash\nexec /usr/bin/pesign "$@"\n' > /usr/local/bin/pesign-with-pin; \
        fi; \
        chmod 0755 /usr/local/bin/pesign-with-pin; \
    fi; \
    mkdir -p \
        /build/grub2/BUILD \
        /build/grub2/BUILDROOT \
        /build/grub2/RPMS \
        /build/grub2/SOURCES \
        /build/grub2/SPECS \
        /build/grub2/SRPMS \
        /srpms \
        /rpms; \
    fedpkg --release "f${FEDORA_VERSION}" --name grub2 --namespace rpms sources; \
    rpmbuild -ba grub2.spec \
        --define "_topdir /build/grub2" \
        --define "_builddir /build/grub2/BUILD" \
        --define "_buildrootdir /build/grub2/BUILDROOT" \
        --define "_rpmdir /build/grub2/RPMS" \
        --define "_sourcedir /work/grub2" \
        --define "_specdir /work/grub2" \
        --define "_srcrpmdir /build/grub2/SRPMS"; \
    find /build/grub2/SRPMS -type f -name '*.rpm' -exec cp -t /srpms {} +; \
    find /build/grub2/RPMS -type f -name '*.rpm' -exec cp -t /rpms {} +

FROM scratch
COPY --from=fwupd-efi-build /rpms/ /rpms/
COPY --from=grub2-build /rpms/ /rpms/
