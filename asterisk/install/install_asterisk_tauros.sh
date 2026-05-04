#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-tauros.env}"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Arquivo de configuracao nao encontrado: $ENV_FILE"
  echo "Copie tauros.env.example para tauros.env e preencha."
  exit 1
fi

if [[ "$(id -u)" != "0" ]]; then
  echo "Execute como root: sudo bash install_asterisk_tauros.sh tauros.env"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

require_value() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" || "$value" == IP_* || "$value" == SEU_* || "$value" == TROQUE_* ]]; then
    echo "Configure $name em $ENV_FILE"
    exit 1
  fi
}

require_value PUBLIC_IP
require_value PANEL_AMI_ALLOW_IP
require_value AMI_USER
require_value AMI_SECRET
require_value MAGNUS_HOST
require_value MAGNUS_USER
require_value MAGNUS_SECRET
require_value MAGNUS_FROM_USER
require_value MAGNUS_FROM_DOMAIN

HTTP_PORT="${HTTP_PORT:-8088}"
AMI_PORT="${AMI_PORT:-5038}"
RTP_START="${RTP_START:-10000}"
RTP_END="${RTP_END:-20000}"
MAGNUS_PORT="${MAGNUS_PORT:-5060}"
DEFAULT_CALLERID="${DEFAULT_CALLERID:-}"
INSTALL_TURN="${INSTALL_TURN:-1}"
CONFIGURE_UFW="${CONFIGURE_UFW:-1}"
TURN_PORT="${TURN_PORT:-3478}"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "Instalador preparado para Debian/Ubuntu com apt-get."
  exit 1
fi

echo "==> Instalando dependencias"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y asterisk asterisk-modules curl ca-certificates openssl sox ffmpeg fail2ban
if [[ "$INSTALL_TURN" == "1" ]]; then
  apt-get install -y coturn
fi
if [[ "$CONFIGURE_UFW" == "1" ]]; then
  apt-get install -y ufw
fi

echo "==> Criando backup de /etc/asterisk"
stamp="$(date +%Y%m%d-%H%M%S)"
mkdir -p "/root/tauros-backups"
tar -czf "/root/tauros-backups/asterisk-before-tauros-$stamp.tar.gz" /etc/asterisk

write_if_missing_include() {
  local file="$1"
  local include="$2"
  touch "$file"
  grep -qxF "#include $include" "$file" || printf "\n#include %s\n" "$include" >> "$file"
}

echo "==> Configurando HTTP/WebSocket"
cat > /etc/asterisk/http_tauros.conf <<EOF_HTTP
[general]
enabled=yes
bindaddr=0.0.0.0
bindport=${HTTP_PORT}
tlsenable=no
EOF_HTTP
write_if_missing_include /etc/asterisk/http.conf http_tauros.conf

echo "==> Configurando RTP/ICE"
cat > /etc/asterisk/rtp_tauros.conf <<EOF_RTP
[general]
rtpstart=${RTP_START}
rtpend=${RTP_END}
icesupport=yes
stunaddr=
EOF_RTP
write_if_missing_include /etc/asterisk/rtp.conf rtp_tauros.conf

echo "==> Configurando AMI"
cat > /etc/asterisk/manager_tauros.conf <<EOF_MANAGER
[general]
enabled = yes
webenabled = no
port = ${AMI_PORT}
bindaddr = 0.0.0.0
displayconnects = yes
allowmultiplelogin = yes

[${AMI_USER}]
secret = ${AMI_SECRET}
deny = 0.0.0.0/0.0.0.0
permit = ${PANEL_AMI_ALLOW_IP}/255.255.255.255
read = system,call,log,verbose,command,agent,user,config,dtmf,reporting,cdr,dialplan,originate
write = system,call,log,verbose,command,agent,user,config,dtmf,reporting,cdr,dialplan,originate
EOF_MANAGER
write_if_missing_include /etc/asterisk/manager.conf manager_tauros.conf

echo "==> Gerando certificado DTLS se necessario"
mkdir -p /etc/asterisk/keys
if [[ ! -f /etc/asterisk/keys/asterisk.pem || ! -f /etc/asterisk/keys/asterisk.key ]]; then
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout /etc/asterisk/keys/asterisk.key \
    -out /etc/asterisk/keys/asterisk.pem \
    -days 3650 \
    -subj "/CN=${ASTERISK_DOMAIN:-$PUBLIC_IP}"
  chown -R asterisk:asterisk /etc/asterisk/keys
  chmod 600 /etc/asterisk/keys/asterisk.key
fi

echo "==> Configurando PJSIP base e tronco Magnus"
cat > /etc/asterisk/pjsip_tauros_base.conf <<EOF_PJSIP
[global]
type=global
user_agent=Tauros-Asterisk

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=${PUBLIC_IP}
external_signaling_address=${PUBLIC_IP}
local_net=10.0.0.0/8
local_net=172.16.0.0/12
local_net=192.168.0.0/16

[transport-ws]
type=transport
protocol=ws
bind=0.0.0.0:${HTTP_PORT}
external_media_address=${PUBLIC_IP}
external_signaling_address=${PUBLIC_IP}

[magnus-auth]
type=auth
auth_type=userpass
username=${MAGNUS_USER}
password=${MAGNUS_SECRET}

[magnus-aor]
type=aor
contact=sip:${MAGNUS_HOST}:${MAGNUS_PORT}

