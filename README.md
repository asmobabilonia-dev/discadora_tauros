# discadora_tauros

## Asterisk

O pacote de instalacao da VPS Asterisk fica em [`asterisk/`](asterisk/).

Instalacao rapida em uma VPS Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/asmobabilonia-dev/discadora_tauros.git
cd discadora_tauros/asterisk/install
cp tauros.env.example tauros.env
nano tauros.env
sudo bash install_asterisk_tauros.sh tauros.env
```
