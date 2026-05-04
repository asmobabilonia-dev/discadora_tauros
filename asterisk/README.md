# Tauros Asterisk Server

Pacote para instalar e recriar uma VPS Asterisk usada pela Discadora Tauros.

Este diretório nao guarda senhas reais. Use `install/tauros.env.example` como base e preencha os dados da nova VPS, do MagnusBilling e do painel.

## O que o instalador prepara

- Asterisk com PJSIP, HTTP WebSocket e RTP para WebRTC.
- AMI para o painel/discadora.
- Tronco PJSIP para o MagnusBilling.
- Includes isolados da Tauros em `/etc/asterisk`.
- Contextos base `from-webrtc`, `from-agents`, `from-magnus` e `set-outbound-callerid`.
- Firewall opcional com portas SIP, WebSocket, AMI, RTP e TURN.
- Coturn opcional para WebRTC.

## Uso rapido

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/asmobabilonia-dev/discadora_tauros.git
cd discadora_tauros/asterisk/install
cp tauros.env.example tauros.env
nano tauros.env
sudo bash install_asterisk_tauros.sh tauros.env
```

Depois de instalar:

1. Entre no painel Tauros.
2. Configure `Asterisk SSH`, `AMI`, IP publico e segredo do AMI.
3. Clique em sincronizar ramais/filas/URAs.
4. Abra a pagina do atendente para registrar o ramal WebRTC.
5. Teste uma chamada curta antes de liberar campanhas.

## Arquivos criados no servidor

- `/etc/asterisk/http_tauros.conf`
- `/etc/asterisk/rtp_tauros.conf`
- `/etc/asterisk/manager_tauros.conf`
- `/etc/asterisk/pjsip_tauros_base.conf`
- `/etc/asterisk/extensions_tauros_base.conf`

O painel cria/sobrescreve estes arquivos separados:

- `/etc/asterisk/pjsip_codex_agents.conf`
- `/etc/asterisk/queues_codex_discadora.conf`
- `/etc/asterisk/extensions_codex_agents.conf`
- `/etc/asterisk/extensions_codex_ivrs.conf`

## Portas importantes

- `5060/udp`: SIP para Magnus.
- `8088/tcp`: WebSocket HTTP do Asterisk.
- `5038/tcp`: AMI, restrinja ao IP do painel.
- `10000:20000/udp`: RTP.
- `3478/tcp/udp`: TURN, se ativado.

## Seguranca

- Nunca commite `tauros.env` preenchido.
- Restrinja AMI ao IP do painel.
- Use senha forte em `AMI_SECRET`, `MAGNUS_SECRET` e TURN.
- Mantenha `allow_guest=no` no PJSIP.

