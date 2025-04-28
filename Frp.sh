#!/bin/bash

# FRP Version
FRP_VERSION="0.62.1"
FRP_DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

# Install FRP
function install_frp() {
    echo -e "${GREEN}Installing FRP ${FRP_VERSION}...${NC}"
    wget -qO frp.tar.gz "${FRP_DOWNLOAD_URL}"
    tar -xzf frp.tar.gz
    cd frp_${FRP_VERSION}_linux_amd64 || exit

    cp frps frpc /usr/local/bin/
    mkdir -p /etc/frp
    cp frps.ini frpc.ini /etc/frp/
    echo -e "${GREEN}FRP installed successfully.${NC}"
}

# Configure FRPS (Server)
function configure_server() {
    echo -e "${GREEN}Configuring FRP Server (frps)...${NC}"
    read -p "Enter bind port (default 7000): " BIND_PORT
    BIND_PORT=${BIND_PORT:-7000}

    cat > /etc/frp/frps.ini <<EOF
[common]
bind_port = ${BIND_PORT}
EOF

    cat > /etc/systemd/system/frps.service <<EOF
[Unit]
Description=FRP Server
After=network.target

[Service]
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.ini
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable frps
    systemctl restart frps
    echo -e "${GREEN}FRPS service started.${NC}"
}

# Configure FRPC (Client)
function configure_client() {
    echo -e "${GREEN}Configuring FRP Client (frpc)...${NC}"
    read -p "Enter server IP: " SERVER_IP
    read -p "Enter server port (default 7000): " SERVER_PORT
    SERVER_PORT=${SERVER_PORT:-7000}

    cat > /etc/frp/frpc.ini <<EOF
[common]
server_addr = ${SERVER_IP}
server_port = ${SERVER_PORT}
EOF

    cat > /etc/systemd/system/frpc.service <<EOF
[Unit]
Description=FRP Client
After=network.target

[Service]
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.ini
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable frpc
    systemctl restart frpc
    echo -e "${GREEN}FRPC service started.${NC}"
}

# Add single or multiple tunnels
function add_tunnel() {
    echo -e "${GREEN}Adding Tunnel(s)...${NC}"
    read -p "Tunnel Name Prefix: " NAME_PREFIX
    echo "Select protocol:"
    select PROTOCOL in tcp udp icmp; do
        case $PROTOCOL in
            tcp|udp) break ;;
            icmp)
                echo -e "${RED}ICMP tunneling is not supported natively in FRP! Exiting.${NC}"
                exit 1 ;;
            *) echo "Invalid option." ;;
        esac
    done

    read -p "Enter Local IP: " LOCAL_IP
    read -p "Enter Local Port Start: " LOCAL_START
    read -p "Enter Local Port End (same as start if single port): " LOCAL_END
    read -p "Enter Remote Port Start: " REMOTE_START

    for ((i=0; i<=LOCAL_END-LOCAL_START; i++)); do
        cat >> /etc/frp/frpc.ini <<EOF

[${NAME_PREFIX}_${i}]
type = ${PROTOCOL}
local_ip = ${LOCAL_IP}
local_port = $((LOCAL_START + i))
remote_port = $((REMOTE_START + i))
EOF
    done

    systemctl restart frpc
    echo -e "${GREEN}Tunnel(s) added and FRPC restarted.${NC}"
}

# Remove tunnel
function remove_tunnel() {
    echo -e "${GREEN}Removing Tunnel...${NC}"
    read -p "Enter Tunnel Name or Prefix to remove: " TUNNEL_NAME
    sed -i "/\[${TUNNEL_NAME}/,/^$/d" /etc/frp/frpc.ini
    systemctl restart frpc
    echo -e "${GREEN}Tunnel(s) matching ${TUNNEL_NAME} removed.${NC}"
}

# Edit tunnel manually
function edit_tunnel() {
    echo -e "${GREEN}Editing Tunnel Configuration...${NC}"
    nano /etc/frp/frpc.ini
    systemctl restart frpc
}

# Add Cron Job
function add_cron() {
    echo -e "${GREEN}Adding Cron Job...${NC}"
    read -p "Enter cron schedule (e.g. */10 * * * *): " CRON_TIME
    read -p "Enter command (e.g. systemctl restart frpc): " CRON_CMD

    (crontab -l ; echo "${CRON_TIME} ${CRON_CMD}") | crontab -
    echo -e "${GREEN}Cron job added.${NC}"
}

# Tunnel Manager
function tunnel_manager() {
    echo -e "${GREEN}Tunnel Manager Menu:${NC}"
    select opt in "Add Tunnel(s)" "Remove Tunnel" "Edit Tunnel Config" "Add Cron Job" "Back to Main Menu"; do
        case $opt in
            "Add Tunnel(s)") add_tunnel ;;
            "Remove Tunnel") remove_tunnel ;;
            "Edit Tunnel Config") edit_tunnel ;;
            "Add Cron Job") add_cron ;;
            "Back to Main Menu") break ;;
            *) echo "Invalid option." ;;
        esac
    done
}

# Main Menu
function main_menu() {
    while true; do
        echo -e "${GREEN}FRP Auto Installer & Tunnel Manager${NC}"
        select option in "Install FRP" "Configure Server (frps)" "Configure Client (frpc)" "Tunnel Manager" "Exit"; do
            case $option in
                "Install FRP") install_frp ;;
                "Configure Server (frps)") configure_server ;;
                "Configure Client (frpc)") configure_client ;;
                "Tunnel Manager") tunnel_manager ;;
                "Exit") exit 0 ;;
                *) echo "Invalid option." ;;
            esac
        done
    done
}

main_menu
