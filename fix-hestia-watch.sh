#!/bin/bash
# ============================================
# HestiaCP Permission Watcher
# Mantém permissões corretas em /home
# Ignora áreas críticas como DNS, logs e tmp
# ============================================

echo "=== Iniciando monitor de permissões HestiaCP (web, mail e DNS) ==="

log() {
    logger -t fix-hestia-watch "$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Função para corrigir permissões do BIND
fix_bind_permissions() {
    log "[BIND] Corrigindo permissões de DNS em /home/*/conf/dns"
    
    for dns_dir in /home/*/conf/dns; do
        [ -d "$dns_dir" ] || continue
        
        USER=$(echo "$dns_dir" | cut -d'/' -f3)
        
        # Proprietário dos arquivos .db deve ser o usuário, mas BIND precisa ler
        chown -R "$USER:bind" "$dns_dir" 2>/dev/null
        
        # Diretório precisa de 750 para bind atravessar
        chmod 750 "$dns_dir"
        
        # Arquivos .db precisam de 644 para bind ler
        find "$dns_dir" -type f -name "*.db" -exec chmod 644 {} \; 2>/dev/null
        
        log "[BIND] Corrigido: $dns_dir"
    done
}

# Função para garantir que bind possa atravessar diretórios
fix_home_access() {
    log "[HOME] Garantindo acesso de leitura aos diretórios home"
    
    for home_dir in /home/*; do
        [ -d "$home_dir" ] || continue
        
        # 711 permite que bind atravesse o diretório sem listar conteúdo
        chmod 711 "$home_dir" 2>/dev/null
        
        # Garante que /conf também seja atravessável
        [ -d "$home_dir/conf" ] && chmod 711 "$home_dir/conf" 2>/dev/null
    done
}

# Função para corrigir dono de arquivos web
fix_owner() {
    FILE="$1"
    USER=$(echo "$FILE" | cut -d'/' -f3)
    
    # Ignorar diretórios críticos (DNS, mail, logs, tmp, cache)
    if [[ "$FILE" =~ (tmp|cache|logs?|conf/dns|conf/mail)/? ]]; then
        return
    fi
    
    if [ -n "$USER" ] && [ -d "/home/$USER" ]; then
        log "[FIX] Corrigindo dono de $FILE para $USER:$USER"
        chown -R "$USER:$USER" "$FILE" 2>/dev/null
    fi
}

# Função para corrigir permissões de e-mails
fix_mail_permissions() {
    FILE="$1"
    
    if [[ "$FILE" =~ /home/[^/]+/conf/mail/[^/]+/ ]]; then
        DOMAIN_DIR=$(echo "$FILE" | grep -oP '/home/[^/]+/conf/mail/[^/]+' | head -1)
        
        if [ -d "$DOMAIN_DIR" ]; then
            log "[MAIL] Corrigindo permissões em $DOMAIN_DIR"
            
            chmod 750 "$DOMAIN_DIR"
            chgrp mail "$DOMAIN_DIR"
            
            for file in limits ip accounts aliases passwd dkim.pem fwd_only antispam; do
                if [ -f "$DOMAIN_DIR/$file" ]; then
                    chmod 640 "$DOMAIN_DIR/$file"
                    chgrp mail "$DOMAIN_DIR/$file"
                fi
            done
            
            # passwd precisa ser do Dovecot
            if [ -f "$DOMAIN_DIR/passwd" ]; then
                chown dovecot:mail "$DOMAIN_DIR/passwd"
                chmod 640 "$DOMAIN_DIR/passwd"
            fi
        fi
    fi
}

# ============================================
# EXECUÇÃO INICIAL
# ============================================

log "Aplicando correções iniciais..."

# Garantir grupos essenciais
usermod -aG mail dovecot 2>/dev/null
log "Dovecot adicionado ao grupo mail"

# Corrigir acessos
fix_home_access
fix_bind_permissions

# Recarregar BIND para aplicar mudanças
if systemctl reload bind9 2>/dev/null; then
    log "[BIND] Serviço recarregado com sucesso"
else
    log "[BIND] ERRO ao recarregar serviço"
fi

# Verificar se há erros de permissão
BIND_ERRORS=$(grep "permission denied" /var/log/syslog | grep named | tail -5)
if [ -n "$BIND_ERRORS" ]; then
    log "[BIND] ATENÇÃO: Ainda há erros de permissão:"
    echo "$BIND_ERRORS"
else
    log "[BIND] Nenhum erro de permissão detectado"
fi

# ============================================
# MONITORAMENTO CONTÍNUO
# ============================================

log "Iniciando monitoramento contínuo de /home"

inotifywait -m -r -e create,modify,move,moved_to /home --format '%w%f' 2>/dev/null |
while read NEWFILE; do
    # Ignorar arquivos temporários
    if [[ "$NEWFILE" =~ (tmp|cache|logs?)/? ]]; then
        continue
    fi
    
    # Detectar novos public_html
    if [[ "$NEWFILE" == */public_html ]] && [ -d "$NEWFILE" ]; then
        USER=$(echo "$NEWFILE" | cut -d'/' -f3)
        log "[NEW SITE] Detectado $NEWFILE para usuário $USER"
        
        setfacl -R -m u:$USER:rwx "$NEWFILE" 2>/dev/null
        setfacl -R -d -m u:$USER:rwx "$NEWFILE" 2>/dev/null
        chmod g+s "$NEWFILE" 2>/dev/null
    fi
    
    # Corrigir proprietários web
    fix_owner "$NEWFILE"
    
    # Corrigir permissões de email
    fix_mail_permissions "$NEWFILE"
    
    # Reforçar DNS se novos arquivos forem criados em conf/dns
    if [[ "$NEWFILE" =~ /conf/dns/ ]]; then
        log "[BIND] Detectada alteração em $NEWFILE"
        fix_bind_permissions
        
        if systemctl reload bind9 2>/dev/null; then
            log "[BIND] Recarregado com sucesso"
        else
            log "[BIND] ERRO ao recarregar"
        fi
    fi
done
