#!/bin/bash

logfile="monitoreo.log"

declare -A hostlist

function getHost {
    hostlist=()
    while IFS='=' read -r name ip; do
        [ -z "$name" ] && continue
        hostlist["$name"]="$ip"
    done < paramsApifiDEV
}

function connect_and_log {
    local host_name=$1
    local host_info=${hostlist[$host_name]}
    local host=${host_info%%:*}
    local port=${host_info#*:}
    local ts

    ts=$(date '+%Y-%m-%d %H:%M:%S')

    if timeout 3 nc -z "$host" "$port"; then
        echo "$ts - OK    $host_name ($host:$port)" >> "$logfile"
    else
        echo "$ts - ERROR $host_name ($host:$port)" >> "$logfile"
    fi
}

while true; do
    getHost

    sorted_keys=($(printf "%s\n" "${!hostlist[@]}" | sort))

    for host_name in "${sorted_keys[@]}"; do
        connect_and_log "$host_name"
    done

    echo "------------------------------------------------------------" >> "$logfile"
    sleep 300
done
