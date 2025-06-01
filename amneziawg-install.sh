#!/bin/bash

# AmneziaWG server installer
# https://github.com/varckin/amneziawg-install

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

AMNEZIAWG_DIR="/etc/amnezia/amneziawg"

function isRoot() {
    if [ "${EUID}" -ne 0 ]; then
        echo "You need to run this script as root"
        exit 1
    fi
}

function checkVirt() {
    if [ "$(systemd-detect-virt)" == "openvz" ]; then
        echo "OpenVZ is not supported"
        exit 1
    fi

    if [ "$(systemd-detect-virt)" == "lxc" ]; then
        echo "LXC is not supported (yet)."
        echo "WireGuard can technically run in an LXC container,"
        echo "but the kernel module has to be installed on the host,"
        echo "the container has to be run with some specific parameters"
        echo "and only the tools need to be installed in the container."
        exit 1
    fi
}

function checkOS() {
    source /etc/os-release
    OS="${ID}"
    if [[ ${OS} == "debian" || ${OS} == "raspbian" ]]; then
        if [[ ${VERSION_ID} -lt 11 ]]; then
            echo "Your version of Debian (${VERSION_ID}) is not supported. Please use Debian 11 Bullseye or later"
            exit 1
        fi
        OS=debian # overwrite if raspbian
    elif [[ ${OS} == "ubuntu" ]]; then
        RELEASE_YEAR=$(echo "${VERSION_ID}" | cut -d'.' -f1)
        if [[ ${RELEASE_YEAR} -lt 20 ]]; then
            echo "Your version of Ubuntu (${VERSION_ID}) is not supported. Please use Ubuntu 20.04 or later"
            exit 1
        fi
    elif [[ ${OS} == "fedora" ]]; then
        if [[ ${VERSION_ID} -lt 39 ]]; then
            echo "Your version of Fedora (${VERSION_ID}) is not supported. Please use Fedora 39 or later"
            exit 1
        fi
    elif [[ ${OS} == 'centos' ]] || [[ ${OS} == 'almalinux' ]] || [[ ${OS} == 'rocky' ]]; then
        if [[ ${VERSION_ID} == 7* ]] || [[ ${VERSION_ID} == 8* ]]; then
            echo "Your version of CentOS (${VERSION_ID}) is not supported. Please use CentOS 9 or later"
            exit 1
        fi
    else
        echo "Looks like you aren't running this installer on a Debian, Ubuntu, Fedora, CentOS, AlmaLinux or Rocky Linux system"
        exit 1
    fi
}

function getHomeDirForClient() {
    local CLIENT_NAME=$1

    if [ -z "${CLIENT_NAME}" ]; then
        echo "Error: getHomeDirForClient() requires a client name as argument"
        exit 1
    fi

    # Home directory of the user, where the client configuration will be written
    if [ -e "/home/${CLIENT_NAME}" ]; then
        # if $1 is a user name
        HOME_DIR="/home/${CLIENT_NAME}"
    elif [ "${SUDO_USER}" ]; then
        # if not, use SUDO_USER
        if [ "${SUDO_USER}" == "root" ]; then
            # If running sudo as root
            HOME_DIR="/root"
        else
            HOME_DIR="/home/${SUDO_USER}"
        fi
    else
        # if not SUDO_USER, use /root
        HOME_DIR="/root"
    fi

    echo "$HOME_DIR"
}

function initialCheck() {
    isRoot
    checkVirt
    checkOS
}

function readJminAndJmax() {
    SERVER_AWG_JMIN=0
    SERVER_AWG_JMAX=0
    until [[ ${SERVER_AWG_JMIN} =~ ^[0-9]+$ ]] && (( ${SERVER_AWG_JMIN} >= 1 )) && (( ${SERVER_AWG_JMIN} <= 1280 )); do
        read -rp "Server AmneziaWG Jmin [1-1280]: " -e -i 50 SERVER_AWG_JMIN
    done
    until [[ ${SERVER_AWG_JMAX} =~ ^[0-9]+$ ]] && (( ${SERVER_AWG_JMAX} >= 1 )) && (( ${SERVER_AWG_JMAX} <= 1280 )); do
        read -rp "Server AmneziaWG Jmax [1-1280]: " -e -i 1000 SERVER_AWG_JMAX
    done
}

function generateS1AndS2() {
    RANDOM_AWG_S1=$(shuf -i15-150 -n1)
    RANDOM_AWG_S2=$(shuf -i15-150 -n1)
}

function readS1AndS2() {
    SERVER_AWG_S1=0
    SERVER_AWG_S2=0
    until [[ ${SERVER_AWG_S1} =~ ^[0-9]+$ ]] && (( ${SERVER_AWG_S1} >= 15 )) && (( ${SERVER_AWG_S1} <= 150 )); do
        read -rp "Server AmneziaWG S1 [15-150]: " -e -i ${RANDOM_AWG_S1} SERVER_AWG_S1
    done
    until [[ ${SERVER_AWG_S2} =~ ^[0-9]+$ ]] && (( ${SERVER_AWG_S2} >= 15 )) && (( ${SERVER_AWG_S2} <= 150 )); do
        read -rp "Server AmneziaWG S2 [15-150]: " -e -i ${RANDOM_AWG_S2} SERVER_AWG_S2
    done
}

function generateH1AndH2AndH3AndH4() {
    RANDOM_AWG_H1=$(shuf -i5-2147483647 -n1)
    RANDOM_AWG_H2=$(shuf -i5-2147483647 -n1)
    RANDOM_AWG_H3=$(shuf -i5-2147483647 -n1)
    RANDOM_AWG_H4=$(shuf -i5-2147483647 -n1)
}

