#!/bin/bash
# Script de instalação automática do fix-hestia-watch
# Autor: ChatGPT

SCRIPT_URL="https://raw.githubusercontent.com/Sage-BR/4tweb/refs/heads/main/fix-hestia-watch.sh"
SCRIPT_PATH="/usr/local/bin/fix-hestia-watch.sh"
SERVICE_PATH="/etc/systemd/system/fix-hestia-watch.service"

echo "=== Instalando fix-hestia-watch ==="
apt update
apt install inotify-tools -y

# 1. Baixar o script
echo "[1/5] Baixando script..."
wget -O "$SCRIPT_PATH" "$SCRIPT_URL"
chmod +x "$SCRIPT_PATH"

# 2. Criar o service systemd
echo "[2/5] Criando service systemd..."
cat > "$SERVICE_PATH" <<EOL
[Unit]
Description=Fix HestiaCP permissions in real-time
After=network.target

[Service]
ExecStart=$SCRIPT_PATH
Restart=always
RestartSec=2
User=root

[Install]
WantedBy=multi-user.target
EOL

# 3. Recarregar systemd
echo "[3/5] Recarregando systemd..."
systemctl daemon-reload

# 4. Ativar e iniciar serviço
echo "[4/5] Ativando e iniciando serviço..."
systemctl enable --now fix-hestia-watch

# 5. Status inicial
echo "[5/5] Serviço instalado com sucesso! Para ver logs em tempo real, use:"
echo "       journalctl -u fix-hestia-watch -f"

echo "=== Instalação concluída ==="
