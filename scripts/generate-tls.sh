#!/bin/bash
set -e

DOMAIN="${DOMAIN:-localhost}"
EMAIL="${EMAIL:-admin@${DOMAIN}}"
TLS_DIR="/etc/freeswitch/tls"

mkdir -p "$TLS_DIR"

if [[ "$DOMAIN" != "localhost" && "$DOMAIN" != "YOUR_VDS_PUBLIC_IP" ]]; then
  if command -v certbot &> /dev/null; then
    certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" 2>/dev/null || true
    if [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
      cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$TLS_DIR/wss.pem"
      cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$TLS_DIR/wss.key"
      cp "/etc/letsencrypt/live/$DOMAIN/chain.pem" "$TLS_DIR/ca.pem"
      echo "Let's Encrypt certificate installed"
    else
      generate_selfsigned
    fi
  else
    generate_selfsigned
  fi
else
  generate_selfsigned
fi

generate_selfsigned() {
  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout "$TLS_DIR/wss.key" \
    -out "$TLS_DIR/wss.pem" \
    -subj "/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN,IP:$(hostname -I | awk '{print $1}')"
  cp "$TLS_DIR/wss.pem" "$TLS_DIR/ca.pem"
  echo "Self-signed certificate generated: $DOMAIN"
}

chmod 644 "$TLS_DIR/wss.pem" "$TLS_DIR/ca.pem"
chmod 600 "$TLS_DIR/wss.key"
chown -R freeswitch:freeswitch "$TLS_DIR" 2>/dev/null || true

echo "TLS ready. Restarting FreeSWITCH..."
docker compose restart freeswitch 2>/dev/null || true