[magnus]
type=endpoint
transport=transport-udp
context=from-magnus
disallow=all
allow=ulaw,alaw
aors=magnus-aor
outbound_auth=magnus-auth
from_user=${MAGNUS_FROM_USER}
from_domain=${MAGNUS_FROM_DOMAIN}
send_pai=yes
send_rpid=yes
trust_id_outbound=yes
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
media_address=${PUBLIC_IP}

[magnus-identify]
type=identify
endpoint=magnus
match=${MAGNUS_HOST}
EOF_PJSIP
write_if_missing_include /etc/asterisk/pjsip.conf pjsip_tauros_base.conf
write_if_missing_include /etc/asterisk/pjsip.conf pjsip_codex_agents.conf

echo "==> Configurando dialplan base"
cat > /etc/asterisk/extensions_tauros_base.conf <<EOF_EXT
[set-outbound-callerid]
exten => s,1,NoOp(Ajustando CallerID de saida)
 same => n,ExecIf(\$["\${ARG1}" != ""]?Set(CALLERID(num)=\${ARG1}))
 same => n,ExecIf(\$["\${ARG1}" != ""]?Set(CALLERID(name)=\${ARG1}))
 same => n,Return()

[from-magnus]
exten => _X.,1,NoOp(Entrada vinda do Magnus para \${EXTEN})
 same => n,Hangup()

[tauros-default-outbound]
exten => _X.,1,NoOp(Saida externa padrao via Magnus)
 same => n,Set(DEFAULT_CID=${DEFAULT_CALLERID})
 same => n,Set(OUTBOUND_CID=\${FILTER(0-9+,\${CAMPAIGN_CALLERID})})
 same => n,ExecIf(\$["\${OUTBOUND_CID}" = ""]?Set(OUTBOUND_CID=\${FILTER(0-9+,\${IVR_CALLERID})}))
 same => n,ExecIf(\$["\${OUTBOUND_CID}" = ""]?Set(OUTBOUND_CID=\${DEFAULT_CID}))
 same => n,ExecIf(\$["\${OUTBOUND_CID}" != ""]?Set(CALLERID(num)=\${OUTBOUND_CID}))
 same => n,ExecIf(\$["\${OUTBOUND_CID}" != ""]?Set(CALLERID(name)=\${OUTBOUND_CID}))
 same => n,Dial(PJSIP/\${EXTEN}@magnus,60,rtTb(set-outbound-callerid^s^1(\${OUTBOUND_CID})))
 same => n,Hangup()
EOF_EXT
write_if_missing_include /etc/asterisk/extensions.conf extensions_tauros_base.conf
write_if_missing_include /etc/asterisk/extensions.conf extensions_codex_agents.conf
write_if_missing_include /etc/asterisk/extensions.conf extensions_codex_ivrs.conf
write_if_missing_include /etc/asterisk/queues.conf queues_codex_discadora.conf

echo "==> Criando arquivos vazios para sincronizacao do painel"
touch /etc/asterisk/pjsip_codex_agents.conf
touch /etc/asterisk/queues_codex_discadora.conf
touch /etc/asterisk/extensions_codex_agents.conf
touch /etc/asterisk/extensions_codex_ivrs.conf
chown asterisk:asterisk /etc/asterisk/*codex*.conf /etc/asterisk/*tauros*.conf

if [[ "$INSTALL_TURN" == "1" ]]; then
  require_value TURN_USER
  require_value TURN_SECRET
  echo "==> Configurando coturn"
  sed -i 's/^#\?TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn || true
  cat > /etc/turnserver.conf <<EOF_TURN
listening-port=${TURN_PORT}
fingerprint
lt-cred-mech
user=${TURN_USER}:${TURN_SECRET}
realm=${TURN_REALM:-tauros.local}
external-ip=${PUBLIC_IP}
no-loopback-peers
no-multicast-peers
simple-log
EOF_TURN
  systemctl enable --now coturn
fi

if [[ "$CONFIGURE_UFW" == "1" ]]; then
  echo "==> Aplicando firewall UFW"
  ufw allow 22/tcp
  ufw allow 5060/udp
  ufw allow "${HTTP_PORT}/tcp"
  ufw allow from "${PANEL_AMI_ALLOW_IP}" to any port "${AMI_PORT}" proto tcp
  ufw allow "${RTP_START}:${RTP_END}/udp"
  if [[ "$INSTALL_TURN" == "1" ]]; then
    ufw allow "${TURN_PORT}/udp"
    ufw allow "${TURN_PORT}/tcp"
  fi
  ufw --force enable
fi

echo "==> Reiniciando Asterisk"
systemctl enable asterisk
systemctl restart asterisk
sleep 2
asterisk -rx "core show version" || true
asterisk -rx "http show status" || true
asterisk -rx "manager show settings" || true
asterisk -rx "pjsip show transports" || true

cat <<EOF_DONE

Instalacao Tauros Asterisk concluida.

Configure no painel:
AMI host: ${PUBLIC_IP}
AMI porta: ${AMI_PORT}
AMI usuario: ${AMI_USER}
AMI senha: a senha definida em AMI_SECRET
WebSocket: ws://${PUBLIC_IP}:${HTTP_PORT}/ws
TURN: turn:${PUBLIC_IP}:${TURN_PORT}?transport=udp

Agora sincronize ramais, filas e URAs pelo painel Tauros.
EOF_DONE

