#!/bin/bash

# --- CONFIGURACIÓN ---
logfile="monitoreo.log"
params="paramsAforePROD"
# Ajuste de horas: Si tu servidor está en UTC y quieres hora CDMX, restamos 6.
# Si el desfase cambia, solo ajusta el número.
HORA_AJUSTE="6 hours ago"
# ---------------------

declare -A hostlist

function getHost {
    unset hostlist
    declare -g -A hostlist
    if [ ! -f "$params" ]; then
        echo "$(date -d "$HORA_AJUSTE" '+%Y-%m-%d %H:%M:%S') - ERROR: Archivo $params no encontrado" >> "$logfile"
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
    # Aplicamos el ajuste de hora aquí
    local ts=$(date -d "$HORA_AJUSTE" '+%Y-%m-%d %H:%M:%S')

    # Intentos de conexión
    # El 2>/dev/null final evita que los mensajes de "Terminated" salgan al nohup.out
    {
        timeout 3 bash -c "cat < /dev/null > /dev/tcp/$host/$port" || \
        timeout 3 curl -sk "https://$host:$port" >/dev/null
    } >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo "$ts - OK    $host_name ($host:$port)" >> "$logfile"
    else
        echo "$ts - ERROR $host_name ($host:$port)" >> "$logfile"
    fi
}

while true; do
    getHost
    if [ ${#hostlist[@]} -eq 0 ]; then
        echo "$(date -d "$HORA_AJUSTE" '+%Y-%m-%d %H:%M:%S') - Alerta: No hay hosts" >> "$logfile"
    else
        for host_name in $(printf "%s\n" "${!hostlist[@]}" | sort); do
            connect_and_log "$host_name"
        done
    fi
    echo "------------------------------------------------------------" >> "$logfile"
    sleep 300
done