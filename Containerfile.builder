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
PACKAGES
)"
dnf -y install ${packages}
rm -rf /var/cache/dnf
EOF

RUN rm -rf /etc/pki/pesign && \
    install -d -m 0755 /etc/pki/pesign && \
    certutil -N -d sql:/etc/pki/pesign --empty-password
