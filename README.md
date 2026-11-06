# ISend

Transferencia de archivos por Wi-Fi entre un **iPad mini 1** (o cualquier iPad/iOS 9) y **cualquier ordenador o móvil**, usando solo el navegador.

ISend abre un pequeño servidor HTTP dentro de la app y sirve una interfaz web adaptada a ordenador y a móvil. No hay nube, no hay cuentas y no hace falta instalar nada en el otro dispositivo.

---

## Por qué existe

Xender **no es open source**: es freeware propietario. Además, Xender, LocalSend, SHAREit y AirDrop piden versiones de iOS muy superiores a la última que admite el iPad mini 1 (**iOS 9.3.6**, ARMv7, 512 MB de RAM). No hay forma de instalarlas ahí.

ISend toma el camino que sí funciona en ese hardware:

```
  PC / móvil                         iPad mini 1
 ┌───────────────┐    Wi-Fi local   ┌──────────────────────┐
 │ Navegador     │ ◄──────────────► │ ISend (servidor HTTP) │
 │ (Chrome,      │   http://IP:8080 │  ├─ interfaz web       │
 │  Safari, ...) │                  │  ├─ cola de subidas    │
 └───────────────┘                  │  └─ carpeta compartida │
                                    └──────────────────────┘
```

- **PC → iPad**: arrastras archivos o carpetas en el navegador y se guardan en el iPad.
- **iPad → PC**: navegas por las carpetas del iPad y descargas con un clic.
- **Móvil**: la misma página se adapta; incluye botones grandes, acceso a fotos/cámara y un botón flotante para subir.

---

## Características

### Servidor

- HTTP/1.1 en el puerto 8080 (configurable entre 1024 y 65535).
- Streaming directo a disco: un archivo de 500 MB no se carga en RAM.
- Subidas `PUT` normales y `Transfer-Encoding: chunked`.
- Descargas con soporte de `Range` (vídeo/audio en el navegador, reanudar descargas).
- Listado JSON, creación de carpetas, renombrado y borrado.
- Protección contra `../`: todo se resuelve dentro de la carpeta publicada.
- HTML/SVG subidos se sirven como texto plano para que no puedan ejecutar scripts con el origen de la interfaz.

### Interfaz web (PC y móvil)

- Arrastrar y soltar **archivos y carpetas** (incluidas carpetas anidadas en escritorio).
- Cola con progreso, velocidad implícita y cancelación.
- Explorador con migas de pan, filtro por nombre y acciones por archivo.
- Descarga directa, previsualización de imágenes/vídeo/PDF en el navegador.
- Diseño oscuro, botones táctiles de 44 px y hoja de estilos sin Grid ni variables CSS (compatible con Safari 9).
- Se puede añadir a la pantalla de inicio del iPhone/iPad y abrir a pantalla completa.

### App nativa

- Código QR con la dirección para escanear desde el móvil.
- Carpeta compartida configurable: Documentos de ISend, `/var/mobile/Documents` o `/`.
- Explorador nativo de la carpeta compartida, con QuickLook, compartir, renombrar y borrar.
- Interruptores para desactivar subidas o borrados desde el navegador.
- El servidor se detiene al pasar a segundo plano y se reanuda al volver.

---

## Requisitos

**iPad**
- iPad mini 1 / iPad 2 o similar, iOS 9.0–9.3.6, ARMv7.
- Jailbreak con Cydia/Sileo y **AppSync Unified**.
- Opcional: Filza para instalar el `.ipa` sin PC.

**Ordenador / móvil**
- Cualquier navegador moderno y estar en la **misma red Wi-Fi** que el iPad.

---

## Instalación

### Desde una Release (recomendado)

1. Descarga el `.ipa` de la última Release (`com.lofturb.isend_1.0.0_*.ipa`).
2. Conecta el iPad y confía en el ordenador.
3. Instala:

```powershell
$bin = "C:\ruta\a\libimobiledevice\ucrt64\bin"
& "$bin\idevice_id.exe" -l
& "$bin\ideviceinstaller.exe" -i ".\com.lofturb.isend_1.0.0_iphoneos-arm.ipa"
```

También puedes copiar el `.ipa` al iPad y abrirlo con **Filza**.

### Compilar desde cero

El proyecto compila en GitHub Actions sin Mac (Theos + toolchain LLVM + SDK 9.3). Al hacer push a `main` se genera el `.ipa` y se publica como Release.

En local (Linux, WSL o CI) con Theos instalado:

