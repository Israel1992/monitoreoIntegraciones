#!/bin/bash

# Configuración del archivo de log y otros parámetros
log_file_tmp="monitoreotmp.log"  # Archivo temporal
max_log_size=20 # Tamaño máximo del archivo en MB

# Verificar si el archivo de log existe, y crearlo si no existe
if [ ! -f "$log_file_tmp" ]; then
    touch "$log_file_tmp"
    echo "$(date) - Archivo de log '$log_file_tmp' creado." >> "$log_file_tmp"
fi

# Definimos un arreglo asociativo para almacenar los hosts y sus puertos
function getHost {
    while IFS== read -r p; do
        name=$(echo ${p%%=*})
        ip=$(echo ${p#*=} )
        hostlist[$name]="$ip"
    done < paramsQA
}

# Función para rotar el archivo de log (sin cambios)
# ... (código de la función rotate_log)

# Función para establecer una conexión telnet y registrar el resultado
function connect_and_log {
    local host_name=$1
    local host_info=${hostlist[$host_name]}
    local host=${host_info%%:*}
    local port=${host_info#*:}
    current_time=$(date +%s)
    eighteen_hours_ago=$((current_time - 6*60*60)) # Aunque no se usa, se mantiene por consistencia

    # Intenta telnet y curl con timeout de 2 segundos
    if timeout 2 telnet "$host" "$port" | grep -wq "Connected" || timeout 2 curl -v "$host":"$port" | grep -wq "Connected" ; then
        echo "$(date -d "@$current_time" +"%Y-%m-%d %H:%M:%S") - Conexión establecida a $host_name ($host:$port)" >> "$log_file_tmp"
    else
        echo "$(date -d "@$current_time" +"%Y-%m-%d %H:%M:%S") - Fallo al conectar a $host_name ($host:$port)" >> "$log_file_tmp"
    fi
}

# Bucle infinito
declare -A hostlist

# Iniciar tail en segundo plano para visualizar el log en tiempo real
tail -f "$log_file_tmp" &
tail_pid=$! # Guardar el PID del comando tail

while true; do
    getHost
    for host_name in "${!hostlist[@]}"; do
        connect_and_log "$host_name"
        unset hostlist["$host_name"] # Limpiar la variable para la siguiente iteración
    done
    echo "-------------------------------------------------------------------------" >> "$log_file_tmp"
    sleep 10  # Esperar 10 segundos
done

# Detener el tail al salir del script (opcional, pero recomendado)
kill "$tail_pid" 2>/dev/null # Ignorar el error si el proceso ya ha terminado
wait "$tail_pid" 2>/dev/null