#!/bin/bash

logfile="monitoreo.log"
params_file="paramsAforePROD"

# Asegurarse de que el archivo de logs exista
touch "$logfile"

function getHost {
    # Limpiamos el array asociativo antes de recargar
    unset hostlist
    declare -g -A hostlist

    # Verificamos si el archivo existe
    if [[ ! -f "$params_file" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Archivo $params_file no encontrado" >> "$logfile"
        return
    fi

    # Leemos línea por línea
    while IFS='=' read -r name ip || [[ -n "$name" ]]; do
        # Eliminar espacios en blanco y retornos de carro
        name=$(echo "$name" | tr -d '\r' | x26s) # x26s elimina espacios
        ip=$(echo "$ip" | tr -d '\r' | x26s)
        
        [[ -z "$name" || -z "$ip" ]] && continue
        
        hostlist["$name"]="$ip"
    done < "$params_file"
}

function connect_and_log {
    local host_name=$1
    local host_info=${hostlist[$host_name]}
    
    # Separar IP y Puerto
    local host=${host_info%%:*}
    local port=${host_info#*:}
    local ts=$(date '+%Y-%m-%d %H:%M:%S')

    # Intento de conexión (Telnet o Curl)
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null || \
       timeout 3 curl -sk "https://$host:$port" >/dev/null 2>&1; then
        echo "$ts - OK    $host_name ($host:$port)" >> "$logfile"
    else
        echo "$ts - ERROR $host_name ($host:$port)" >> "$logfile"
    fi
}

while true; do
    getHost

    # Verificar si el array está vacío
    if [ ${#hostlist[@]} -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Alerta: No se cargaron hosts de $params_file" >> "$logfile"
    else
        # Ordenar y ejecutar
        sorted_keys=($(printf "%s\n" "${!hostlist[@]}" | sort))
        for host_name in "${sorted_keys[@]}"; do
            connect_and_log "$host_name"
        done
    fi

    echo "------------------------------------------------------------" >> "$logfile"
    sleep 300
done
