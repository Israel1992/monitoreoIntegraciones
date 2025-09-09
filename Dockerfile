FROM alpine:latest

# Actualizar la lista de paquetes e instalar las dependencias
RUN apk update && \
    apk add --no-cache inetutils-telnet bash curl vim nano

# Crear el directorio monitor en el home del usuario
RUN mkdir /home/monitor

# Copiar la carpeta monitor y su contenido al directorio /home/monitor
COPY monitor /home/monitor

# Convertir múltiples archivos a formato Unix usando un bucle
RUN for file in /home/monitor/monitorVPN.sh /home/monitor/realtime.sh /home/monitor/start.sh /home/monitor/reset.sh /home/monitor/paramsApifiDEV /home/monitor/paramsApoloQA /home/monitor/paramsAresQA; do \
        sed -i 's/\r$//' "$file"; \
    done

# Opcional: Copiar archivos de tu aplicación a la imagen
# COPY . /app

# Opcional: Exponer puertos si tu aplicación lo requiere
# EXPOSE 8080

# Comando por defecto al iniciar el contenedor
CMD ["/bin/sh"]