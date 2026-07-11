# voip-stack

Production-ready, self-hosted WebRTC VoIP stack. Runs on a single VDS with Docker. Includes FreeSWITCH (SIP/Verto), Coturn (STUN/TURN), and a zero-dependency Web Dialer (SIP.js).

**Use case:** Make/receive real phone calls (PSTN) from a browser — no softphone, no app, no third-party SaaS.

---

## Architecture

```
┌─────────────┐     WSS (Verto)      ┌──────────────────┐     SIP/TLS      ┌──────────────┐
│  Browser    │ ◄──────────────────► │   FreeSWITCH     │ ◄─────────────►  │  SIP Trunk   │
│  (SIP.js)   │                      │  (Verto/WebRTC)  │                  │  (Telnyx,    │
└─────────────┘                      └────────┬─────────┘                  │  VoIP.ms,    │
                                              │                            │  Flowroute)  │
                                              ▼                            └──────────────┘
                                    ┌──────────────────┐
                                    │     Coturn       │
                                    │  (STUN/TURN)     │
                                    └──────────────────┘
```

**Components:**
- **FreeSWITCH** — SIP registrar, Verto WebRTC gateway, media proxy, dialplan
- **Coturn** — ICE/NAT traversal (STUN + TURN over UDP/TCP/TLS)
- **Nginx** — Serves static Web Dialer (HTTPS ready)
- **Web Dialer** — Single-file SIP.js client: register, dial, hold, mute, DTMF, call timer

---

## Quick Start (VDS)

```bash
# 1. Clone to your VDS
git clone https://github.com/YOUR_USERNAME/voip-stack.git /opt/voip-stack
cd /opt/voip-stack

# 2. Configure environment
cp .env.example .env
nano .env   # Fill all values (see Configuration below)

# 3. Run automated setup
chmod +x scripts/setup-vds.sh
./scripts/setup-vds.sh

# 4. Open Web Dialer
# http://YOUR_VDS_IP:8080
```

The setup script installs Docker, pulls images, starts containers, generates TLS certs, and configures UFW firewall.

---

## Configuration (`.env`)

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `EXTERNAL_IP` | ✅ | VDS public IPv4 | `123.45.67.89` |
| `DOMAIN` | ✅ | Domain or IP for TLS cert | `123.45.67.89` or `voip.example.com` |
| `SIP_TRUNK_HOST` | ✅ | Provider SIP host | `sip.telnyx.com` |
| `SIP_TRUNK_USER` | ✅ | SIP username | `your_username` |
| `SIP_TRUNK_PASS` | ✅ | SIP password | `your_password` |
| `SIP_TRUNK_DOMAIN` | ✅ | SIP realm/domain | `sip.telnyx.com` |
| `SIP_TRUNK_PROXY` | ✅ | SIP proxy with TLS port | `sip.telnyx.com:5061` |
| `TURN_USER` | ✅ | TURN username | `turnuser` |
| `TURN_PASS` | ✅ | TURN password (generate strong) | `openssl rand -base64 32` |
| `TURN_REALM` | ✅ | TURN realm | `voip.local` |
| `OUTBOUND_CALLER_ID_NUMBER` | ✅ | Your DID in E.164 | `905XXXXXXXXX` |
| `OUTBOUND_CALLER_ID_NAME` | ✅ | Caller ID name | `Your Name` |

**Generate TURN password:**
```bash
openssl rand -base64 32
```

---

## SIP Trunk Providers (Tested)

| Provider | Host | TLS Port | Notes |
|----------|------|----------|-------|
| **Telnyx** | `sip.telnyx.com` | 5061 | Crypto accepted, $10 free trial |
| **VoIP.ms** | `montreal.voip.ms` | 5061 | Prepaid, global DIDs, minimal KYC |
| **Flowroute** | `sip.flowroute.com` | 5061 | Developer-friendly |
| **DIDWW** | `sip.didww.com` | 5061 | Global coverage, API |
| **SignalWire** | `sip.signalwire.com` | 5061 | Elastic SIP, per-second billing |

> **PSTN calls require a SIP trunk.** For VoIP-to-VoIP only (SIP URI dialing), leave trunk vars empty — internal extensions `1000-1099` work out of the box.

---

## Web Dialer Usage

1. Open `http://YOUR_VDS_IP:8080`
2. Click ⚙️ **Settings**
3. Enter:
   - **WebSocket URL:** `wss://YOUR_VDS_IP:8083` (or `wss://your.domain.com:8083`)
   - **SIP Username:** `1000` (default extension range: `1000-1099`)
   - **SIP Password:** *leave empty* (internal auth disabled by default)
   - **Domain:** `YOUR_VDS_IP` or `voip.local`
4. Click **Save & Connect** → Status shows **"Kayıtlı ✓"** (green)
5. Dial full E.164 number: `905XXXXXXXXX` → 📞 **Ara**

**Features:** Mute, Hold, DTMF keypad, Call timer, Incoming call answer, Keyboard shortcuts (`Enter`=dial, `Esc`=hangup, `m`=mute, `h`=hold).

---

## FreeSWITCH CLI

```bash
docker exec -it voip-freeswitch fs_cli
```

| Command | Description |
|---------|-------------|
| `sofia status` | All SIP profiles status |
| `sofia status gateway sip_trunk` | Trunk registration state |
| `verto status` | Verto/WebRTC sessions |
| `show channels` | Active calls |
| `reloadxml` | Reload dialplan/config |
| `sofia profile internal restart` | Restart WebRTC profile |

---

## TLS Certificates

**Let's Encrypt (requires domain):**
```bash
DOMAIN=voip.example.com ./scripts/generate-tls.sh
```

