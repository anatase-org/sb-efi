ARG FEDORA_VERSION=44
FROM registry.fedoraproject.org/fedora:${FEDORA_VERSION}

RUN <<'EOF'
set -eux
packages="$(
    sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' <<'PACKAGES'
# Base RPM and source-fetch tooling.
curl
fedpkg
git-core
redhat-rpm-config
rpm-build
rpmdevtools
rpmautospec

# fwupd-efi build dependencies.
gcc
gnu-efi-devel
meson
nss-tools
opensc
pcsc-lite-libs
pesign
python3
python3-pefile

# grub2 build dependencies.
autoconf
automake
binutils
bison
bzip2-devel
dejavu-sans-fonts
device-mapper-devel
efi-srpm-macros
flex
freetype-devel
fuse3-devel
gettext-devel
git
help2man
ncurses-devel
rpm-devel
rpm-libs
squashfs-tools
systemd-rpm-macros
texinfo
xz-devel

# Kernel
fedpkg fedora-packager rpmdevtools ncurses-devel pesign opensc
asciidoc audit-libs-devel bc bindgen binutils-devel bison clang dwarves
elfutils-devel flex fuse-devel gcc gcc-c++ gettext glibc-static hostname
java-devel kernel-rpm-macros libbabeltrace-devel libbpf-devel ccache
libcap-devel libcap-ng-devel libmnl-devel libnl3-devel libtraceevent-devel
libtracefs-devel lld llvm-devel lvm2 m4 make net-tools newt-devel
numactl-devel openssl openssl-devel pciutils-devel perl perl-devel
perl-generators python3-devel python3-docutils rsync rust rust-src
systemd-boot-unsigned systemd-ukify which xmlto xz-devel zlib-devel
python3-requests hmaccalc dracut tpm2-tools rustfmt clippy bpftool
python3-jsonschema libxml2-devel swig opencsd-devel automake
libtool libtirpc libtirpc-devel

# libkmsp11
which
zip
unzip
gcc-c++
libstdc++-static
p11-kit

PACKAGES
)"
dnf -y install ${packages}
rm -rf /var/cache/dnf
EOF

ARG BAZELISK_VERSION=1.26.0
ARG BAZELISK_LINUX_AMD64_SHA256=6539c12842ad76966f3d493e8f80d67caa84ec4a000e220d5459833c967c12bc
ARG BAZELISK_LINUX_ARM64_SHA256=54f85ef4c23393f835252cc882e5fea596e8ef3c4c2056b059f8067cd19f0351

RUN <<'EOF'
set -eux
case "$(uname -m)" in
    x86_64)
        bazelisk_arch=amd64
        bazelisk_sha256="${BAZELISK_LINUX_AMD64_SHA256}"
        ;;
    aarch64)
        bazelisk_arch=arm64
        bazelisk_sha256="${BAZELISK_LINUX_ARM64_SHA256}"
        ;;
    *)
        echo "unsupported Bazelisk architecture: $(uname -m)" >&2
        exit 1
        ;;
esac
curl -fL \
    "https://github.com/bazelbuild/bazelisk/releases/download/v${BAZELISK_VERSION}/bazelisk-linux-${bazelisk_arch}" \
    -o /usr/local/bin/bazelisk
printf '%s  /usr/local/bin/bazelisk\n' "${bazelisk_sha256}" | sha256sum -c -
chmod 0755 /usr/local/bin/bazelisk
EOF

ARG KMS_INTEGRATIONS_TAG=pkcs11-v1.9
ARG KMS_INTEGRATIONS_TAG_SHA=0ac563ef4d337a0b91a8861b176c41e87eac6198
ARG KMS_INTEGRATIONS_COMMIT=e01c9b66a4b1db63e42de956ae6b2cefde2fea67

RUN <<'EOF'
set -eux
git clone \
    --branch "${KMS_INTEGRATIONS_TAG}" \
    --depth 1 \
    https://github.com/GoogleCloudPlatform/kms-integrations.git \
    /tmp/kms-integrations
test "$(git -C /tmp/kms-integrations rev-parse "refs/tags/${KMS_INTEGRATIONS_TAG}")" = "${KMS_INTEGRATIONS_TAG_SHA}"
test "$(git -C /tmp/kms-integrations rev-parse "refs/tags/${KMS_INTEGRATIONS_TAG}^{}")" = "${KMS_INTEGRATIONS_COMMIT}"
test "$(git -C /tmp/kms-integrations rev-parse HEAD)" = "${KMS_INTEGRATIONS_COMMIT}"
cd /tmp/kms-integrations
CC=gcc CXX=g++ bazelisk build \
    --conlyopt=-Wno-error=discarded-qualifiers \
    --cxxopt=-include \
    --cxxopt=cstdint \
    --host_conlyopt=-Wno-error=discarded-qualifiers \
    --host_cxxopt=-include \
    --host_cxxopt=cstdint \
    //kmsp11/main:libkmsp11.so
install -D -m 0755 bazel-bin/kmsp11/main/libkmsp11.so /usr/local/lib64/pkcs11/libkmsp11.so
install -d -m 0755 /usr/local/lib
ln -sf ../lib64/pkcs11/libkmsp11.so /usr/local/lib/libkmsp11.so
strip --strip-unneeded /usr/local/lib64/pkcs11/libkmsp11.so || :
rm -rf /tmp/kms-integrations /root/.cache/bazel
EOF

RUN rm -rf /etc/pki/pesign && \
    install -d -m 0755 /etc/pki/pesign && \
    certutil -N -d sql:/etc/pki/pesign --empty-password && \
    install -d -m 0755 /usr/share/p11-kit/modules && \
    printf '%s\n' \
        '# Google Cloud KMS PKCS #11 module built from kms-integrations.' \
        'module: /usr/local/lib64/pkcs11/libkmsp11.so' \
        > /usr/share/p11-kit/modules/gcp-kms.module
