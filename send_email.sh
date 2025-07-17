#!/bin/bash

# Script para enviar correos electrónicos

# Cargar variables del archivo .env
if [ -f "/opt/vpn-server/.env" ]; then
    source "/opt/vpn-server/.env"
else
    echo "Error: Archivo .env no encontrado. No se puede enviar el correo."
    exit 1
fi

SUBJECT="$1"
BODY="$2"

if [ -z "$SUBJECT" ] || [ -z "$BODY" ]; then
    echo "Uso: $0 \"Asunto del correo\" \"Cuerpo del correo\""
    exit 1
fi

if [ -z "$SMTP_SERVER" ] || [ -z "$SMTP_PORT" ] || [ -z "$SMTP_USERNAME" ] || [ -z "$SMTP_PASSWORD" ] || [ -z "$NOTIFICATION_RECIPIENT" ]; then
    echo "Error: Variables SMTP no configuradas en .env. No se puede enviar el correo."
    exit 1
fi

# Construir el cuerpo del correo en formato MIME
EMAIL_CONTENT="Subject: $SUBJECT\r\n"
EMAIL_CONTENT+="To: $NOTIFICATION_RECIPIENT\r\n"
EMAIL_CONTENT+="From: $SMTP_USERNAME\r\n"
EMAIL_CONTENT+="Content-Type: text/plain; charset=\"UTF-8\"\r\n\r\n"
EMAIL_CONTENT+="$BODY"

# Enviar el correo usando curl
curl --url "smtp://$SMTP_SERVER:$SMTP_PORT" \
     --ssl-reqd \
     --mail-from "$SMTP_USERNAME" \
     --mail-rcpt "$NOTIFICATION_RECIPIENT" \
     --user "$SMTP_USERNAME:$SMTP_PASSWORD" \
     --upload-file <(echo -e "$EMAIL_CONTENT")

if [ $? -eq 0 ]; then
    echo "Correo enviado exitosamente a $NOTIFICATION_RECIPIENT"
else
    echo "Error al enviar el correo."
fi
