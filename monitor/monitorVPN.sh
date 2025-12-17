#!/bin/bash

# --- CONFIGURACIÓN ---
# En Alpine, UTC+6 resta 6 horas (Hora CDMX)
export TZ="UTC+6"
logfile="monitoreo.log"
params="paramsAforePROD"
# ---------------------

declare -A hostlist

# Función para cargar los hosts del archivo
function getHost {
    unset hostlist
    declare -g -A hostlist

    if [ ! -f "$params" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Archivo $params no encontrado" >> "$logfile"
        return
    fi

    # Maneja archivos sin salto de línea final y elimina caracteres de Windows (\r)
    while IFS='=' read -r name ip || [ -n "$name" ]; do
        name=$(echo "$name" | tr -d '\r' | xargs 2>/dev/null)
        ip=$(echo "$ip" | tr -d '\r' | xargs 2>/dev/null)

        # Saltar líneas vacías o comentarios
        if [ -z "$name" ] || [[ "$name" == "#"* ]]; then
            continue
        fi
        
        hostlist["$name"]="$ip"
    done < "$params"
}

# Función para probar conexión y registrar log
function connect_and_log {
    local host_name=$1
    local host_info=${hostlist[$host_name]}
    
    # Separar IP y Puerto
    local host=${host_info%:*}
    local port=${host_info##*:}
    local ts=$(date '+%Y-%m-%d %H:%M:%S')

    # Intento de conexión silencioso (Bash TCP o Curl)
    # Se redirige todo a /dev/null para no ensuciar el nohup.out
    if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null || \
       timeout 3 curl -sk "https://$host:$port" >/dev/null 2>&1; then
        echo "$ts - OK    $host_name ($host:$port)" >> "$logfile"
    else
        echo "$ts - ERROR $host_name ($host:$port)" >> "$logfile"
    fi
}

# Limpiar el log o añadir encabezado al iniciar
echo "--- Iniciando monitoreo: $(date) ---" >> "$logfile"

# --- CICLO PRINCIPAL ---
while true; do
    getHost

    if [ ${#hostlist[@]} -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Alerta: No se cargaron hosts de $params" >> "$logfile"
    else
        # Obtener llaves y procesar una por una
        for host_name in $(printf "%s\n" "${!hostlist[@]}" | sort); do
            connect_and_log "$host_name"
        done
    fi

    echo "------------------------------------------------------------" >> "$logfile"
    
    # Esperar 5 minutos (300 segundos)
    sleep 300
done