```bash
export THEOS="$PWD/theos"
python3 tools/generar_recursos.py
cd app
make clean && make package FINALPACKAGE=1 PACKAGE_FORMAT=ipa
```

El resultado queda en `app/packages/`.

---

## Uso

1. Abre **ISend** en el iPad: el servidor arranca solo (si lo habías detenido, pulsa **Iniciar servidor**).
2. Aparece una dirección tipo `http://192.168.1.42:8080` y un QR.
3. En el PC, abre esa dirección en el navegador (o escanea el QR con el móvil).
4. Para enviar: arrastra archivos a la zona superior o pulsa **Elegir archivos** / **Fotos** / **Carpeta**.
5. Para recibir: usa el botón **↓** de cada archivo, o pulsa el nombre para abrirlo en el navegador.
6. Para organizar: **+** crea una carpeta; **✎** renombra; **×** borra.

> La app debe permanecer abierta mientras se transfiere. iOS 9 suspende la app (y cierra los sockets) al pasar a segundo plano.

---

## Seguridad

ISend está pensado para **redes de confianza** (tu casa, tu oficina). En esta versión:

- No hay contraseña ni cifrado: cualquiera en la misma Wi-Fi que conozca la IP puede entrar.
- Los permisos se pueden limitar desde la app: desactivar **subidas** o **borrados**.
- La carpeta publicada por defecto es el contenedor de la app; puedes cambiarla a `/var/mobile/Documents` o a `/`.
- No se envía nada a Internet.

Si vas a usarlo en una red compartida, añade una contraseña/PIN en una versión futura o limita el acceso con el cortafuegos del router.

---

## API

Todas las rutas devuelven JSON salvo las descargas y los recursos web.

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/` | Interfaz web |
| `GET` | `/api/info` | Dispositivo, versión, carpeta, espacio libre, contadores |
| `GET` | `/api/list?path=/` | Listado de una carpeta |
| `GET` | `/api/raw?path=/x` | Archivo en línea (previsualizar) |
| `GET` | `/api/download?path=/x` | Archivo como descarga |
| `PUT` | `/api/upload?path=/&name=x` | Cuerpo = bytes del archivo |
| `POST` | `/api/mkdir?path=/&name=x` | Crear carpeta (idempotente) |
| `POST` | `/api/rename?path=/x&name=y` | Renombrar |
| `POST` | `/api/delete?path=/x` | Borrar archivo o carpeta |
| `GET` | `/api/ping` | Comprobación rápida |

Ejemplo con `curl`:

```bash
curl -T foto.jpg "http://192.168.1.42:8080/api/upload?path=/&name=foto.jpg"
curl -OJ "http://192.168.1.42:8080/api/download?path=/foto.jpg"
```

---

## Estructura

```
ISend/
├── app/
│   ├── Makefile, control, entitlements.plist
│   ├── main.m / ISAppDelegate
│   ├── ISHTTPServer.{h,m}      # servidor y API
│   ├── ISService.{h,m}         # estado, puerto, carpeta, persistencia
│   ├── ISPaths.{h,m}           # rutas, MIME, IP local, utilidades
│   ├── ISTheme.{h,m}           # paleta y componentes
│   ├── ISQRCode.{h,m}          # QR con CoreImage
│   ├── ISHomeViewController    # pantalla "Compartir"
│   ├── ISFilesViewController   # explorador nativo + QuickLook
│   ├── ISSettingsViewController
│   └── Resources/
│       ├── Info.plist
│       ├── Icon-*.png / LaunchImage-*.png
│       └── web/                # index.html, style.css, app.js
├── tools/generar_recursos.py   # iconos e imágenes de arranque
└── .github/workflows/build-ipa.yml
```

---

## Limitaciones conocidas

- iOS 9 suspende la app en segundo plano: no hay transferencias en background.
- Sin autenticación ni TLS en esta versión.
- No hay descubrimiento automático entre dispositivos (se usa IP o QR).
- No se pueden descargar carpetas enteras como ZIP todavía.
- La interfaz web es en español.

## Ideas para la siguiente versión

- PIN de acceso y enlace con token.
- Descarga de carpetas en ZIP.
- Descubrimiento por Bonjour y nombre `ipad.local`.
- Envío directo entre dos iPads con ISend.
- Compresión opcional de fotos al vuelo.

---

## Licencia

MIT. Consulta `LICENSE`.

Hecho para revivir un iPad mini 1 con iOS 9 sin depender de la nube.
