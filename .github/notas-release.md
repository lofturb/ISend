# ISend 1.0.2

Transferencia de archivos por Wi-Fi entre el iPad y cualquier navegador.

## Qué incluye

- Servidor HTTP local en el iPad (puerto 8080 por defecto).
- Interfaz web adaptada a **ordenador** (arrastrar y soltar, carpetas) y a **móvil** (botones grandes, fotos/cámara, botón flotante).
- Subida por streaming al disco: los archivos no se cargan en memoria.
- Descarga de archivos, renombrado, borrado y creación de carpetas desde el navegador.
- Código QR en el iPad para abrir la interfaz desde el móvil sin escribir la IP.
- Sin nube, sin cuentas y sin instalar nada en el ordenador.

## Cambios de la 1.0.2

- **Arreglada la subida de archivos.** El servidor escribía en disco con `send()`, que solo funciona con sockets: fallaba con `ENOTSOCK` y abortaba cualquier subida con "error de red" en el navegador. Ahora usa `write()`.
- La versión que muestra la app y la API se lee del `Info.plist`, así que ya no puede quedarse desfasada del build instalado.
- Si una subida se corta, la respuesta incluye un código de error numérico para poder diagnosticarla.
- **La pantalla ya no se bloquea** mientras el servidor está activo. Antes, el bloqueo automático a los 2 minutos suspendía la app y cortaba la transferencia en curso.
- Al volver del segundo plano el servidor se reintenta hasta 4 veces en lugar de apagarse para siempre.
- Margen de ejecución en segundo plano para terminar lo que esté en curso.
- El servidor libera los sockets activos al detenerse y da más margen al cuerpo de una subida.

## Instalación

1. Descarga el `.ipa` de esta Release.
2. Conecta el iPad por USB y confía en el ordenador.
3. Instala con AppSync Unified (jailbreak) usando Filza o `ideviceinstaller -i ISend.ipa`.
4. Abre **ISend**: el servidor arranca solo con la última dirección y puerto usados.
5. Conecta el ordenador o el móvil a la **misma Wi-Fi** y abre la dirección que aparece.

## Notas

- La app debe quedar abierta durante las transferencias: iOS 9 suspende los procesos en segundo plano.
- Si no aparece la dirección, revisa que el iPad esté en Wi-Fi y que el puerto no esté ocupado.
- Ambos equipos tienen que estar en la **misma red**: dos Wi-Fi distintas (por ejemplo `192.168.0.x` y `192.168.1.x`) no se ven aunque el router sea el mismo.
- Publica siempre en redes de confianza: la interfaz no pide contraseña en esta versión.
