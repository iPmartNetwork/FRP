#!/bin/bash

# --- Variables ---
FRP_VERSION="0.62.1"
FRP_DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"
FRP_DIR="/opt/frp"
DEFAULT_FRP_PORT="7000"
FRP_DASHBOARD_PORT="7500"
FRP_DASHBOARD_USER="admin"
FRP_DASHBOARD_PASSWORD="admin"
FRP_TOKEN=$(openssl rand -hex 16)
SYSTEMD_DIR="/etc/systemd/system"

# --- Colors ---
NC='\033[0m'        # No Color
CYAN='\033[1;36m'   # Light Cyan
PURPLE='\033[1;35m' # Light Purple
BLUE='\033[1;34m'   # Blue

# --- Functions ---
install_frp() {
    echo -e "${BLUE}>> Downloading FRP version ${FRP_VERSION}...${NC}"
    mkdir -p ${FRP_DIR}
    cd ${FRP_DIR}
    wget -q --show-progress ${FRP_DOWNLOAD_URL} -O frp.tar.gz
    tar -xzf frp.tar.gz --strip-components=1
    rm -f frp.tar.gz
    echo -e "${CYAN}>> FRP installed at ${FRP_DIR}${NC}"
}

setup_frps() {
    read -p "$(echo -e ${CYAN}"Enter server bind port (default ${DEFAULT_FRP_PORT}): "${NC})" FRP_PORT
    FRP_PORT=${FRP_PORT:-$DEFAULT_FRP_PORT}

    cat > ${FRP_DIR}/frps.ini <<EOF
[common]
bind_port = ${FRP_PORT}
token = ${FRP_TOKEN}

dashboard_addr = 0.0.0.0
dashboard_port = ${FRP_DASHBOARD_PORT}
dashboard_user = ${FRP_DASHBOARD_USER}
dashboard_pwd = ${FRP_DASHBOARD_PASSWORD}
EOF

    cat > ${SYSTEMD_DIR}/frps.service <<EOF
[Unit]
Description=FRP Server Service
After=network.target

[Service]
ExecStart=${FRP_DIR}/frps -c ${FRP_DIR}/frps.ini
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable frps
    systemctl restart frps
    echo -e "${PURPLE}>> frps server is now running.${NC}"
    echo -e "${CYAN}>> Dashboard URL: http://your-server-ip:${FRP_DASHBOARD_PORT}${NC}"
    echo -e "${CYAN}>> Dashboard Login: ${FRP_DASHBOARD_USER} / ${FRP_DASHBOARD_PASSWORD}${NC}"
    echo -e "${CYAN}>> Your security token: ${FRP_TOKEN}${NC}"
}

setup_frpc() {
    read -p "$(echo -e ${CYAN}"Enter server IP or domain: "${NC})" SERVER_IP
    read -p "$(echo -e ${CYAN}"Enter server port (default ${DEFAULT_FRP_PORT}): "${NC})" FRP_PORT
    FRP_PORT=${FRP_PORT:-$DEFAULT_FRP_PORT}

    echo "[common]" > ${FRP_DIR}/frpc.ini
    echo "server_addr = ${SERVER_IP}" >> ${FRP_DIR}/frpc.ini
    echo "server_port = ${FRP_PORT}" >> ${FRP_DIR}/frpc.ini
    echo "token = ${FRP_TOKEN}" >> ${FRP_DIR}/frpc.ini
    echo "" >> ${FRP_DIR}/frpc.ini

    while true; do
        read -p "$(echo -e ${CYAN}"Enter tunnel name (e.g., ssh, http, rdp): "${NC})" TUNNEL_NAME
        echo -e "${PURPLE}Select tunnel protocol type:${NC}"
        echo -e "${BLUE}1) tcp${NC}"
        echo -e "${BLUE}2) udp${NC}"
        echo -e "${BLUE}3) stcp (secure tcp)${NC}"
        echo -e "${BLUE}4) xtcp (P2P)${NC}"
        echo -e "${BLUE}5) faketcp${NC}"
        echo -e "${BLUE}6) quic${NC}"
        echo -e "${BLUE}7) kcp${NC}"
        echo -e "${BLUE}8) tls${NC}"
        echo -e "${BLUE}9) icmp${NC}"
        read -p "$(echo -e ${CYAN}"Choose protocol (1-9): "${NC})" PROTOCOL_CHOICE

        case $PROTOCOL_CHOICE in
            1) PROTOCOL_TYPE="tcp" ;;
            2) PROTOCOL_TYPE="udp" ;;
            3) PROTOCOL_TYPE="stcp" ;;
            4) PROTOCOL_TYPE="xtcp" ;;
            5) PROTOCOL_TYPE="faketcp" ;;
            6) PROTOCOL_TYPE="quic" ;;
            7) PROTOCOL_TYPE="kcp" ;;
            8) PROTOCOL_TYPE="tls" ;;
            9) PROTOCOL_TYPE="icmp" ;;
            *) echo "Invalid protocol selected. Defaulting to tcp."; PROTOCOL_TYPE="tcp" ;;
        esac

        read -p "$(echo -e ${CYAN}"Enter local IP (e.g., 127.0.0.1): "${NC})" LOCAL_IP
        read -p "$(echo -e ${CYAN}"Enter local port (e.g., 22 for SSH): "${NC})" LOCAL_PORT
        read -p "$(echo -e ${CYAN}"Enter remote port (e.g., 6000 or any free port): "${NC})" REMOTE_PORT

        cat >> ${FRP_DIR}/frpc.ini <<EOF
[${TUNNEL_NAME}]
type = ${PROTOCOL_TYPE}
local_ip = ${LOCAL_IP}
local_port = ${LOCAL_PORT}
remote_port = ${REMOTE_PORT}

EOF

        read -p "$(echo -e ${CYAN}"Do you want to add another tunnel? (y/n): "${NC})" ADD_MORE
        if [[ "$ADD_MORE" != "y" ]]; then
            break
        fi
    done

    cat > ${SYSTEMD_DIR}/frpc.service <<EOF
[Unit]
Description=FRP Client Service
After=network.target

[Service]
ExecStart=${FRP_DIR}/frpc -c ${FRP_DIR}/frpc.ini
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable frpc
    systemctl restart frpc
    echo -e "${PURPLE}>> frpc client is now running.${NC}"
    echo -e "${CYAN}>> Your security token: ${FRP_TOKEN}${NC}"
}

# --- Menu ---
echo -e "${PURPLE}What do you want to do?${NC}"
echo -e "${BLUE}1) Install and setup Server (frps)${NC}"
echo -e "${BLUE}2) Install and setup Client (frpc)${NC}"
read -p "$(echo -e ${CYAN}"Choose (1/2): "${NC})" CHOICE

install_frp

if [ "$CHOICE" == "1" ]; then
    setup_frps
elif [ "$CHOICE" == "2" ]; then
    setup_frpc
else
    echo -e "${PURPLE}Invalid option selected. Exiting.${NC}"
    exit 1
fi
