# voip-stack

Production-ready, self-hosted WebRTC VoIP yığını. Tek bir VDS'de Docker ile çalışır. FreeSWITCH (SIP/Verto), Coturn (STUN/TURN), ve sıfır-bağımlılık Web Dialer (SIP.js) içerir.

**Kullanım alanı:** Tarayıcıdan gerçek telefon araması (PSTN) yap/al — softphone yok, uygulama yok, üçüncü taraf SaaS yok.

---

## Mimarisi

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

**Bileşenler:**
- **FreeSWITCH** — SIP registrar, Verto WebRTC gateway, medya proxy, dialplan
- **Coturn** — ICE/NAT traversal (STUN + TURN over UDP/TCP/TLS)
- **Nginx** — Statik Web Dialer servisi (HTTPS hazır)
- **Web Dialer** — Tek dosyalık SIP.js istemcisi: register, dial, hold, mute, DTMF, çağrı süresi

---

## Hızlı Başlangıç (VDS)

```bash
# 1. VDS'ye klonla
git clone https://github.com/zwenmis/voip-stack.git /opt/voip-stack
cd /opt/voip-stack

# 2. Ortam değişkenlerini ayarla
cp .env.example .env
nano .env   # Tüm değerleri doldur (aşağıya bak)

# 3. Otomatik kurulum
chmod +x scripts/setup-vds.sh
./scripts/setup-vds.sh

# 4. Web Dialer'ı aç
# http://SUNUCU_IP:8080
```

Kurulum scripti Docker kurar, image'ları çeker, container'ları başlatır, TLS sertifikası üretir, UFW firewall'ı yapılandırır.

---

## Konfigürasyon (`.env`)

| Değişken | Zorunlu | Açıklama | Örnek |
|----------|---------|----------|-------|
| `EXTERNAL_IP` | ✅ | VDS public IPv4 | `123.45.67.89` |
| `DOMAIN` | ✅ | TLS sertifikası için domain/IP | `123.45.67.89` veya `voip.ornek.com` |
| `SIP_TRUNK_HOST` | ✅ | Sağlayıcı SIP host | `sip.telnyx.com` |
| `SIP_TRUNK_USER` | ✅ | SIP kullanıcı adı | `kullanici_adin` |
| `SIP_TRUNK_PASS` | ✅ | SIP şifresi | `sifreniz` |
| `SIP_TRUNK_DOMAIN` | ✅ | SIP realm/domain | `sip.telnyx.com` |
| `SIP_TRUNK_PROXY` | ✅ | SIP proxy (TLS port ile) | `sip.telnyx.com:5061` |
| `TURN_USER` | ✅ | TURN kullanıcı adı | `turnuser` |
| `TURN_PASS` | ✅ | TURN şifresi (güçlü üretin) | `openssl rand -base64 32` |
| `TURN_REALM` | ✅ | TURN realm | `voip.local` |
| `OUTBOUND_CALLER_ID_NUMBER` | ✅ | DID numaranız (E.164) | `905XXXXXXXXX` |
| `OUTBOUND_CALLER_ID_NAME` | ✅ | Caller ID adı | `Adiniz` |

**TURN şifresi üret:**
```bash
openssl rand -base64 32
```

---

## Test Edilen SIP Trunk Sağlayıcıları

| Sağlayıcı | Host | TLS Port | Notlar |
|-----------|------|----------|--------|
| **Telnyx** | `sip.telnyx.com` | 5061 | Kripto kabul, $10 deneme kredisi |
| **VoIP.ms** | `montreal.voip.ms` | 5061 | Prepaid, global DID, minimal KYC |
| **Flowroute** | `sip.flowroute.com` | 5061 | Geliştirici dostu |
| **DIDWW** | `sip.didww.com` | 5061 | Geniş kapsama, API |
| **SignalWire** | `sip.signalwire.com` | 5061 | Elastic SIP, saniye bazlı faturalama |

> **PSTN araması için SIP trunk zorunlu.** Sadece VoIP-to-VoIP (SIP URI) istiyorsan trunk alanlarını boş bırak — dahili uzantılar `1000-1099` kutudan çıkar çıkmaz çalışır.

