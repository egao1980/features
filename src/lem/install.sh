#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------
#
# Docs: https://github.com/microsoft/vscode-dev-containers/blob/main/script-library/docs/roswell.md
# Maintainer: The VS Code and Codespaces Teams

LEM_VERSION="${VERSION:-"latest"}" # 'system' or 'os-provided' checks the base image first, else installs 'latest'
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Bring in ID, ID_LIKE, VERSION_ID, VERSION_CODENAME
. /etc/os-release
# Get an adjusted ID independent of distro variants
MAJOR_VERSION_ID=$(echo ${VERSION_ID} | cut -d . -f 1)
if [ "${ID}" = "debian" ] || [ "${ID_LIKE}" = "debian" ]; then
    ADJUSTED_ID="debian"
elif [[ "${ID}" = "rhel" || "${ID}" = "fedora" || "${ID}" = "mariner" ||  "${ID}" = "alma" || "${ID_LIKE}" = *"alma"* || "${ID_LIKE}" = *"rhel"* || "${ID_LIKE}" = *"fedora"* || "${ID_LIKE}" = *"mariner"* ]]; then
    ADJUSTED_ID="rhel"
    if [[ "${ID}" = "rhel" ]] || [[ "${ID}" = *"alma"* ]] || [[ "${ID}" = *"rocky"* ]]; then
        VERSION_CODENAME="rhel${MAJOR_VERSION_ID}"
    else
        VERSION_CODENAME="${ID}${MAJOR_VERSION_ID}"
    fi
elif [ "${ID}" = "alpine" ] || [ "${ID_LIKE}" = "alpine" ]; then
    ADJUSTED_ID="alpine"
else
    echo "Linux distro ${ID} not supported."
    exit 1
fi

if [ "${ADJUSTED_ID}" = "rhel" ] && [ ${ID} != "rhel" ]; then
    # As of 1 July 2024, mirrorlist.centos.org no longer exists.
    # Update the repo files to reference vault.centos.org.
    sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
    sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
    sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
fi

# To find some devel packages, some rhel need to enable specific extra repos, but not on RedHat ubi images...
INSTALL_CMD_ADDL_REPO=""
if [ ${ADJUSTED_ID} = "rhel" ] && [ ${ID} != "rhel" ]; then
    if [ ${MAJOR_VERSION_ID} = "8" ]; then
        INSTALL_CMD_ADDL_REPOS="--enablerepo powertools"
    elif [ ${MAJOR_VERSION_ID} = "9" ]; then
        INSTALL_CMD_ADDL_REPOS="--enablerepo crb"
    fi
fi

# Setup INSTALL_CMD & PKG_MGR_CMD
if type apt-get > /dev/null 2>&1; then
    PKG_MGR_CMD=apt-get
    INSTALL_CMD="${PKG_MGR_CMD} -y install --no-install-recommends"
elif type microdnf > /dev/null 2>&1; then
    PKG_MGR_CMD=microdnf
    INSTALL_CMD="${PKG_MGR_CMD} ${INSTALL_CMD_ADDL_REPOS} -y install --refresh --best --nodocs --noplugins --setopt=install_weak_deps=0"
elif type dnf > /dev/null 2>&1; then
    PKG_MGR_CMD=dnf
    INSTALL_CMD="${PKG_MGR_CMD} ${INSTALL_CMD_ADDL_REPOS} -y install --refresh --best --nodocs --noplugins --setopt=install_weak_deps=0"
elif type apk > /dev/null 2>&1; then
    PKG_MGR_CMD=apk
    INSTALL_CMD="${PKG_MGR_CMD} add"
else
    PKG_MGR_CMD=yum
    INSTALL_CMD="${PKG_MGR_CMD} ${INSTALL_CMD_ADDL_REPOS} -y install --noplugins --setopt=install_weak_deps=0"
fi

