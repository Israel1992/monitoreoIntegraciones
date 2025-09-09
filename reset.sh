#!/bin/bash

# 1. Verificar si el proceso monitorVPN.sh está en ejecución
if ps aux | grep -q "monitorVPN.sh"; then
  echo "El proceso monitorVPN.sh está en ejecución."

  # 2. Obtener los PIDs de los procesos monitorVPN.sh
  pids=$(ps aux | grep "monitorVPN.sh" | awk '{print $2}')

  # 3. Matar los procesos monitorVPN.sh
  echo "Matando procesos monitorVPN.sh con PIDs: $pids"
  kill $pids

  # Esperar un breve momento para que los procesos se cierren
  sleep 2

  # 4. Verificar si los procesos fueron eliminados
  if ps aux | grep -q "monitorVPN.sh"; then
    echo "No se pudieron matar algunos procesos monitorVPN.sh."
  else
    echo "Todos los procesos monitorVPN.sh han sido eliminados."
  fi
else
  echo "El proceso monitorVPN.sh no está en ejecución."
fi

# 5. Ejecutar monitorVPN.sh en segundo plano con nohup
echo "Ejecutando monitorVPN.sh en segundo plano..."
nohup /bin/bash /home/monitor/monitorVPN.sh &

echo "monitorVPN.sh ha sido iniciado."