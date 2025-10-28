#!/bin/bash
set -e

echo "Iniciando atualização em $(date)"

apt update
apt -y dist-upgrade
apt -y autoremove
apt clean

# Remove pacotes com config residual (rc)
RESIDUAL_PKGS=$(dpkg -l | awk '/^rc/ { print $2 }')
if [ -n "$RESIDUAL_PKGS" ]; then
  apt purge -y $RESIDUAL_PKGS
fi

echo "Atualização concluída em $(date)"
