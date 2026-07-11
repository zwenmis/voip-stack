#!/bin/bash
set -e

echo "=== VoIP System VDS Setup ==="

apt-get update && apt-get upgrade -y

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker $USER
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    apt-get install -y docker-compose-plugin
fi

PROJECT_DIR="/opt/voip-system"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

if [[ ! -f .env ]]; then
    cat > .env << 'EOF'
EXTERNAL_IP=$(curl -s ifconfig.me)
DOMAIN=YOUR_VDS_PUBLIC_IP

SIP_TRUNK_HOST=sip.yourprovider.com
SIP_TRUNK_USER=your_sip_username
SIP_TRUNK_PASS=your_sip_password
SIP_TRUNK_DOMAIN=sip.yourprovider.com
SIP_TRUNK_PROXY=sip.yourprovider.com:5061

TURN_USER=turnuser
TURN_PASS=$(openssl rand -base64 32)
TURN_REALM=voip.local

OUTBOUND_CALLER_ID_NUMBER=905XXXXXXXXX
OUTBOUND_CALLER_ID_NAME=YourName
EOF
    echo ".env created. EDIT IT:"
    nano .env
fi

docker compose pull
docker compose up -d

chmod +x scripts/generate-tls.sh
./scripts/generate-tls.sh

ufw allow 5060/udp
ufw allow 5060/tcp
ufw allow 5061/tcp
ufw allow 5066/tcp
ufw allow 7443/tcp
ufw allow 8080/tcp
ufw allow 16384:32768/udp
ufw allow 3478/udp
ufw allow 3478/tcp
ufw allow 5349/tcp
ufw --force enable

echo "=== Done ==="
echo "Web Dialer: http://$(curl -s ifconfig.me):8080"
echo "FreeSWITCH CLI: docker exec -it voip-freeswitch fs_cli"
echo "Logs: docker compose logs -f"