---

## Web Dialer Kullanımı

1. `http://SUNUCU_IP:8080` aç
2. ⚙️ **Ayarlar** tıkla
3. Gir:
   - **WebSocket URL:** `wss://SUNUCU_IP:8083` (veya `wss://domain.com:8083`)
   - **SIP Kullanıcı:** `1000` (varsayılan aralık: `1000-1099`)
   - **SIP Şifre:** *boş bırak* (dahili auth kapalı)
   - **Domain:** `SUNUCU_IP` veya `voip.local`
4. **Kaydet & Bağlan** → Durum **"Kayıtlı ✓"** (yeşil) olur
5. Tam E.164 numara gir: `905XXXXXXXXX` → 📞 **Ara**

**Özellikler:** Mute, Hold, DTMF tuş takımı, Çağrı süresi, Gelen arama cevaplama, Klavye kısayolları (`Enter`=ara, `Esc`=kapat, `m`=mute, `h`=hold).

---

## FreeSWITCH CLI

```bash
docker exec -it voip-freeswitch fs_cli
```

| Komut | Açıklama |
|-------|----------|
| `sofia status` | Tüm SIP profilleri durumu |
| `sofia status gateway sip_trunk` | Trunk kayıt durumu |
| `verto status` | Verto/WebRTC oturumları |
| `show channels` | Aktif çağrılar |
| `reloadxml` | Dialplan/config yenile |
| `sofia profile internal restart` | WebRTC profili yeniden başlat |

---

## TLS Sertifikaları

**Let's Encrypt (domain gerekir):**
```bash
DOMAIN=voip.ornek.com ./scripts/generate-tls.sh
```

**Self-signed (sadece IP):**
```bash
DOMAIN=123.45.67.89 ./scripts/generate-tls.sh
```

Sertifikalar `freeswitch/tls/` altında, otomatik mount edilir. Yenilemeden sonra:
```bash
docker compose restart freeswitch
```

---

## Port Referansı

| Port | Servis | Protokol | Amaç |
|------|--------|----------|------|
| 5060 | SIP | UDP/TCP | Standart SIP sinyali |
| 5061 | SIPS | TCP | SIP over TLS (trunk) |
| 5066 | WS | TCP | Verto WebSocket (şifresiz) |
| 7443 | WSS | TCP | Verto WebSocket Secure (tarayıcı) |
| 8080 | HTTP | TCP | Web Dialer (Nginx) |
| 16384-32768 | RTP/SRTP | UDP | Medya (ses) |
| 3478 | STUN/TURN | UDP/TCP | NAT traversal |
| 5349 | TURNS | TCP | TURN over TLS |

**VDS firewall'da hepsi açık olmalı.** Kurulum scripti UFW'yi otomatik yapılandırır.

---

## Varsayılan Uzantılar ve Özellikler

| Pattern | İşlem |
|---------|-------|
| `1000-1099` | Dahili uzantılar (WebRTC) |
| `90XXXXXXXXX` | SIP trunk üzerinden giden (E.164) |
| `9999` | Echo test |
| `8888` | Konferans odası |
| `*98` | Sesli posta ana menü |

Gelen trunk çağrıları `1000` numaralı uzantıya (Verto) yönlendirilir. Değiştirmek için `freeswitch/conf/dialplan/default.xml` düzenle.

---

## Anonimlik / OpSec Kontrol Listesi

- [ ] **SSH sadece Tor üzerinden:** `ssh -o ProxyCommand="nc -X 5 -x localhost:9050 %h %p" root@IP`
- [ ] **`.env` izinleri:** `chmod 600 .env`
- [ ] **FreeSWITCH log kapalı:** `conf/autoload_configs/console.conf.xml` → `<param name="log-level" value="0"/>`
- [ ] **SIP TLS zorunlu:** `register-transport=tls`, `contact-params=transport=tls`
- [ ] **SRTP zorunlu:** `media-option=SRTP` (RTP fallback yok)
- [ ] **Ödeme:** Sadece Monero (XMR) veya coinjoin yapılmış Bitcoin
- [ ] **Domain:** Njalla / OrangeWebsite (WHOIS gizli, kripto ödeme)
- [ ] **Kendi TURN:** Production'da Google/Cloudflare STUN kullanma
- [ ] **VDS sağlayıcı:** No-KYC hosting (Hetzner bayi, Contabo, veya kripto VPS)