function readH1AndH2AndH3AndH4() {
    SERVER_AWG_H1=0
    SERVER_AWG_H2=0
    SERVER_AWG_H3=0
    SERVER_AWG_H4=0
    until [[ ${SERVER_AWG_H1} =~ ^[0-9]+$ ]] && (( ${SERVER_AWG_H1} >= 5 )) && (( ${SERVER_AWG_H1} <= 2147483647 )); do
        read -rp "Server AmneziaWG H1 [5-2147483647]: " -e -i ${RANDOM_AWG_H1} SERVER_AWG_H1
    done
    until [[ ${SERVER_AWG_H2} =~ ^[0-9]+$ ]] && (( ${SERVER_AWG_H2} >= 5 )) && (( ${SERVER_AWG_H2} <= 2147483647 )); do
        read -rp "Server AmneziaWG H2 [5-2147483647]: " -e -i ${RANDOM_AWG_H2} SERVER_AWG_H2
    done
    until [[ ${SERVER_AWG_H3} =~ ^[0-9]+$ ]] && (( ${SERVER_AWG_H3} >= 5 )) && (( ${SERVER_AWG_H3} <= 2147483647 )); do
        read -rp "Server AmneziaWG H3 [5-2147483647]: " -e -i ${RANDOM_AWG_H3} SERVER_AWG_H3
    done
    until [[ ${SERVER_AWG_H4} =~ ^[0-9]+$ ]] && (( ${SERVER_AWG_H4} >= 5 )) && (( ${SERVER_AWG_H4} <= 2147483647 )); do
        read -rp "Server AmneziaWG H4 [5-2147483647]: " -e -i ${RANDOM_AWG_H4} SERVER_AWG_H4
    done
}