# Clean up
clean_up() {
    case ${ADJUSTED_ID} in
        debian)
            rm -rf /var/lib/apt/lists/*
            ;;
        rhel)
            rm -rf /var/cache/dnf/* /var/cache/yum/*
            rm -rf /tmp/yum.log
            ;;
    esac
}
clean_up


updaterc() {
    local _bashrc
    local _zshrc
    if [ "${UPDATE_RC}" = "true" ]; then
        case $ADJUSTED_ID in
            alpine) echo "Updating /etc/bash/bashrc and /etc/zsh/zshrc..."
                _bashrc=/etc/bash/bashrc
                _zshrc=/etc/zsh/zshrc
                ;;
            debian) echo "Updating /etc/bash.bashrc and /etc/zsh/zshrc..."
                _bashrc=/etc/bash.bashrc
                _zshrc=/etc/zsh/zshrc
                ;;
            rhel) echo "Updating /etc/bashrc and /etc/zshrc..."
                _bashrc=/etc/bashrc
                _zshrc=/etc/zshrc
            ;;
        esac
        if [[ "$(cat ${_bashrc})" != *"$1"* ]]; then
            echo -e "$1" >> ${_bashrc}
        fi
        if [ -f "${_zshrc}" ] && [[ "$(cat ${_zshrc})" != *"$1"* ]]; then
            echo -e "$1" >> ${_zshrc}
        fi
    fi
}

# Figure out correct version of a three part version number is not passed
find_version_from_git_tags() {
    local variable_name=$1
    local requested_version=${!variable_name}
    if [ "${requested_version}" = "none" ]; then return; fi
    local repository=$2
    local prefix=${3:-"tags/v"}
    local separator=${4:-"."}
    local last_part_optional=${5:-"false"}
    if [ "$(echo "${requested_version}" | grep -o "." | wc -l)" != "2" ]; then
        local escaped_separator=${separator//./\\.}
        local last_part
        if [ "${last_part_optional}" = "true" ]; then
            last_part="(${escaped_separator}[0-9]+)?"
        else
            last_part="${escaped_separator}[0-9]+"
        fi
        local regex="${prefix}\\K[0-9]+${escaped_separator}[0-9]+${last_part}$"
        local version_list="$(git ls-remote --tags ${repository} | grep -oP "${regex}" | tr -d ' ' | tr "${separator}" "." | sort -rV)"
        if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "current" ] || [ "${requested_version}" = "lts" ]; then
            declare -g ${variable_name}="$(echo "${version_list}" | head -n 1)"
        else
            set +e
            declare -g ${variable_name}="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
            set -e
        fi
    fi
    if [ -z "${!variable_name}" ] || ! echo "${version_list}" | grep "^${!variable_name//./\\.}$" > /dev/null 2>&1; then
        echo -e "Invalid ${variable_name} value: ${requested_version}\nValid values:\n${version_list}" >&2
        exit 1
    fi
    echo "${variable_name}=${!variable_name}"
}

# Use semver logic to decrement a version number then look for the closest match
find_prev_version_from_git_tags() {
    local variable_name=$1
    local current_version=${!variable_name}
    local repository=$2
    # Normally a "v" is used before the version number, but support alternate cases
    local prefix=${3:-"tags/v"}
    # Some repositories use "_" instead of "." for version number part separation, support that
    local separator=${4:-"."}
    # Some tools release versions that omit the last digit (e.g. go)
    local last_part_optional=${5:-"false"}
    # Some repositories may have tags that include a suffix (e.g. actions/node-versions)
    local version_suffix_regex=$6
    # Try one break fix version number less if we get a failure. Use "set +e" since "set -e" can cause failures in valid scenarios.
    set +e
        major="$(echo "${current_version}" | grep -oE '^[0-9]+' || echo '')"
        minor="$(echo "${current_version}" | grep -oP '^[0-9]+\.\K[0-9]+' || echo '')"
        breakfix="$(echo "${current_version}" | grep -oP '^[0-9]+\.[0-9]+\.\K[0-9]+' 2>/dev/null || echo '')"

        if [ "${minor}" = "0" ] && [ "${breakfix}" = "0" ]; then
            ((major=major-1))
            declare -g ${variable_name}="${major}"
            # Look for latest version from previous major release
            find_version_from_git_tags "${variable_name}" "${repository}" "${prefix}" "${separator}" "${last_part_optional}"
        # Handle situations like Go's odd version pattern where "0" releases omit the last part
        elif [ "${breakfix}" = "" ] || [ "${breakfix}" = "0" ]; then
            ((minor=minor-1))
            declare -g ${variable_name}="${major}.${minor}"
            # Look for latest version from previous minor release
            find_version_from_git_tags "${variable_name}" "${repository}" "${prefix}" "${separator}" "${last_part_optional}"
        else
            ((breakfix=breakfix-1))
            if [ "${breakfix}" = "0" ] && [ "${last_part_optional}" = "true" ]; then
                declare -g ${variable_name}="${major}.${minor}"
            else
                declare -g ${variable_name}="${major}.${minor}.${breakfix}"
            fi
        fi
    set -e
}

pkg_mgr_update() {
    case $ADJUSTED_ID in
        debian)
            if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
                echo "Running apt-get update..."
                ${PKG_MGR_CMD} update -y
            fi
            ;;
        rhel)
            if [ ${PKG_MGR_CMD} = "microdnf" ]; then
                if [ "$(ls /var/cache/yum/* 2>/dev/null | wc -l)" = 0 ]; then
                    echo "Running ${PKG_MGR_CMD} makecache ..."
                    ${PKG_MGR_CMD} makecache
                fi
            else
                if [ "$(ls /var/cache/${PKG_MGR_CMD}/* 2>/dev/null | wc -l)" = 0 ]; then
                    echo "Running ${PKG_MGR_CMD} check-update ..."
                    set +e
                    ${PKG_MGR_CMD} check-update
                    rc=$?
                    if [ $rc != 0 ] && [ $rc != 100 ]; then
                        exit 1
                    fi
                    set -e
                fi
            fi
            ;;
    esac
}

# Checks if packages are installed and installs them if not
check_packages() {
    case ${ADJUSTED_ID} in
        debian)
            if ! dpkg -s "$@" > /dev/null 2>&1; then
                pkg_mgr_update
                ${INSTALL_CMD} "$@"
            fi
            ;;
        rhel)
            if ! rpm -q "$@" > /dev/null 2>&1; then
                pkg_mgr_update
                ${INSTALL_CMD} "$@"
            fi
            ;;
        alpine)
            if ! apk -e info "$@" > /dev/null 2>&1; then
                pkg_mgr_update
                ${INSTALL_CMD} "$@"
            fi
            ;;
    esac
}

sudo_if() {
    COMMAND="$*"
    echo "$COMMAND"
    if [ "$(id -u)" -eq 0 ] && [ "$USERNAME" != "root" ]; then
        su - "$USERNAME" -c "bash -l -c \"PATH=\"\$PATH:/usr/local/roswell/current/bin:\$HOME/.roswell/bin\" $COMMAND\""
    else
        PATH="$PATH:/usr/local/roswell/current/bin:$HOME/.roswell/bin"  $COMMAND
    fi
}

install_user_package() {
    INSTALL_UNDER_ROOT="$1"
    PACKAGE="$2"
    ROSWELL_HOME="/root/.roswell"
    if [ "$INSTALL_UNDER_ROOT" = false ]; then
        ROSWELL_HOME="/home/$USERNAME/.roswell"
    fi
    sudo_if ros follow-dependency=t install "$PACKAGE"
}

run_lisp() {
    INSTALL_UNDER_ROOT="$1"
    LISP_FILE="$2"

    ROSWELL_HOME="/root/.roswell"
    if [ "$INSTALL_UNDER_ROOT" = false ]; then
        ROSWELL_HOME="/home/$USERNAME/.roswell"
    fi

    sudo_if ros -l "$LISP_FILE"
}


# Ensure that login shells get the correct path if the user updated the PATH using ENV.
rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" > /etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh

# Some distributions do not install awk by default (e.g. Mariner)
if ! type awk >/dev/null 2>&1; then
    check_packages awk
fi

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u ${CURRENT_USER} > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

# Ensure apt is in non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# General requirements

REQUIRED_PKGS=""
case ${ADJUSTED_ID} in
    debian)
        REQUIRED_PKGS="${REQUIRED_PKGS} \
            automake \
            ca-certificates \
            curl \
            dirmngr \
            patchelf \
            gcc \
            g++ \
            libcurl4-openssl-dev \
            libffi-dev \
            libncurses5-dev \
            libreadline-dev \
            libsqlite3-dev \
            libssl-dev \
            make \
            tar \
            tk-dev \
            uuid-dev \
            xz-utils \
            zlib1g-dev"
        ;;
    alpine)
        REQUIRED_PKGS="${REQUIRED_PKGS} \
            git \
            gcompat \
            automake \
            autoconf \
            ca-certificates \
            curl \
            gcc \
            g++ \
            bzip2-dev \
            curl-dev \
            libffi-dev \
            ncurses-dev \
            readline-dev \
            sqlite-dev \
            openssl-dev \
            make \
            sbcl \
            tar \
            xz \
            zlib-dev"
        ;;
    rhel)
        REQUIRED_PKGS="${REQUIRED_PKGS} \
            automake \
            bzip2 \
            bzip2-devel \
            ca-certificates \
            findutils \
            gcc \
            gcc-c++ \
            gnupg2 \
            libcurl-devel \
            libffi-devel \
            make \
            ncurses-devel \
            openssl-devel \
            shadow-utils \
            tar \
            which \
            xz-devel \
            xz \
            zlib-devel"
        if ! type curl >/dev/null 2>&1; then
            REQUIRED_PKGS="${REQUIRED_PKGS} \
                curl"
        fi
        # Redhat ubi8 and ubi9 do not have some packages by default, only add them
        # if we're not on RedHat ...
        if [ ${ID} != "rhel" ]; then
            REQUIRED_PKGS="${REQUIRED_PKGS} \
                gdbm-devel \
                readline-devel \
                uuid-devel \
                xmlsec1-devel"
        fi
        ;;
esac

check_packages ${REQUIRED_PKGS}

INSTALL_UNDER_ROOT=true
if [ "$(id -u)" -eq 0 ] && [ "$USERNAME" != "root" ]; then
    INSTALL_UNDER_ROOT=false
fi

# Install Lem from source if needed
case "${LEM_VERSION}" in
    latest)
       install_user_package $INSTALL_UNDER_ROOT lem-project/lem
       sudo_if lem --version
       ;;
    none)
       echo "Skipping installation..."
       ;;
    *)
       install_user_package $INSTALL_UNDER_ROOT lem-project/lem/${LEM_VERSION}
       sudo_if lem --version
       ;;
esac

# Clean up
clean_up

echo "Done!"