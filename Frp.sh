#!/bin/bash

# Colors
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
FRP_VERSION="0.52.3"
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"
INSTALL_DIR="/opt/frp"
SERVER_IP=""
SERVER_PORT="7000"
TOKEN="changeme"
WG_LOCAL_PORT="51820"
WG_REMOTE_PORT="51820"

# Install FRP
install_frp() {
    echo -e "${CYAN}[+] Installing FRP...${NC}"
    mkdir -p $INSTALL_DIR
    cd /tmp
    wget -q $FRP_URL -O frp.tar.gz
    tar -xzf frp.tar.gz
    mv frp_${FRP_VERSION}_linux_amd64/* $INSTALL_DIR
    chmod +x $INSTALL_DIR/frps $INSTALL_DIR/frpc
    echo -e "${CYAN}[+] FRP installed successfully.${NC}"
}

# Create Server Configuration
create_server_config() {
    cat > $INSTALL_DIR/frps.ini <<EOF
[common]
bind_port = ${SERVER_PORT}
token = ${TOKEN}
EOF
}

# Create Client Configuration (for WireGuard)
create_client_config() {
    cat > $INSTALL_DIR/frpc.ini <<EOF
[common]
server_addr = ${SERVER_IP}
server_port = ${SERVER_PORT}
token = ${TOKEN}

[wireguard-tunnel]
type = udp
local_ip = 127.0.0.1
local_port = ${WG_LOCAL_PORT}
remote_port = ${WG_REMOTE_PORT}
EOF
}

# Create systemd Service
create_service() {
    if [[ "$MODE" == "server" ]]; then
        SERVICE_FILE="/etc/systemd/system/frps.service"
        cat > $SERVICE_FILE <<EOF
[Unit]
Description=FRP Server Service
After=network.target

[Service]
ExecStart=${INSTALL_DIR}/frps -c ${INSTALL_DIR}/frps.ini
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    else
        SERVICE_FILE="/etc/systemd/system/frpc.service"
        cat > $SERVICE_FILE <<EOF
[Unit]
Description=FRP Client Service
After=network.target

[Service]
ExecStart=${INSTALL_DIR}/frpc -c ${INSTALL_DIR}/frpc.ini
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    fi

    echo -e "${CYAN}[+] systemd service created.${NC}"
    systemctl daemon-reload
    systemctl enable $(basename $SERVICE_FILE)
    systemctl start $(basename $SERVICE_FILE)
    echo -e "${CYAN}[+] Service $(basename $SERVICE_FILE) enabled and started.${NC}"
}

# Main Menu
echo -e "${CYAN}--- FRP WireGuard Tunnel Setup ---${NC}"
echo ""
echo -e "${CYAN}Is this the External Server or Internal Client?${NC}"
echo -e "${PURPLE}[server/client]: ${NC}\c"
read MODE

if [[ "$MODE" == "server" ]]; then
    echo -e "${CYAN}Enter the FRP server bind port (e.g., 7000):${NC}"
    echo -e "${PURPLE}> ${NC}\c"
    read SERVER_PORT
    echo -e "${CYAN}Enter a token for authentication:${NC}"
    echo -e "${PURPLE}> ${NC}\c"
    read TOKEN
    install_frp
    create_server_config
    create_service
    echo -e "${CYAN}[+] FRP server setup completed.${NC}"

elif [[ "$MODE" == "client" ]]; then
    echo -e "${CYAN}Enter the public server IP:${NC}"
    echo -e "${PURPLE}> ${NC}\c"
    read SERVER_IP
    echo -e "${CYAN}Enter the FRP server port (e.g., 7000):${NC}"
    echo -e "${PURPLE}> ${NC}\c"
    read SERVER_PORT
    echo -e "${CYAN}Enter the authentication token:${NC}"
    echo -e "${PURPLE}> ${NC}\c"
    read TOKEN
    echo -e "${CYAN}Enter your local WireGuard port (default 51820):${NC}"
    echo -e "${PURPLE}> ${NC}\c"
    read WG_LOCAL_PORT
    echo -e "${CYAN}Enter the remote port to expose (default 51820):${NC}"
    echo -e "${PURPLE}> ${NC}\c"
    read WG_REMOTE_PORT
    install_frp
    create_client_config
    create_service
    echo -e "${CYAN}[+] FRP client setup completed.${NC}"

else
    echo -e "${CYAN}Invalid input! Please type server or client.${NC}"
    exit 1
fi
