# App CONPOCIIECH

Aplicación móvil institucional de CONPOCIIECH (Android e iOS). Integra servicios de la
organización; el módulo **Tribunal Electoral** es una extensión móvil del sistema TEC y
solo está disponible tras iniciar sesión con un rol autorizado.

| Dato | Valor |
| --- | --- |
| Paquete Android / bundle iOS | `ec.org.conpociiech.app` |
| Plataformas | Android, iOS |
| Flutter / Dart | 3.44 estable / 3.12 |
| Backend | TEC — `https://tribunal.conpociiech.org` |

## Arquitectura

```
lib/
  main.dart            Arranque: entorno (--dart-define) y App
  app.dart             Proveedores (entorno, sesión) y MaterialApp.router
  core/                Infraestructura sin pantallas
    api/               Cliente JSON de TEC y errores (ErrorApi, SinConexion)
    config/            Entorno: URL de la API, solo HTTPS
    router/            Rutas y guardas por sesión y rol (go_router)
    sesion/            Sesión con TEC (tokens, refresh, inactividad) y roles
  shared/              Reutilizable por cualquier módulo
    tema/              Colores y tipografía del tema Tribunal
    widgets/           Componentes comunes (logo institucional)
  features/            Un directorio por módulo, independientes entre sí
    inicio/            Área pública
    auth/              Inicio de sesión y cambio de clave
    tribunal/          Tribunal Electoral (área autenticada)
```

Flujo: `App Flutter → API REST de TEC (/api/v1, HTTPS) → servicios EJB de TEC → PostgreSQL`.
TEC es la fuente de verdad de usuarios, roles, iglesias, personas, padrón, procesos, JRV,
mesas, actas y escrutinio, y **autoriza cada petición**. La App solo presenta e interactúa:
ocultar una opción no es seguridad y no se duplican reglas electorales.

Nuevos módulos CONPOCIIECH: agregar `features/<modulo>/`, sus rutas en
`core/router/app_router.dart` y, si es protegido, su guarda.

## Identidad

- Colores y tipografía del **tema Tribunal** de TEC (`shared/tema/`), Montserrat 400/500/700
  (licencia OFL en `assets/fonts/OFL.txt`).
- **Logo provisional:** `assets/branding/logo_tec_provisional.png` (logo del TEC). Se
  reemplaza por el logo oficial de CONPOCIIECH al recibirlo; también quedan pendientes el
  icono y el splash definitivos.

## Ejecutar y probar

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=https://tribunal.conpociiech.org/api/v1
```

`API_BASE_URL` es opcional (ese es el valor por defecto) y **debe ser https**: la App no
arranca con una URL insegura. No se colocan secretos ni API keys en el código.

Para probar contra el entorno local (`https://tribunal.local/api/v1`) el dispositivo debe
resolver `tribunal.local` y confiar en su certificado; la App no desactiva la validación TLS.

## Firma de release (Android)

`android/key.properties` (con `storeFile`, `storePassword`, `keyAlias`, `keyPassword`) y el
keystore **no se versionan** (`.gitignore`). Sin `key.properties` el build de release falla
en lugar de firmarse con la llave de depuración.

## Seguridad

- Solo HTTPS (`usesCleartextTraffic="false"`; ATS por defecto en iOS).
- Sin copia de seguridad automática en Android (`allowBackup="false"`).
- La contraseña nunca se guarda. TEC emite tokens opacos (contrato en `docs/api-movil.md`
  del repositorio de TEC): el de acceso (5 min) vive solo en memoria; el refresh rotativo se
  guarda cifrado (Android Keystore / iOS Keychain, sin copia en otro dispositivo).
- 15 minutos sin interacción cierran la sesión (como la web); ante un 401 se renueva una
  vez y, si TEC la rechaza, se cierra con aviso. Las renovaciones nunca se solapan.
- Un usuario no permanente solo ve el cambio de clave hasta realizarlo.

## Fases

1. **Base Flutter** — estructura, tema, inicio público, formulario de inicio de sesión
   (sin conexión) y guardas por rol. *(completada)*
2. **Identidad** — logo oficial, icono y splash.
3. **API de autenticación en TEC** — tokens opacos con hash, refresh rotativo,
   revocación, cambio de clave obligatorio en la App. *(completada)*
4. **Sesión y roles en la App** — almacenamiento seguro, interceptor, 401/403, logout. *(completada)*
5. **Módulo Tribunal** — funcionalidades de solo lectura por rol (Presidente de mesa,
   IglesiaAdmin, Tribunal/Administrador). *(implementada; pendiente de validar con datos reales)*
6. **Acciones** — operaciones que modifican datos, tras validar la fase anterior.
7. **Pruebas y seguridad** — pruebas de autorización en backend, TLS, logs.
