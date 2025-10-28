#!/bin/sh

BACKUP_DIR="/backup/var"
LOG_DIR="/var/log"
DATA=$(date +%d.%m.%y-%H:%M)

# Criar diretório se não existir
mkdir -p "$BACKUP_DIR"

# Backup dos logs
tar -zcvf "$BACKUP_DIR/log-$DATA.tar.gz" "$LOG_DIR"

# Limpeza dos logs
find "$LOG_DIR" -type f -exec truncate -s 0 {} \;

# Remover backups antigos (+3 dias)
find "$BACKUP_DIR" -name "*.tar.gz" -ctime +3 -exec rm -f {} \;

# Limpeza de cache do APT
rm -rf /var/cache/apt/archives/*
rm -rf /var/lib/apt/lists/*

journalctl --vacuum-time=3d
