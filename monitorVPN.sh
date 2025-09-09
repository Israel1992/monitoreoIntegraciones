#!/bin/bash/

# Configuración del archivo de log y otros parámetros
logfile="monitoreo.log"
max_log_size=20 # Tamaño máximo del archivo en MB

# Definimos un arreglo asociativo para almacenar los hosts y sus puertos
function getHost {
    while IFS== read -r p; do
        name=$(echo ${p%%=*})
        ip=$(echo ${p#*=})
        hostlist[$name]="$ip"
    done < paramsApifiDEV
}

# Función para establecer una conexión telnet y registrar el resultado
function connect_and_log {
    local host_name=$1
    local host_info=${hostlist[$host_name]}
    local host=${host_info%%:*}
    local port=${host_info#*:}
    current_time=$(date +%s)
    eighteen_hours_ago=$((current_time - 6*60*60))
    if timeout 2 telnet "$host" "$port" | grep -wq "Connected" || timeout 2 curl -v "$host":"$port" | grep -wq "Connected"; then
        echo "$(date -d "@$eighteen_hours_ago" +"%Y-%m-%d %H:%M:%S") - Conexión establecida a $host_name ($host:$port)"
    else
        echo "$(date -d "@$eighteen_hours_ago" +"%Y-%m-%d %H:%M:%S") - Fallo al conectar a $host_name ($host:$port)"
    fi >> "$logfile"
}

# Bucle infinito
declare -A hostlist
while true; do
    getHost
    # Obtenemos las claves del arreglo y las ordenamos alfabéticamente
    local sorted_keys=($(printf "%s\n" "${!hostlist[@]}" | sort))
    for host_name in "${sorted_keys[@]}"; do
        connect_and_log "$host_name"
    done
    echo "-------------------------------------------------------------------------" >> "$logfile"
    sleep 300
done