---

## Proje Yapısı

```
voip-stack/
├── .env.example              # Şablon — .env olarak kopyala
├── docker-compose.yml        # 3 servis: freeswitch, coturn, nginx
├── README.md                 # Bu dosya
├── freeswitch/
│   ├── conf/
│   │   ├── vars.xml          # .env'den değişken yerine koyma
│   │   ├── sip_profiles/
│   │   │   ├── internal.xml  # WebRTC profili (WSS, SRTP, ICE)
│   │   │   └── external/sip_trunk.xml  # SIP trunk (TLS, SRTP)
│   │   ├── dialplan/
│   │   │   └── default.xml   # Gelen/giden yönlendirme
│   │   └── autoload_configs/
│   │       └── verto.conf.xml # Verto WebRTC config
│   ├── scripts/
│   │   └── generate-tls.sh   # Let's Encrypt / self-signed sertifika
│   ├── recordings/           # Çağrı kayıtları (etkinse)
│   └── tls/                  # TLS sertifikaları (otomatik)
├── scripts/
│   ├── setup-vds.sh          # Tek komutlu VDS kurulumu
│   └── generate-tls.sh       # freeswitch/scripts/ symlink
└── web-dialer/
    └── index.html            # SIP.js dialer (tek dosya, build yok)
```

---

## Güncelleme ve Bakım

```bash
cd /opt/voip-stack
docker compose pull
docker compose up -d
./scripts/generate-tls.sh    # Sertifika yenilendiyse
```

**Yedek:**
```bash
tar -czf /backup/voip-$(date +%F).tar.gz freeswitch/conf .env
```

**Loglar:**
```bash
docker compose logs -f freeswitch
docker compose logs -f turn
```

---

## Neden Bu Stack?

| Özellik | Bu Stack | Tipik SaaS |
|---------|----------|------------|
| **Tam kontrol** | ✅ Sunucun, verin | ❌ Vendor lock-in |
| **Anonimlik** | ✅ Tor SSH, kripto ödeme, log yok | ❌ KYC, loglama |
| **Maliyet** | ~$6-10/ay (VDS) + dakika | $20-50+/ay/koltuk |
| **PSTN erişimi** | ✅ Herhangi bir SIP trunk | ✅ Dahili |
| **WebRTC** | ✅ Yerel tarayıcı, kurulum yok | ✅ Genelde |
| **Özel dialplan** | ✅ Tam FreeSWITCH XML | ❌ Sınırlı |
| **Kayıt** | ✅ Yerel, şifreli | ❌ Sağlayıcı depolar |

---

## Sorun Giderme

| Belirti | Kontrol Edilmesi Gerekenler |
|---------|----------------------------|
| Trunk kayıt olmuyor | `docker logs voip-freeswitch` → cred, TLS port 5061 |
| Ses yok / tek yönlü | Coturn portları 3478/5349 açık mı? `docker logs voip-turn` |
| Tarayıcı "Güvenli değil" WSS | Self-signed cert → `https://IP:8083` kabul et |
| 30 sn'de düşüyor | `internal.xml` → `rtp-timeout-sec` artır |
| Dialer "SIP kayıtlı değil" | WebSocket URL doğru mu? Domain FreeSWITCH realm ile eşleşiyor mu? |

---

## Lisans

MIT — Ticari kullanım dahil her kullanım için ücretsiz.

---

## Katkı

Issue ve PR memnuniyetle karşılanır. Odak alanları:
- Dialplan örnekleri (IVR, çağrı kaydı, voicemail e-posta)
- Dialer için PWA manifest
- Prometheus/Grafana metrik exporter
- IPv6 desteği
- Cron ile otomatik Let's Encrypt yenileme

---

**Egemenlik için inşa edildi. Kendi ses altyapını çalıştır.**
