# ISend 1.0.0

Transferencia de archivos por Wi-Fi entre el iPad y cualquier navegador.

## Qué incluye

- Servidor HTTP local en el iPad (puerto 8080 por defecto).
- Interfaz web adaptada a **ordenador** (arrastrar y soltar, carpetas) y a **móvil** (botones grandes, fotos/cámara, botón flotante).
- Subida por streaming al disco: los archivos no se cargan en memoria.
- Descarga de archivos, renombrado, borrado y creación de carpetas desde el navegador.
- Código QR en el iPad para abrir la interfaz desde el móvil sin escribir la IP.
- Sin nube, sin cuentas y sin instalar nada en el ordenador.

## Instalación

1. Descarga el `.ipa` de esta Release.
2. Conecta el iPad por USB y confía en el ordenador.
3. Instala con AppSync Unified (jailbreak) usando Filza o `ideviceinstaller -i ISend.ipa`.
4. Abre **ISend** y pulsa **Iniciar servidor**.
5. Conecta el ordenador o el móvil a la **misma Wi-Fi** y abre la dirección que aparece.

## Notas

- La app debe quedar abierta durante las transferencias. iOS 9 suspende los sockets al pasar a segundo plano y el servidor se detiene.
- Si no aparece la dirección, revisa que el iPad esté en Wi-Fi y que el puerto no esté ocupado.
- Publica siempre en redes de confianza: la interfaz no pide contraseña en esta versión.