**Self-signed (IP only):**
```bash
DOMAIN=123.45.67.89 ./scripts/generate-tls.sh
```

Certs are stored in `freeswitch/tls/` and auto-mounted. Restart FreeSWITCH after renewal:
```bash
docker compose restart freeswitch
```

---

## Ports Reference

| Port | Service | Protocol | Purpose |
|------|---------|----------|---------|
| 5060 | SIP | UDP/TCP | Standard SIP signaling |
| 5061 | SIPS | TCP | SIP over TLS (trunk) |
| 5066 | WS | TCP | Verto WebSocket (unencrypted) |
| 7443 | WSS | TCP | Verto WebSocket Secure (browser) |
| 8080 | HTTP | TCP | Web Dialer (Nginx) |
| 16384-32768 | RTP/SRTP | UDP | Media (audio) |
| 3478 | STUN/TURN | UDP/TCP | NAT traversal |
| 5349 | TURNS | TCP | TURN over TLS |

**Open all on VDS firewall.** The setup script configures UFW automatically.

---

## Default Extensions & Features

| Pattern | Action |
|---------|--------|
| `1000-1099` | Internal extensions (WebRTC) |
| `90XXXXXXXXX` | Outbound via SIP trunk (E.164) |
| `9999` | Echo test |
| `8888` | Conference room |
| `*98` | Voicemail main |

Inbound trunk calls route to extension `1000` (Verto). Modify `freeswitch/conf/dialplan/default.xml` to change.

---

## Anonymity / OpSec Checklist

- [ ] **SSH over Tor only:** `ssh -o ProxyCommand="nc -X 5 -x localhost:9050 %h %p" root@IP`
- [ ] **`.env` permissions:** `chmod 600 .env`
- [ ] **FreeSWITCH logging disabled:** Edit `conf/autoload_configs/console.conf.xml` → `<param name="log-level" value="0"/>`
- [ ] **SIP TLS enforced:** `register-transport=tls`, `contact-params=transport=tls`
- [ ] **SRTP enforced:** `media-option=SRTP` (no fallback to RTP)
- [ ] **Payments:** Monero (XMR) or coinjoined Bitcoin only
- [ ] **Domain:** Njalla / OrangeWebsite (WHOIS privacy, crypto payment)
- [ ] **Own TURN:** No Google/Cloudflare STUN in production
- [ ] **VDS provider:** No-KYC hosting (e.g., Hetzner via reseller, Contabo, or crypto VPS)

---

## Project Structure

```
voip-stack/
├── .env.example              # Template — copy to .env
├── docker-compose.yml        # 3 services: freeswitch, coturn, nginx
├── README.md                 # This file
├── freeswitch/
│   ├── conf/
│   │   ├── vars.xml          # Variable substitution from .env
│   │   ├── sip_profiles/
│   │   │   ├── internal.xml  # WebRTC profile (WSS, SRTP, ICE)
│   │   │   └── external/sip_trunk.xml  # SIP trunk (TLS, SRTP)
│   │   ├── dialplan/
│   │   │   └── default.xml   # Inbound/outbound routing
│   │   └── autoload_configs/
│   │       └── verto.conf.xml # Verto WebRTC config
│   ├── scripts/
│   │   └── generate-tls.sh   # Let's Encrypt / self-signed certs
│   ├── recordings/           # Call recordings (if enabled)
│   └── tls/                  # TLS certs (auto-generated)
├── scripts/
│   ├── setup-vds.sh          # One-command VDS install
│   └── generate-tls.sh       # Symlink to freeswitch/scripts/
└── web-dialer/
    └── index.html            # SIP.js dialer (single file, no build)
```

---

## Update & Maintenance

```bash
cd /opt/voip-stack
docker compose pull
docker compose up -d
./scripts/generate-tls.sh    # If cert renewed
```

**Backup:**
```bash
tar -czf /backup/voip-$(date +%F).tar.gz freeswitch/conf .env
```

**Logs:**
```bash
docker compose logs -f freeswitch
docker compose logs -f turn
```

---

## Why This Stack?

| Feature | This Stack | Typical SaaS |
|---------|------------|--------------|
| **Full control** | ✅ Your server, your data | ❌ Vendor lock-in |
| **Anonymity** | ✅ Tor SSH, crypto pay, no logs | ❌ KYC, logging |
| **Cost** | ~$6-10/mo (VDS) + trunk minutes | $20-50+/mo per seat |
| **PSTN access** | ✅ Any SIP trunk provider | ✅ Built-in |
| **WebRTC** | ✅ Native browser, no install | ✅ Usually |
| **Custom dialplan** | ✅ Full FreeSWITCH XML | ❌ Limited |
| **Recording** | ✅ Local, encrypted | ❌ Vendor storage |

---

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Trunk not registering | `docker logs voip-freeswitch` → verify credentials, TLS port 5061 |
| No audio / one-way | Coturn ports 3478/5349 open? `docker logs voip-turn` |
| Browser "Insecure" on WSS | Self-signed cert → accept in browser at `https://IP:8083` first |
| Call drops at 30s | `rtp-timeout-sec` in `internal.xml` → increase |
| Dialer "SIP not registered" | WebSocket URL correct? Domain matches FreeSWITCH realm? |

---

## License

MIT — Free for any use, including commercial.

---

## Contributing

Issues and PRs welcome. Focus areas:
- Dialplan examples (IVR, call recording, voicemail email)
- Mobile PWA manifest for dialer
- Prometheus/Grafana metrics exporter
- IPv6 support
- Automated Let's Encrypt renewal via cron

---

**Built for sovereignty. Run your own voice infrastructure.**
