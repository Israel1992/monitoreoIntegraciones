#!/bin/bash

# --- CONFIGURACIÓN ---
export TZ="America/Mexico_City"
logfile="monitoreo.log"
params="paramsAforePROD"
# ---------------------

declare -A hostlist

# Función para cargar los hosts del archivo
function getHost {
    unset hostlist
    declare -g -A hostlist

    if [[ ! -f "$params" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Archivo $params no encontrado" >> "$logfile"
        return
    fi

    # El '|| [[ -n "$line" ]]' permite leer la última línea si no tiene salto de línea
    while IFS='=' read -r name ip || [[ -n "$name" ]]; do
        # Limpieza de espacios y saltos de línea de Windows (\r)
        name=$(echo "$name" | tr -d '\r' | xargs)
        ip=$(echo "$ip" | tr -d '\r' | xargs)

        # Saltar líneas vacías o comentarios
        [[ -z "$name" || "$name" == #* ]] && continue
        
        hostlist["$name"]="$ip"
    done < "$params"
}

# Función para probar conexión y registrar log
function connect_and_log {
    local host_name=$1
    local host_info=${hostlist[$host_name]}
    
    # Separar IP y Puerto (maneja formato ip:puerto)
    local host=${host_info%:*}
    local port=${host_info##*:}
    local ts=$(date '+%Y-%m-%d %H:%M:%S')

    # Intento 1: Bash nativo (rápido) | Intento 2: Curl (para servicios HTTPS)
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null || \
       timeout 3 curl -sk "https://$host:$port" >/dev/null 2>&1; then
        echo "$ts - OK    $host_name ($host:$port)" >> "$logfile"
    else
        echo "$ts - ERROR $host_name ($host:$port)" >> "$logfile"
    fi
}

# --- CICLO PRINCIPAL ---
while true; do
    getHost

    if [ ${#hostlist[@]} -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Alerta: No se cargaron hosts de $params" >> "$logfile"
    else
        # Obtener llaves ordenadas y procesar
        sorted_keys=$(printf "%s\n" "${!hostlist[@]}" | sort)
        for host_name in $sorted_keys; do
            connect_and_log "$host_name"
        done
    fi

    echo "------------------------------------------------------------" >> "$logfile"
    
    # Esperar 5 minutos para la siguiente vuelta
    sleep 300
done