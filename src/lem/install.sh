#!/usr/bin/env bash
# Installs Lem, the Common Lisp editor, via Roswell.
# Requires the roswell feature (declared in dependsOn).
# https://github.com/egao1980/features/tree/main/src/lem
set -e

LEM_VERSION="${VERSION:-"latest"}"
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root.' >&2
    exit 1
fi

# Roswell's containerEnv PATH only applies at runtime, not during build.
export PATH="/usr/local/roswell/current/bin:${PATH}"

# Bring in ID, ID_LIKE for distro-specific extra packages
. /etc/os-release

if [ "${ID}" = "debian" ] || [ "${ID_LIKE}" = "debian" ]; then
    ADJUSTED_ID="debian"
elif [[ "${ID}" = "rhel" || "${ID}" = "fedora" || "${ID_LIKE}" = *"rhel"* || "${ID_LIKE}" = *"fedora"* ]]; then
    ADJUSTED_ID="rhel"
elif [ "${ID}" = "alpine" ] || [ "${ID_LIKE}" = "alpine" ]; then
    ADJUSTED_ID="alpine"
else
    echo "Linux distro ${ID} not supported." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Lem needs a C++ compiler and xdg-utils beyond what roswell installs.
# webkitgtk/gtk4 are optional — only needed for the webview frontend (lem-sdl2).
# ncurses mode works without them. Install best-effort since older distros lack them.
install_extra_packages() {
    case ${ADJUSTED_ID} in
        debian)
            apt-get update -y
            apt-get -y install --no-install-recommends g++ tk-dev xdg-utils
            apt-get -y install --no-install-recommends libwebkitgtk-6.0-4 libgtk-4-1 2>/dev/null || true
            rm -rf /var/lib/apt/lists/*
            ;;
        rhel)
            dnf -y install gcc-c++ xdg-utils 2>/dev/null || yum -y install gcc-c++ xdg-utils
            dnf -y install webkit2gtk4.1 gtk4 2>/dev/null || true
            ;;
        alpine)
            apk add g++ xdg-utils
            apk add webkit2gtk-6.0 gtk4.0 2>/dev/null || true
            ;;
    esac
}

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    for u in vscode node codespace "$(awk -v val=1000 -F ':' '$3==val{print $1}' /etc/passwd)"; do
        if [ -n "$u" ] && id -u "$u" > /dev/null 2>&1; then
            USERNAME="$u"
            break
        fi
    done
    [ -z "${USERNAME}" ] && USERNAME=root
elif [ "${USERNAME}" = "none" ] || ! id -u "${USERNAME}" > /dev/null 2>&1; then
    USERNAME=root
fi

sudo_if() {
    local user_home
    if [ "$(id -u)" -eq 0 ] && [ "$USERNAME" != "root" ]; then
        user_home=$(eval echo "~${USERNAME}")
        su - "$USERNAME" -c "PATH=\"/usr/local/roswell/current/bin:\$PATH:${user_home}/.roswell/bin\" $(printf '%q ' "$@")"
    else
        export PATH="${PATH}:${HOME}/.roswell/bin"
        "$@"
    fi
}

install_extra_packages

# Lem's .asd requires deploy at parse time (:defsystem-depends-on).
# Pre-install it so ASDF can load the system definition.
sudo_if ros -e '(ql:quickload :deploy :silent t)' -q

case "${LEM_VERSION}" in
    latest)
        sudo_if ros follow-dependency=t install lem-project/lem
        sudo_if lem --version
        ;;
    none)
        echo "Skipping Lem installation."
        ;;
    *)
        sudo_if ros follow-dependency=t install "lem-project/lem/${LEM_VERSION}"
        sudo_if lem --version
        ;;
esac

echo "Done!"
