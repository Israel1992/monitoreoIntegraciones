#!/bin/bash

logfile="monitoreo.log"
params="paramsAforePROD"

declare -A hostlist

function getHost {
    # Limpiamos el array anterior
    unset hostlist
    declare -g -A hostlist

    # La clave es: || [[ -n "$line" ]] 
    # Esto obliga a procesar la línea incluso si no tiene un salto de línea al final
    while IFS='=' read -r name ip || [[ -n "$name" ]]; do
        # Limpieza de caracteres especiales y espacios
        name=$(echo "$name" | tr -d '\r' | xargs)
        ip=$(echo "$ip" | tr -d '\r' | xargs)

        [ -z "$name" ] && continue
        
        hostlist["$name"]="$ip"
    done < "$params"
}

function connect_and_log {
    local host_name=$1
    local host_info=${hostlist[$host_name]}
    local host=${host_info%%:*}
    local port=${host_info#*:}
    local ts=$(date '+%Y-%m-%d %H:%M:%S')

    # Usamos /dev/tcp para una verificación más rápida y nativa en Bash
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        echo "$ts - OK    $host_name ($host:$port)" >> "$logfile"
    elif timeout 3 curl -sk "https://$host:$port" >/dev/null 2>&1; then
        echo "$ts - OK    $host_name ($host:$port)" >> "$logfile"
    else
        echo "$ts - ERROR $host_name ($host:$port)" >> "$logfile"
    fi
}

while true; do
    getHost

    if [ ${#hostlist[@]} -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Alerta: No se detectaron hosts" >> "$logfile"
    else
        # Ordenar las llaves y ejecutar
        for host_name in $(printf "%s\n" "${!hostlist[@]}" | sort); do
            connect_and_log "$host_name"
        done
    fi

    echo "------------------------------------------------------------" >> "$logfile"
    sleep 300
done