function installQuestions() {
    echo "AmneziaWG server installer (https://github.com/varckin/amneziawg-install)"
    echo ""
    echo "I need to ask you a few questions before starting the setup."
    echo "You can keep the default options and just press enter if you are ok with them."
    echo ""

    # Detect public IPv4 or IPv6 address and pre-fill for the user
    SERVER_PUB_IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | awk '{print $1}' | head -1)
    if [[ -z ${SERVER_PUB_IP} ]]; then
        # Detect public IPv6 address
        SERVER_PUB_IP=$(ip -6 addr | sed -ne 's|^.* inet6 \([^/]*\)/.* scope global.*$|\1|p' | head -1)
    fi
    read -rp "Public IPv4 or IPv6 address or domain: " -e -i "${SERVER_PUB_IP}" SERVER_PUB_IP

    # Detect public interface and pre-fill for the user
    SERVER_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
    until [[ ${SERVER_PUB_NIC} =~ ^[a-zA-Z0-9_]+$ ]]; do
        read -rp "Public interface: " -e -i "${SERVER_NIC}" SERVER_PUB_NIC
    done

    until [[ ${SERVER_AWG_NIC} =~ ^[a-zA-Z0-9_]+$ && ${#SERVER_AWG_NIC} -lt 16 ]]; do
        read -rp "AmneziaWG interface name: " -e -i awg0 SERVER_AWG_NIC
    done

    until [[ ${SERVER_AWG_IPV4} =~ ^([0-9]{1,3}\.){3} ]]; do
        read -rp "Server AmneziaWG IPv4: " -e -i 10.66.66.1 SERVER_AWG_IPV4
    done

    until [[ ${SERVER_AWG_IPV6} =~ ^([a-f0-9]{1,4}:){3,4}: ]]; do
        read -rp "Server AmneziaWG IPv6: " -e -i fd42:42:42::1 SERVER_AWG_IPV6
    done

    # Generate random number within private ports range
    RANDOM_PORT=$(shuf -i49152-65535 -n1)
    until [[ ${SERVER_PORT} =~ ^[0-9]+$ ]] && [ "${SERVER_PORT}" -ge 1 ] && [ "${SERVER_PORT}" -le 65535 ]; do
        read -rp "Server AmneziaWG port [1-65535]: " -e -i "${RANDOM_PORT}" SERVER_PORT
    done

    # Adguard DNS by default
    until [[ ${CLIENT_DNS_1} =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; do
        read -rp "First DNS resolver to use for the clients: " -e -i 1.1.1.1 CLIENT_DNS_1
    done
    until [[ ${CLIENT_DNS_2} =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; do
        read -rp "Second DNS resolver to use for the clients (optional): " -e -i 1.0.0.1 CLIENT_DNS_2
        if [[ ${CLIENT_DNS_2} == "" ]]; then
            CLIENT_DNS_2="${CLIENT_DNS_1}"
        fi
    done

    until [[ ${ALLOWED_IPS} =~ ^.+$ ]]; do
        echo -e "\nAmneziaWG uses a parameter called AllowedIPs to determine what is routed over the VPN."
        read -rp "Allowed IPs list for generated clients (leave default to route everything): " -e -i '0.0.0.0/0,::/0' ALLOWED_IPS
        if [[ ${ALLOWED_IPS} == "" ]]; then
            ALLOWED_IPS="0.0.0.0/0,::/0"
        fi
    done

    # Jc
    RANDOM_AWG_JC=$(shuf -i3-10 -n1)
    until [[ ${SERVER_AWG_JC} =~ ^[0-9]+$ ]] && (( ${SERVER_AWG_JC} >= 1 )) && (( ${SERVER_AWG_JC} <= 128 )); do
        read -rp "Server AmneziaWG Jc [1-128]: " -e -i ${RANDOM_AWG_JC} SERVER_AWG_JC
    done

    # Jmin && Jmax
    readJminAndJmax
    until [ "${SERVER_AWG_JMIN}" -le "${SERVER_AWG_JMAX}" ]; do
        echo "AmneziaWG require Jmin < Jmax"
        readJminAndJmax
    done

    # S1 && S2
    generateS1AndS2
    while (( ${RANDOM_AWG_S1} + 56 == ${RANDOM_AWG_S2} )); do
        generateS1AndS2
    done
    readS1AndS2
    while (( ${SERVER_AWG_S1} + 56 == ${SERVER_AWG_S2} )); do
        echo "AmneziaWG require S1 + 56 <> S2"
        readS1AndS2
    done

    # H1 && H2 && H3 && H4
    generateH1AndH2AndH3AndH4
    while (( ${RANDOM_AWG_H1} == ${RANDOM_AWG_H2} )) || (( ${RANDOM_AWG_H1} == ${RANDOM_AWG_H3} )) || (( ${RANDOM_AWG_H1} == ${RANDOM_AWG_H4} )) || (( ${RANDOM_AWG_H2} == ${RANDOM_AWG_H3} )) || (( ${RANDOM_AWG_H2} == ${RANDOM_AWG_H4} )) || (( ${RANDOM_AWG_H3} == ${RANDOM_AWG_H4} )); do
        generateH1AndH2AndH3AndH4
    done
    readH1AndH2AndH3AndH4
    while (( ${SERVER_AWG_H1} == ${SERVER_AWG_H2} )) || (( ${SERVER_AWG_H1} == ${SERVER_AWG_H3} )) || (( ${SERVER_AWG_H1} == ${SERVER_AWG_H4} )) || (( ${SERVER_AWG_H2} == ${SERVER_AWG_H3} )) || (( ${SERVER_AWG_H2} == ${SERVER_AWG_H4} )) || (( ${SERVER_AWG_H3} == ${SERVER_AWG_H4} )); do
        echo "AmneziaWG require H1 and H2 and H3 and H4 be different"
        readH1AndH2AndH3AndH4
    done

    echo ""
    echo "Okay, that was all I needed. We are ready to setup your AmneziaWG server now."
    echo "You will be able to generate a client at the end of the installation."
    echo "This script will also install Go, build amneziawg-go and configure it as the userspace implementation."
    read -n1 -r -p "Press any key to continue..."
}

function installAmneziaWG() {
    # Run setup questions first
    installQuestions

    # Install AmneziaWG tools and module
    if [[ ${OS} == 'ubuntu' ]]; then
        if [[ -e /etc/apt/sources.list.d/ubuntu.sources ]]; then
            if ! grep -q "deb-src" /etc/apt/sources.list.d/ubuntu.sources; then
                cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/amneziawg.sources
                sed -i 's/deb/deb-src/' /etc/apt/sources.list.d/amneziawg.sources
            fi
        else
            if ! grep -q "^deb-src" /etc/apt/sources.list; then
                cp /etc/apt/sources.list /etc/apt/sources.list.d/amneziawg.sources.list
                sed -i 's/^deb/deb-src/' /etc/apt/sources.list.d/amneziawg.sources.list
            fi
        fi
        apt update # It's good practice to update before installing new packages
        apt install -y software-properties-common git build-essential
        add-apt-repository -y ppa:amnezia/ppa
        apt install -y amneziawg amneziawg-tools qrencode
    elif [[ ${OS} == 'debian' ]]; then
        if ! grep -q "^deb-src" /etc/apt/sources.list; then
            cp /etc/apt/sources.list /etc/apt/sources.list.d/amneziawg.sources.list
            sed -i 's/^deb/deb-src/' /etc/apt/sources.list.d/amneziawg.sources.list
        fi
        apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 57290828
        echo "deb https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" >>/etc/apt/sources.list.d/amneziawg.sources.list
        echo "deb-src https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu focal main" >>/etc/apt/sources.list.d/amneziawg.sources.list
        apt update
        apt install -y amneziawg amneziawg-tools qrencode iptables git build-essential
    elif [[ ${OS} == 'fedora' ]]; then
        dnf config-manager --set-enabled crb
        dnf install -y epel-release
        dnf copr enable -y amneziavpn/amneziawg
        dnf install -y amneziawg-dkms amneziawg-tools qrencode iptables git make gcc
    elif [[ ${OS} == 'centos' ]] || [[ ${OS} == 'almalinux' ]] || [[ ${OS} == 'rocky' ]]; then
        dnf config-manager --set-enabled crb
        dnf install -y epel-release
        dnf copr enable -y amneziavpn/amneziawg
        dnf install -y amneziawg-dkms amneziawg-tools qrencode iptables git make gcc
    fi

    SERVER_AWG_CONF="${AMNEZIAWG_DIR}/${SERVER_AWG_NIC}.conf"

    SERVER_PRIV_KEY=$(awg genkey)
    SERVER_PUB_KEY=$(echo "${SERVER_PRIV_KEY}" | awg pubkey)

    # Save WireGuard settings
    mkdir -p "${AMNEZIAWG_DIR}" # Ensure directory exists
    echo "SERVER_PUB_IP=${SERVER_PUB_IP}
SERVER_PUB_NIC=${SERVER_PUB_NIC}
SERVER_AWG_NIC=${SERVER_AWG_NIC}
SERVER_AWG_IPV4=${SERVER_AWG_IPV4}
SERVER_AWG_IPV6=${SERVER_AWG_IPV6}
SERVER_PORT=${SERVER_PORT}
SERVER_PRIV_KEY=${SERVER_PRIV_KEY}
SERVER_PUB_KEY=${SERVER_PUB_KEY}
CLIENT_DNS_1=${CLIENT_DNS_1}
CLIENT_DNS_2=${CLIENT_DNS_2}
ALLOWED_IPS=${ALLOWED_IPS}
SERVER_AWG_JC=${SERVER_AWG_JC}
SERVER_AWG_JMIN=${SERVER_AWG_JMIN}
SERVER_AWG_JMAX=${SERVER_AWG_JMAX}
SERVER_AWG_S1=${SERVER_AWG_S1}
SERVER_AWG_S2=${SERVER_AWG_S2}
SERVER_AWG_H1=${SERVER_AWG_H1}
SERVER_AWG_H2=${SERVER_AWG_H2}
SERVER_AWG_H3=${SERVER_AWG_H3}
SERVER_AWG_H4=${SERVER_AWG_H4}" >"${AMNEZIAWG_DIR}/params"

    # Add server interface
    echo "[Interface]
Address = ${SERVER_AWG_IPV4}/24,${SERVER_AWG_IPV6}/64
ListenPort = ${SERVER_PORT}
PrivateKey = ${SERVER_PRIV_KEY}
Jc = ${SERVER_AWG_JC}
Jmin = ${SERVER_AWG_JMIN}
Jmax = ${SERVER_AWG_JMAX}
S1 = ${SERVER_AWG_S1}
S2 = ${SERVER_AWG_S2}
H1 = ${SERVER_AWG_H1}
H2 = ${SERVER_AWG_H2}
H3 = ${SERVER_AWG_H3}
H4 = ${SERVER_AWG_H4}" >"${SERVER_AWG_CONF}"

    if pgrep firewalld; then
        FIREWALLD_IPV4_ADDRESS=$(echo "${SERVER_AWG_IPV4}" | cut -d"." -f1-3)".0"
        FIREWALLD_IPV6_ADDRESS=$(echo "${SERVER_AWG_IPV6}" | sed 's/:[^:]*$/:0/')
        echo "PostUp = firewall-cmd --add-port ${SERVER_PORT}/udp && firewall-cmd --add-rich-rule='rule family=ipv4 source address=${FIREWALLD_IPV4_ADDRESS}/24 masquerade' && firewall-cmd --add-rich-rule='rule family=ipv6 source address=${FIREWALLD_IPV6_ADDRESS}/64 masquerade'
PostDown = firewall-cmd --remove-port ${SERVER_PORT}/udp && firewall-cmd --remove-rich-rule='rule family=ipv4 source address=${FIREWALLD_IPV4_ADDRESS}/24 masquerade' && firewall-cmd --remove-rich-rule='rule family=ipv6 source address=${FIREWALLD_IPV6_ADDRESS}/64 masquerade'" >>"${SERVER_AWG_CONF}"
    else
        echo "PostUp = iptables -I INPUT -p udp --dport ${SERVER_PORT} -j ACCEPT
PostUp = iptables -I FORWARD -i ${SERVER_PUB_NIC} -o ${SERVER_AWG_NIC} -j ACCEPT
PostUp = iptables -I FORWARD -i ${SERVER_AWG_NIC} -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
PostUp = ip6tables -I INPUT -p udp --dport ${SERVER_PORT} -j ACCEPT
PostUp = ip6tables -I FORWARD -i ${SERVER_PUB_NIC} -o ${SERVER_AWG_NIC} -j ACCEPT
PostUp = ip6tables -I FORWARD -i ${SERVER_AWG_NIC} -j ACCEPT
PostUp = ip6tables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
PostDown = iptables -D INPUT -p udp --dport ${SERVER_PORT} -j ACCEPT
PostDown = iptables -D FORWARD -i ${SERVER_PUB_NIC} -o ${SERVER_AWG_NIC} -j ACCEPT
PostDown = iptables -D FORWARD -i ${SERVER_AWG_NIC} -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
PostDown = ip6tables -D INPUT -p udp --dport ${SERVER_PORT} -j ACCEPT
PostDown = ip6tables -D FORWARD -i ${SERVER_PUB_NIC} -o ${SERVER_AWG_NIC} -j ACCEPT
PostDown = ip6tables -D FORWARD -i ${SERVER_AWG_NIC} -j ACCEPT
PostDown = ip6tables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE" >>"${SERVER_AWG_CONF}"
    fi

    # Enable routing on the server
    echo "net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1" >/etc/sysctl.d/awg.conf

    sysctl --system

    systemctl start "awg-quick@${SERVER_AWG_NIC}"
    systemctl enable "awg-quick@${SERVER_AWG_NIC}"

    # <<< BEGINNING OF USER'S ADDED SECTION >>>
    echo -e "\n${GREEN}Installing Go and building amneziawg-go userspace implementation...${NC}"

    GO_VERSION="1.24.3" # 你可以根据需要更改 Go 版本
    AMNEZIAWG_GO_REPO_DIR="/root/amneziawg-go"
    AWG_GO_EXEC="${AMNEZIAWG_GO_REPO_DIR}/amneziawg-go"

    # 检测 CPU 架构
    ARCH=$(uname -m)
    GO_ARCH_SUFFIX=""

    case ${ARCH} in
        x86_64 | amd64)
            GO_ARCH_SUFFIX="amd64"
            echo "Detected x86_64/amd64 architecture."
            ;;
        aarch64 | arm64)
            GO_ARCH_SUFFIX="arm64"
            echo "Detected aarch64/arm64 architecture."
            ;;
        armv7l)
            # Go 官方为 32-bit ARMv7 通常使用 armv6l 的包 (带硬浮点)
            # 你需要确认 amneziawg-go 是否支持 32-bit ARM
            # 如果支持，可以使用 "armv6l"
            # GO_ARCH_SUFFIX="armv6l"
            # echo "Detected armv7l (32-bit ARM) architecture. Will attempt to use Go for armv6l."
            echo -e "${RED}Unsupported architecture: ${ARCH} (32-bit ARM). amneziawg-go might require 64-bit. Exiting.${NC}"
            exit 1
            ;;
        *)
            echo -e "${RED}Unsupported architecture: ${ARCH}. Cannot determine Go binary. Exiting.${NC}"
            exit 1
            ;;
    esac

    GO_TAR="go${GO_VERSION}.linux-${GO_ARCH_SUFFIX}.tar.gz"
    GO_URL="https://go.dev/dl/${GO_TAR}"

    # Install Go
    echo "Downloading Go ${GO_VERSION} for ${GO_ARCH_SUFFIX} from ${GO_URL}..."
    wget -O "/tmp/${GO_TAR}" "${GO_URL}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download Go. Please check the URL or network connection. Exiting.${NC}"
        echo -e "${RED}Attempted URL: ${GO_URL}${NC}"
        exit 1
    fi

    echo "Extracting Go..."
    # 先删除可能存在的旧的 Go 安装目录，避免冲突
    if [ -d "/usr/local/go" ]; then
        echo "Removing existing Go installation at /usr/local/go..."
        rm -rf /usr/local/go
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to remove existing Go installation. Please check permissions. Exiting.${NC}"
            exit 1
        fi
    fi
    tar -C /usr/local -xzf "/tmp/${GO_TAR}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to extract Go. Exiting.${NC}"
        exit 1
    fi
    rm "/tmp/${GO_TAR}"

    export PATH=/usr/local/go/bin:$PATH
    # 确保新路径生效，对于当前脚本执行而言，直接使用绝对路径或者在后续命令前加上go的路径更为稳妥
    # 例如：/usr/local/go/bin/go version
    # 或者在执行 make 前确保 PATH 被子 shell 继承
    echo "Go version: $(/usr/local/go/bin/go version)"
    if ! /usr/local/go/bin/go version &>/dev/null; then
        echo -e "${RED}Go installation failed or Go binary not found in PATH. Exiting.${NC}"
        exit 1
    fi


    # Clone and build amneziawg-go
    echo "Cloning amneziawg-go repository..."
    if [ -d "${AMNEZIAWG_GO_REPO_DIR}" ]; then
        echo "Found existing directory ${AMNEZIAWG_GO_REPO_DIR}, removing it."
        rm -rf "${AMNEZIAWG_GO_REPO_DIR}"
    fi
    git clone https://github.com/amnezia-vpn/amneziawg-go "${AMNEZIAWG_GO_REPO_DIR}"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to clone amneziawg-go repository. Exiting.${NC}"
        exit 1
    fi

    cd "${AMNEZIAWG_GO_REPO_DIR}"
    if [ $? -ne 0 ]; then # Check if cd was successful
        echo -e "${RED}Failed to change directory to ${AMNEZIAWG_GO_REPO_DIR}. Exiting.${NC}"
        exit 1
    fi

    echo "Building amneziawg-go..."
    # 确保 make 命令能找到正确的 go 执行文件
    # 如果 PATH 设置可能在子 shell 中不立即生效，可以显式指定
    # PATH=/usr/local/go/bin:$PATH make
    make # 脚本中的 export PATH 应该对后续命令有效
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to build amneziawg-go (make command failed). Exiting.${NC}"
        exit 1
    fi

    if [ ! -f "${AWG_GO_EXEC}" ]; then
        echo -e "${RED}Build failed: ${AWG_GO_EXEC} not found. Exiting.${NC}"
        exit 1
    else
        echo -e "${GREEN}amneziawg-go built successfully: ${AWG_GO_EXEC}${NC}"
    fi

    # Modify systemd service file for awg-quick
    SERVICE_FILE="/lib/systemd/system/awg-quick@.service"
    ENV_LINE_TO_ADD="Environment=WG_QUICK_USERSPACE_IMPLEMENTATION=${AWG_GO_EXEC}"
    ENV_LINE_PATTERN="^Environment=WG_QUICK_USERSPACE_IMPLEMENTATION=.*"

    echo "Modifying ${SERVICE_FILE} to use amneziawg-go..."
    # Check if the service file exists
    if [ ! -f "${SERVICE_FILE}" ]; then
        echo -e "${RED}Service file ${SERVICE_FILE} not found. Cannot configure userspace implementation. Exiting.${NC}"
        exit 1
    fi

    # Remove existing WG_QUICK_USERSPACE_IMPLEMENTATION line if it exists, to avoid duplicates
    if grep -q "${ENV_LINE_PATTERN}" "${SERVICE_FILE}"; then
        echo "Found existing userspace implementation line, removing it first."
        sed -i "\#${ENV_LINE_PATTERN}#d" "${SERVICE_FILE}"
    fi

    # Add the new Environment line after the [Service] section header
    # Using a temporary file for safer sed operation, though direct should be fine.
    awk -v env_line="${ENV_LINE_TO_ADD}" '1;/^\[Service\]/{print env_line}' "${SERVICE_FILE}" > "${SERVICE_FILE}.tmp" && mv "${SERVICE_FILE}.tmp" "${SERVICE_FILE}"
    # Alternative sed: sed -i "/^\[Service\]/a ${ENV_LINE_TO_ADD}" "${SERVICE_FILE}"
    # The awk approach is a bit more robust if [Service] is not the first line after comments.
    # For simplicity and directness as per original intent for sed:
    # sed -i "/^\[Service\]/a ${ENV_LINE_TO_ADD}" "${SERVICE_FILE}"
    # Let's re-verify sed for correct placement. The `a` command appends on the *next* line.
    # To be absolutely sure it's *within* [Service], it's common to look for [Service] then add.
    # Simpler sed for this case:
    if grep -q "^\[Service\]" "${SERVICE_FILE}"; then
         sed -i "/^\[Service\]/a ${ENV_LINE_TO_ADD}" "${SERVICE_FILE}"
    else
        echo -e "${RED}[Service] section not found in ${SERVICE_FILE}. Cannot add Environment line. Exiting.${NC}"
        exit 1
    fi


    echo "Reloading systemd daemon..."
    systemctl daemon-reload

    echo "Restarting awg-quick@${SERVER_AWG_NIC}.service..."
    systemctl restart "awg-quick@${SERVER_AWG_NIC}.service"

    echo -e "${GREEN}Checking status of awg-quick@${SERVER_AWG_NIC}.service with Go userspace implementation:${NC}"
    systemctl status "awg-quick@${SERVER_AWG_NIC}.service" --no-pager -l
    echo -e "${GREEN}Userspace Go implementation setup complete.${NC}"
    # <<< END OF USER'S ADDED SECTION >>>

    newClient
    echo -e "${GREEN}If you want to add more clients, you simply need to run this script another time!${NC}"

    # Check if AmneziaWG is running
    systemctl is-active --quiet "awg-quick@${SERVER_AWG_NIC}"
    AWG_RUNNING=$?

    # AmneziaWG might not work if we updated the kernel. Tell the user to reboot
    if [[ ${AWG_RUNNING} -ne 0 ]]; then
        echo -e "\n${RED}WARNING: AmneziaWG does not seem to be running.${NC}"
        echo -e "${ORANGE}You can check if AmneziaWG is running with: systemctl status awg-quick@${SERVER_AWG_NIC}${NC}"
        echo -e "${ORANGE}If you get something like \"Cannot find device ${SERVER_AWG_NIC}\", please reboot!${NC}"
        echo -e "${ORANGE}Also check the output of 'journalctl -u awg-quick@${SERVER_AWG_NIC}.service' for errors related to the Go userspace implementation.${NC}"
    else # AmneziaWG is running
        echo -e "\n${GREEN}AmneziaWG is running (hopefully with the Go userspace implementation).${NC}"
        echo -e "${GREEN}You can check the status of AmneziaWG with: systemctl status awg-quick@${SERVER_AWG_NIC}\n\n${NC}"
        echo -e "${ORANGE}If you don't have internet connectivity from your client, try to reboot the server.${NC}"
    fi
}

function newClient() {
    # If SERVER_PUB_IP is IPv6, add brackets if missing
    if [[ ${SERVER_PUB_IP} =~ .*:.* ]]; then
        if [[ ${SERVER_PUB_IP} != *"["* ]] || [[ ${SERVER_PUB_IP} != *"]"* ]]; then
            SERVER_PUB_IP="[${SERVER_PUB_IP}]"
        fi
    fi
    ENDPOINT="${SERVER_PUB_IP}:${SERVER_PORT}"

    echo ""
    echo "Client configuration"
    echo ""
    echo "The client name must consist of alphanumeric character(s). It may also include underscores or dashes and can't exceed 15 chars."

    CLIENT_NAME="" # Initialize to ensure loop condition is met first time
    CLIENT_EXISTS=1 # Initialize to ensure loop condition is met first time

    until [[ ${CLIENT_NAME} =~ ^[a-zA-Z0-9_-]+$ && ${CLIENT_EXISTS} == '0' && ${#CLIENT_NAME} -lt 16 ]]; do
        read -rp "Client name: " -e CLIENT_NAME
        CLIENT_EXISTS=$(grep -c -E "^### Client ${CLIENT_NAME}\$" "${SERVER_AWG_CONF}")

        if [[ ${CLIENT_EXISTS} != 0 ]]; then
            echo ""
            echo -e "${ORANGE}A client with the specified name was already created, please choose another name.${NC}"
            echo ""
        fi
    done

    for DOT_IP in {2..254}; do
        DOT_EXISTS=$(grep -c "${SERVER_AWG_IPV4::-1}${DOT_IP}" "${SERVER_AWG_CONF}")
        if [[ ${DOT_EXISTS} == '0' ]]; then
            break
        fi
    done

    if [[ ${DOT_EXISTS} == '1' ]]; then
        echo ""
        echo "The subnet configured supports only 253 clients."
        exit 1
    fi

    BASE_IP=$(echo "$SERVER_AWG_IPV4" | awk -F '.' '{ print $1"."$2"."$3 }')
    IPV4_EXISTS=1 # Initialize to ensure loop condition is met first time
    until [[ ${IPV4_EXISTS} == '0' ]]; do
        read -rp "Client AmneziaWG IPv4: ${BASE_IP}." -e -i "${DOT_IP}" DOT_IP_SUFFIX
        CLIENT_AWG_IPV4="${BASE_IP}.${DOT_IP_SUFFIX}" # Use different var name for suffix
        IPV4_EXISTS=$(grep -c "$CLIENT_AWG_IPV4/32" "${SERVER_AWG_CONF}")

        if [[ ${IPV4_EXISTS} != 0 ]]; then
            echo ""
            echo -e "${ORANGE}A client with the specified IPv4 was already created, please choose another IPv4.${NC}"
            echo ""
        fi
    done

    BASE_IP_V6=$(echo "$SERVER_AWG_IPV6" | awk -F '::' '{ print $1 }') # Use different var name
    IPV6_EXISTS=1 # Initialize to ensure loop condition is met first time
    # Use the same DOT_IP_SUFFIX from IPv4 as a suggestion for IPv6 client part
    until [[ ${IPV6_EXISTS} == '0' ]]; do
        read -rp "Client AmneziaWG IPv6: ${BASE_IP_V6}::" -e -i "${DOT_IP_SUFFIX}" DOT_IP_V6_SUFFIX
        CLIENT_AWG_IPV6="${BASE_IP_V6}::${DOT_IP_V6_SUFFIX}"
        IPV6_EXISTS=$(grep -c "${CLIENT_AWG_IPV6}/128" "${SERVER_AWG_CONF}")

        if [[ ${IPV6_EXISTS} != 0 ]]; then
            echo ""
            echo -e "${ORANGE}A client with the specified IPv6 was already created, please choose another IPv6.${NC}"
            echo ""
        fi
    done

    # Generate key pair for the client
    CLIENT_PRIV_KEY=$(awg genkey)
    CLIENT_PUB_KEY=$(echo "${CLIENT_PRIV_KEY}" | awg pubkey)
    CLIENT_PRE_SHARED_KEY=$(awg genpsk)

    HOME_DIR=$(getHomeDirForClient "${CLIENT_NAME}")

    # Create client file and add the server as a peer
    echo "[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${CLIENT_AWG_IPV4}/32,${CLIENT_AWG_IPV6}/128
DNS = ${CLIENT_DNS_1},${CLIENT_DNS_2}
Jc = ${SERVER_AWG_JC}
Jmin = ${SERVER_AWG_JMIN}
Jmax = ${SERVER_AWG_JMAX}
S1 = ${SERVER_AWG_S1}
S2 = ${SERVER_AWG_S2}
H1 = ${SERVER_AWG_H1}
H2 = ${SERVER_AWG_H2}
H3 = ${SERVER_AWG_H3}
H4 = ${SERVER_AWG_H4}

[Peer]
PublicKey = ${SERVER_PUB_KEY}
PresharedKey = ${CLIENT_PRE_SHARED_KEY}
Endpoint = ${ENDPOINT}
AllowedIPs = ${ALLOWED_IPS}" >"${HOME_DIR}/${SERVER_AWG_NIC}-client-${CLIENT_NAME}.conf"

    # Add the client as a peer to the server
    echo -e "\n### Client ${CLIENT_NAME}
[Peer]
PublicKey = ${CLIENT_PUB_KEY}
PresharedKey = ${CLIENT_PRE_SHARED_KEY}
AllowedIPs = ${CLIENT_AWG_IPV4}/32,${CLIENT_AWG_IPV6}/128" >>"${SERVER_AWG_CONF}"

    awg syncconf "${SERVER_AWG_NIC}" <(awg-quick strip "${SERVER_AWG_NIC}")

    # Generate QR code if qrencode is installed
    if command -v qrencode &>/dev/null; then
        echo -e "${GREEN}\nHere is your client config file as a QR Code:\n${NC}"
        qrencode -t ansiutf8 -l L <"${HOME_DIR}/${SERVER_AWG_NIC}-client-${CLIENT_NAME}.conf"
        echo ""
    fi

    echo -e "${GREEN}Your client config file is in ${HOME_DIR}/${SERVER_AWG_NIC}-client-${CLIENT_NAME}.conf${NC}"
}

function listClients() {
    loadParams # Ensure SERVER_AWG_CONF is set
    NUMBER_OF_CLIENTS=$(grep -c -E "^### Client" "${SERVER_AWG_CONF}")
    if [[ ${NUMBER_OF_CLIENTS} -eq 0 ]]; then
        echo ""
        echo "You have no existing clients!"
        exit 1
    fi

    grep -E "^### Client" "${SERVER_AWG_CONF}" | cut -d ' ' -f 3 | nl -s ') '
}

function revokeClient() {
    loadParams # Ensure SERVER_AWG_CONF and SERVER_AWG_NIC are set
    NUMBER_OF_CLIENTS=$(grep -c -E "^### Client" "${SERVER_AWG_CONF}")
    if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
        echo ""
        echo "You have no existing clients!"
        exit 1
    fi

    echo ""
    echo "Select the existing client you want to revoke"
    grep -E "^### Client" "${SERVER_AWG_CONF}" | cut -d ' ' -f 3 | nl -s ') '
    CLIENT_NUMBER=0 # Initialize
    until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
        if [[ ${NUMBER_OF_CLIENTS} -eq 1 ]]; then # Handle case of only one client
            read -rp "Select one client [1]: " CLIENT_NUMBER
        else
            read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
        fi
    done

    # match the selected number to a client name
    CLIENT_NAME=$(grep -E "^### Client" "${SERVER_AWG_CONF}" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)

    # remove [Peer] block matching $CLIENT_NAME
    sed -i "/^### Client ${CLIENT_NAME}\$/,/^$/d" "${SERVER_AWG_CONF}"

    # remove generated client file
    HOME_DIR=$(getHomeDirForClient "${CLIENT_NAME}")
    rm -f "${HOME_DIR}/${SERVER_AWG_NIC}-client-${CLIENT_NAME}.conf"

    # restart AmneziaWG to apply changes
    awg syncconf "${SERVER_AWG_NIC}" <(awg-quick strip "${SERVER_AWG_NIC}")
    echo -e "${GREEN}Client ${CLIENT_NAME} revoked.${NC}"
}

function uninstallAmneziaWG() {
    echo ""
    echo -e "\n${RED}WARNING: This will uninstall AmneziaWG and remove all the configuration files!${NC}"
    echo -e "${ORANGE}Please backup the ${AMNEZIAWG_DIR} directory if you want to keep your configuration files.\n${NC}"
    read -rp "Do you really want to remove AmneziaWG? [y/n]: " -e REMOVE
    REMOVE=${REMOVE:-n}
    if [[ $REMOVE == 'y' ]]; then
        checkOS # OS variable is needed
        loadParams # SERVER_AWG_NIC is needed

        systemctl stop "awg-quick@${SERVER_AWG_NIC}"
        systemctl disable "awg-quick@${SERVER_AWG_NIC}"

        # Disable routing
        rm -f /etc/sysctl.d/awg.conf
        sysctl --system

        # Remove config files
        rm -rf ${AMNEZIAWG_DIR}

        # Remove amneziawg-go directory
        if [ -d "/root/amneziawg-go" ]; then
            echo "Removing /root/amneziawg-go..."
            rm -rf "/root/amneziawg-go"
        fi
        # Optionally remove Go installation - decided against for now as it might be used by other apps
        # echo "Go (/usr/local/go) is not automatically removed. You can remove it manually if desired."

        # Revert systemd service file modification (optional, as package removal might replace it)
        SERVICE_FILE="/lib/systemd/system/awg-quick@.service"
        ENV_LINE_PATTERN="^Environment=WG_QUICK_USERSPACE_IMPLEMENTATION=.*"
        if [ -f "${SERVICE_FILE}" ] && grep -q "${ENV_LINE_PATTERN}" "${SERVICE_FILE}"; then
            echo "Removing userspace implementation line from ${SERVICE_FILE}..."
            sed -i "\#${ENV_LINE_PATTERN}#d" "${SERVICE_FILE}"
            systemctl daemon-reload
        fi

        if [[ ${OS} == 'ubuntu' ]]; then
            apt remove --purge -y amneziawg amneziawg-tools qrencode # Purge to remove configs too
            if command -v add-apt-repository &> /dev/null; then # Check if command exists
                add-apt-repository -ry ppa:amnezia/ppa
            fi
            if [[ -e /etc/apt/sources.list.d/ubuntu.sources ]]; then # file name was amneziawg.sources
                rm -f /etc/apt/sources.list.d/amneziawg.sources
            else # file name was amneziawg.sources.list
                rm -f /etc/apt/sources.list.d/amneziawg.sources.list
            fi
        elif [[ ${OS} == 'debian' ]]; then
            apt-get remove --purge -y amneziawg amneziawg-tools qrencode iptables # Purge
            rm -f /etc/apt/sources.list.d/amneziawg.sources.list
            if command -v apt-key &> /dev/null; then apt-key del 57290828 || true; fi # ignore error if key not found
            apt update
        elif [[ ${OS} == 'fedora' ]]; then
            dnf remove -y amneziawg-dkms amneziawg-tools qrencode iptables
            if command -v dnf &> /dev/null && dnf copr list | grep -q "amneziavpn/amneziawg"; then
                dnf copr disable -y amneziavpn/amneziawg
            fi
        elif [[ ${OS} == 'centos' ]] || [[ ${OS} == 'almalinux' ]] || [[ ${OS} == 'rocky' ]]; then
            dnf remove -y amneziawg-dkms amneziawg-tools qrencode iptables
            if command -v dnf &> /dev/null && dnf copr list | grep -q "amneziavpn/amneziawg"; then
                dnf copr disable -y amneziavpn/amneziawg
            fi
        fi

        echo "AmneziaWG uninstalled."
        echo "You might need to reboot for all changes to take full effect (e.g. kernel modules)."
        exit 0
    else
        echo ""
        echo "Removal aborted!"
    fi
}

function loadParams() {
    if [ ! -f "${AMNEZIAWG_DIR}/params" ]; then
        echo -e "${RED}Error: Parameters file ${AMNEZIAWG_DIR}/params not found.${NC}"
        echo "This can happen if the installation was not completed or if running uninstall without prior setup."
        # For uninstall, we might not need all params, but SERVER_AWG_NIC is crucial.
        # Attempt to find SERVER_AWG_NIC from active services if params are missing.
        if [[ -z "$SERVER_AWG_NIC" ]]; then
            FOUND_AWG_NIC=$(systemctl list-units --type=service --state=active --plain --no-legend | grep -oP 'awg-quick@\K[^.]+(?=.service)' | head -n 1)
            if [[ -n "$FOUND_AWG_NIC" ]]; then
                SERVER_AWG_NIC="$FOUND_AWG_NIC"
                echo -e "${ORANGE}Guessed SERVER_AWG_NIC as ${SERVER_AWG_NIC} from active services.${NC}"
            else
                # Try to find from existing config files if dir exists
                if [ -d "${AMNEZIAWG_DIR}" ]; then
                    SERVER_AWG_NIC=$(ls -1 "${AMNEZIAWG_DIR}"/*.conf 2>/dev/null | head -n 1 | xargs basename -s .conf)
                     if [[ -n "$SERVER_AWG_NIC" ]]; then
                        echo -e "${ORANGE}Guessed SERVER_AWG_NIC as ${SERVER_AWG_NIC} from config files.${NC}"
                    else
                        read -rp "Could not automatically determine AmneziaWG interface name. Please enter it (e.g., awg0): " SERVER_AWG_NIC
                        if [[ -z "$SERVER_AWG_NIC" ]]; then
                             echo -e "${RED}Cannot proceed without AmneziaWG interface name.${NC}"
                             exit 1
                        fi
                    fi
                else
                     read -rp "Could not automatically determine AmneziaWG interface name. Please enter it (e.g., awg0): " SERVER_AWG_NIC
                     if [[ -z "$SERVER_AWG_NIC" ]]; then
                        echo -e "${RED}Cannot proceed without AmneziaWG interface name.${NC}"
                        exit 1
                     fi
                fi
            fi
        fi
        # For other functions, params file is essential.
        # For uninstall, we make a best guess if params are missing.
        if [[ $(basename $0) != "uninstallAmneziaWG" ]] && [ ! -f "${AMNEZIAWG_DIR}/params" ]; then
            exit 1
        fi
    else
        source "${AMNEZIAWG_DIR}/params"
    fi
    SERVER_AWG_CONF="${AMNEZIAWG_DIR}/${SERVER_AWG_NIC}.conf"
}

function manageMenu() {
    echo "AmneziaWG server installer (https://github.com/varckin/amneziawg-install)"
    echo ""
    echo "It looks like AmneziaWG is already installed."
    echo ""
    echo "What do you want to do?"
    echo "   1) Add a new user"
    echo "   2) List all users"
    echo "   3) Revoke existing user"
    echo "   4) Uninstall AmneziaWG"
    echo "   5) Exit"
    MENU_OPTION=0 # Initialize
    until [[ ${MENU_OPTION} =~ ^[1-5]$ ]]; do
        read -rp "Select an option [1-5]: " MENU_OPTION
    done
    case "${MENU_OPTION}" in
    1)
        loadParams # Needed for newClient
        newClient
        ;;
    2)
        loadParams # Needed for listClients
        listClients
        ;;
    3)
        loadParams # Needed for revokeClient
        revokeClient
        ;;
    4)
        # loadParams will be called by uninstallAmneziaWG if needed after checkOS
        uninstallAmneziaWG
        ;;
    5)
        exit 0
        ;;
    esac
}

# Check for root, virt, OS...
initialCheck

# Check if AmneziaWG is already installed and load params
# Create directory if it doesn't exist, for the params file check
mkdir -p "${AMNEZIAWG_DIR}"
if [[ -e "${AMNEZIAWG_DIR}/params" ]]; then
    # loadParams # manageMenu will call loadParams as needed by its options
    manageMenu
else
    installAmneziaWG
fi
