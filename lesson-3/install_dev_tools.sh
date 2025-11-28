#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${LOG_FILE:-$(pwd)/install.log}"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==> $(date '+%Y-%m-%d %H:%M:%S') Starting environment bootstrap"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_apt() {
    if [ ! -f /etc/os-release ]; then
        echo "Unsupported system: /etc/os-release missing"
        exit 1
    fi
    # shellcheck disable=SC1091
    . /etc/os-release
    case "$ID" in
        ubuntu|debian|linuxmint|pop|elementary)
            return 0
            ;;
        *)
            echo "Unsupported distribution: $ID. Please install tools manually."
            exit 1
            ;;
    esac
}

SUDO=""
if [ "$EUID" -ne 0 ]; then
    if command_exists sudo; then
        SUDO="sudo"
    else
        echo "This script requires root privileges or sudo."
        exit 1
    fi
fi

APT_UPDATED=0
apt_update_once() {
    if [ "$APT_UPDATED" -eq 0 ]; then
        $SUDO apt-get update -y
        APT_UPDATED=1
    fi
}

install_pkg_if_missing() {
    local pkg="$1"
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        apt_update_once
        $SUDO apt-get install -y "$pkg"
    fi
}

install_docker() {
    if command_exists docker; then
        echo "Docker already installed: $(docker --version)"
        return
    fi
    require_apt
    install_pkg_if_missing ca-certificates
    install_pkg_if_missing curl
    install_pkg_if_missing gnupg
    install_pkg_if_missing lsb-release

    if [ ! -d /etc/apt/keyrings ]; then
        $SUDO install -m 0755 -d /etc/apt/keyrings
    fi
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
            $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
    fi

    local codename
    codename=$(. /etc/os-release && echo "$UBUNTU_CODENAME")
    if [ -z "$codename" ]; then
        codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
    fi
    if [ -z "$codename" ]; then
        echo "Cannot determine distro codename."
        exit 1
    fi

    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$codename stable" | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
    fi

    APT_UPDATED=0
    apt_update_once
    $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io
    $SUDO systemctl enable docker
    $SUDO systemctl start docker
}

install_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        echo "Docker Compose plugin already installed."
        return
    fi
    if command_exists docker-compose; then
        echo "docker-compose standalone already installed."
        return
    fi
    require_apt
    install_pkg_if_missing docker-compose-plugin
}

ensure_python() {
    local min_version="3.9"
    if command_exists python3; then
        local current
        current=$(python3 -c 'import platform; print(platform.python_version())')
        if python3 - "$min_version" "$current" <<'EOF'
import sys
from itertools import zip_longest

def to_tuple(version: str):
    return tuple(int(part) for part in version.split("."))

minimum = to_tuple(sys.argv[1])
current = to_tuple(sys.argv[2])
sys.exit(0 if current >= minimum else 1)
EOF
        then
            echo "Python >= $min_version already installed: $current"
            return
        fi
    fi
    require_apt
    apt_update_once
    $SUDO apt-get install -y python3.10 python3.10-venv python3-pip
    if [ ! -e /usr/bin/python3 ]; then
        $SUDO ln -sf /usr/bin/python3.10 /usr/bin/python3
    fi
}

ensure_pip() {
    if python3 -m pip --version >/dev/null 2>&1; then
        return
    fi
    require_apt
    install_pkg_if_missing python3-pip
}

ensure_python_packages() {
    local packages=(django torch torchvision pillow)
    for pkg in "${packages[@]}"; do
        if ! python3 - <<EOF >/dev/null 2>&1
import importlib
import pkgutil
import sys
pkg = "$pkg"
name = pkg.split("[")[0]
importlib.import_module(name)
EOF
        then
            python3 -m pip install --upgrade "$pkg"
        fi
    done
}

print_versions() {
    echo "---- Installed tool versions ----"
    command_exists docker && docker --version
    docker compose version >/dev/null 2>&1 && docker compose version
    command_exists docker-compose && docker-compose --version || true
    python3 --version || true
    python3 -m pip --version || true
    python3 -c "import django,torch,torchvision,PIL; print('Django', django.get_version()); print('torch', torch.__version__); print('torchvision', torchvision.__version__); print('Pillow', PIL.__version__)" || true
    echo "---------------------------------"
}

install_docker
install_docker_compose
ensure_python
ensure_pip
ensure_python_packages
print_versions

echo "==> $(date '+%Y-%m-%d %H:%M:%S') Finished environment bootstrap"

