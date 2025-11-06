#!/bin/bash
# Monitorar public_html e conf/mail do HestiaCP
# Corrigir donos e permissões automaticamente
# Logs enviados para systemd journal

echo "=== Iniciando monitor de permissões HestiaCP (sites e e-mails) ==="

log_web() {
    logger -t fix-hestia-watch "$1"
}

log_mail() {
    logger -t fix-mail-watch "$1"
}

fix_owner() {
    FILE="$1"
    USER=$(echo "$FILE" | cut -d'/' -f3)
    
    # Ignorar diretórios temporários, cache e logs
    if [[ "$FILE" =~ (tmp|cache|logs?)/? ]]; then
        return
    fi
    
    if [ -n "$USER" ]; then
        log_web "[FIX] Corrigindo dono de $FILE para $USER:$USER"
        chown -R "$USER:$USER" "$FILE"
    fi
}

fix_mail_permissions() {
    FILE="$1"
    
    # Verificar se é um diretório conf/mail
    if [[ "$FILE" =~ /home/[^/]+/conf/mail/[^/]+/ ]]; then
        DOMAIN_DIR=$(echo "$FILE" | grep -oP '/home/[^/]+/conf/mail/[^/]+' | head -1)
        
        if [ -d "$DOMAIN_DIR" ]; then
            log_mail "[FIX MAIL] Corrigindo permissões em $DOMAIN_DIR"
            
            chmod 750 "$DOMAIN_DIR"
            chgrp mail "$DOMAIN_DIR"
            
            for file in limits ip accounts aliases passwd dkim.pem fwd_only antispam; do
                if [ -f "$DOMAIN_DIR/$file" ]; then
                    chmod 640 "$DOMAIN_DIR/$file"
                    chgrp mail "$DOMAIN_DIR/$file"
                fi
            done
            
            # passwd precisa ser do dovecot
            if [ -f "$DOMAIN_DIR/passwd" ]; then
                chown dovecot:mail "$DOMAIN_DIR/passwd"
                chmod 640 "$DOMAIN_DIR/passwd"
            fi
        fi
    fi
}

log_web "Serviço iniciado e monitorando /home (web + email)"
log_mail "Serviço iniciado e monitorando /home/*/conf/mail/"

# Garantir que dovecot está no grupo mail
usermod -aG mail dovecot 2>/dev/null

# Monitorar tudo sob /home
inotifywait -m -r -e create,modify,move,moved_to /home --format '%w%f' 2>/dev/null |
while read NEWFILE; do
    # Ignorar diretórios de cache/log/tmp
    if [[ "$NEWFILE" =~ (tmp|cache|logs?)/? ]]; then
        continue
    fi
    
    # Detectar novos public_html
    if [[ "$NEWFILE" == */public_html ]]; then
        USER=$(echo "$NEWFILE" | cut -d'/' -f3)
        log_web "[NEW SITE] Detectado $NEWFILE para usuário $USER"
        setfacl -R -m u:$USER:rwx "$NEWFILE"
        setfacl -R -d -m u:$USER:rwx "$NEWFILE"
        chmod g+s "$NEWFILE"
    fi

    # Corrigir dono e permissões conforme tipo
    fix_owner "$NEWFILE"
    fix_mail_permissions "$NEWFILE"
done
