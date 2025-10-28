#!/bin/sh

# Limite de uso de memória
percent=70

# Total e memória livre
ramtotal=$(grep -F "MemTotal:" /proc/meminfo | awk '{print $2}')
ramlivre=$(grep -F "MemFree:" /proc/meminfo | awk '{print $2}')

# Memória utilizada e porcentagem
ramusada=$((ramtotal - ramlivre))
putil=$((ramusada * 100 / ramtotal))

# Log do estado atual
echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
date
echo "Memória total: $ramtotal kB"
echo "Memória livre: $ramlivre kB"
echo "Memória utilizada: $putil%"

if [ $putil -gt $percent ]; then
    # Log detalhado
    logfile="/var/log/memoria.log"
    [ ! -f $logfile ] && touch $logfile
    date >> $logfile
    echo "Memória acima de $percent%: $putil%" >> $logfile

    echo "Limpando cache e reiniciando SWAP..."
    sync
    echo 3 > /proc/sys/vm/drop_caches
    swapoff -a && swapon -a
else
    echo "Uso de memória abaixo do limite. Nenhuma ação necessária."
fi

echo "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
