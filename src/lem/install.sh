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

# Lem needs a C++ compiler and xdg-utils beyond what roswell installs
install_extra_packages() {
    case ${ADJUSTED_ID} in
        debian)
            apt-get update -y
            apt-get -y install --no-install-recommends g++ tk-dev xdg-utils
            rm -rf /var/lib/apt/lists/*
            ;;
        rhel)
            dnf -y install gcc-c++ xdg-utils 2>/dev/null || yum -y install gcc-c++ xdg-utils
            ;;
        alpine)
            apk add g++ xdg-utils
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
    if [ "$(id -u)" -eq 0 ] && [ "$USERNAME" != "root" ]; then
        su - "$USERNAME" -c "$(printf '%q ' "$@")"
    else
        "$@"
    fi
}

install_extra_packages

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
