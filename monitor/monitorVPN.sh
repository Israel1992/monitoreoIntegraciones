#!/bin/bash

# --- CONFIGURACIÓN ---
# Forzamos la zona horaria de CDMX para todo el script
export TZ="America/Mexico_City"
logfile="monitoreo.log"
params="paramsAforePROD"
# ---------------------

declare -A hostlist

function getHost {
    unset hostlist
    declare -g -A hostlist
    if [ ! -f "$params" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Archivo $params no encontrado" >> "$logfile"
        return
    fi

    while IFS='=' read -r name ip || [ -n "$name" ]; do
        name=$(echo "$name" | tr -d '\r' | xargs 2>/dev/null)
        ip=$(echo "$ip" | tr -d '\r' | xargs 2>/dev/null)
        if [ -z "$name" ] || [[ "$name" == "#"* ]]; then
            continue
        fi
        hostlist["$name"]="$ip"
    done < "$params"
}

function connect_and_log {
    local host_name=$1
    local host_info=${hostlist[$host_name]}
    local host=${host_info%:*}
    local port=${host_info##*:}
    local ts=$(date '+%Y-%m-%d %H:%M:%S')

    # Intentamos conexión silenciosa
    # Probamos /dev/tcp y si falla probamos curl
    timeout 3 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null || \
    timeout 3 curl -sk "https://$host:$port" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "$ts - OK    $host_name ($host:$port)" >> "$logfile"
    else
        echo "$ts - ERROR $host_name ($host:$port)" >> "$logfile"
    fi
}

# Reiniciar el log cada vez que inicies el script (opcional)
echo "--- Iniciando monitoreo: $(date) ---" >> "$logfile"

while true; do
    getHost
    if [ ${#hostlist[@]} -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Alerta: No hay hosts en $params" >> "$logfile"
    else
        # Ordenar y procesar
        for host_name in $(printf "%s\n" "${!hostlist[@]}" | sort); do
            connect_and_log "$host_name"
        done
    fi
    echo "------------------------------------------------------------" >> "$logfile"
    sleep 300
done