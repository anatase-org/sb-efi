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

# fwupd build dependencies.
ModemManager-glib-devel
cairo-devel
cairo-gobject-devel
freetype
fontconfig
gettext
gi-docgen
glib2-devel
gnutls-devel
gnutls-utils
google-noto-sans-cjk-ttc-fonts
gobject-introspection-devel
hwdata
libblkid-devel
libcurl-devel
libdrm-devel
libmbim-devel
libmnl-devel
libqmi-devel
libusb1-devel
libxmlb-devel
meson
pango-devel
passim-devel
pkgconfig(bash-completion)
polkit
polkit-devel
python3
python3-cairo
python3-gobject
python3-jinja2
python3-packaging
readline-devel
sqlite-devel
systemd
systemd-devel
tpm2-tss-devel
vala
valgrind
valgrind-devel

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
gcc
gettext-devel
git
help2man
ncurses-devel
pesign
python3
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
