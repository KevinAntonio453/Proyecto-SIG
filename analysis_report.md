# 🔍 Análisis Completo — SafeSteps (Backend + Móvil)

Se analizaron **todos los archivos** del proyecto. Este reporte está organizado por severidad y prioridades pendientes.

---

## 🔴 CRÍTICO — La app se rompe o tiene riesgo de seguridad grave

### 1. ✅ [RESUELTO] No hay tracking en segundo plano (Móvil)
*   **Solución**: Se implementó un servicio de primer plano (`BackgroundService`) persistente en Android mediante `flutter_background_service`. Corre en un isolate separado y es inmune al cierre forzado de la ventana de la app.

---

### 2. ✅ [RESUELTO] No hay notificaciones push (Móvil + Backend)
*   **Solución**: Se integraron `firebase_core` y `firebase_messaging` en la app móvil. Se enlazó `google-services.json` de tu proyecto `proy-sig` y se configuró `FcmService` para suscribirse, solicitar permisos nativos (Android 13+) y registrar el token en el servidor tras iniciar sesión.

---

### 3. ✅ [RESUELTO] Controller de Registros sin autenticación (Backend)
*   **Solución**: Se aplicó la guardia de autenticación `@UseGuards(JwtAuthGuard)` a nivel global en la clase `RegistrosController`. Todos los endpoints de historial de trayectorias están protegidos con JWT.

---

### 4. No hay autorización, solo autenticación (Backend)
La mayoría de endpoints verifican que el usuario está logueado, pero **NO** verifican que tenga relación o permiso sobre la entidad consultada:

| Endpoint | Riesgo |
|----------|--------|
| `GET /tutores/:id/hijos` | Cualquier usuario ve los hijos de CUALQUIER tutor |
| `GET /hijos/:id` | Cualquier usuario ve datos de CUALQUIER niño |
| `PATCH /hijos/:id` | Cualquier usuario modifica CUALQUIER niño |
| `DELETE /tutores/:id` | Cualquier usuario elimina CUALQUIER tutor |
| WebSocket `joinChildRoom` | Cualquier usuario espía la ubicación de CUALQUIER niño |

> [!CAUTION]
> **Prioridad Alta**. En una app de seguridad infantil, esto es inaceptable. Un tutor autenticado no debe poder consultar ubicaciones de niños vinculados a otros tutores.

---

### 5. Credenciales en el repositorio (Backend)
- `FireBase Key.json` con la clave privada completa de Firebase — **NO está en .gitignore** (el patrón cubre `*-key.json` pero el archivo tiene un espacio)
- JWT secret en `.env`: `tu-clave-secreta-muy-segura-cambiala-en-produccion` — es el valor REAL en producción
- Fallback del JWT secret: `'your-secret-key'` — si falta la variable de entorno, cualquiera puede forjar tokens
- `synchronize: true` en producción — TypeORM puede alterar o destruir tablas automáticamente

---

### 6. No hay refresh de token JWT (Móvil)
Si el token expira (24h), todas las llamadas API fallan silenciosamente con 401. No hay interceptor, no hay redirección al login, no hay refresh token.

---

## 🟠 MAYOR — Gaps significativos de funcionalidad o calidad

### 7. Duplicación masiva de código (Móvil)
[home_screen.dart](file:///C:/Users/Antonio/Desktop/Proy%20SIG/Movil/lib/features/tutor/home_screen.dart) (662 líneas) y [map_screen.dart](file:///C:/Users/Antonio/Desktop/Proy%20SIG/Movil/lib/features/tutor/map_screen.dart) (572 líneas) son **~90% código idéntico**: misma lógica de WebSocket, mismos listeners, mismo renderizado de mapa, mismo bottom sheet. Uno parece ser la versión anterior del otro.

---

### 8. Riverpod declarado pero nunca usado (Móvil)
`flutter_riverpod` está en `pubspec.yaml` pero **cero providers existen**. Toda la app usa `setState()` directo. Los servicios se instancian manualmente en cada widget: `final _authService = AuthService()`. No hay inyección de dependencias, no hay testing posible.

---

### 9. SOS del WebSocket no se persiste ni envía push (Backend)
El handler `panicAlert` en el gateway solo hace broadcast por WebSocket. Hay un **TODO literal** en el código:
```typescript
// TODO: Guardar alerta en base de datos y/o enviar notificación push
```
Si el tutor no tiene la app abierta cuando el niño presiona SOS, **no se entera**.

> [!WARNING]
> El SOS por HTTP (endpoint `/hijos/:id/sos`) SÍ persiste y envía push. Pero si el WebSocket falla primero, el flujo puede ser inconsistente.

---

### 10. ✅ [RESUELTO] No hay reconexión de WebSocket (Móvil)
*   **Solución**: Se implementó una política de auto-reconexión robusta de WebSocket en `SocketService` con reintentos exponenciales (2s a 30s) y se creó un búfer de canales monitoreados (`_monitoredChildIds`) que re-inscribe al tutor automáticamente al restablecerse la conexión. El hijo también auto-ejecuta `marcarOnline()` al reconectar.

---

### 11. Contraseñas expuestas en respuestas API (Backend)
`findAll()`, `findOne()`, `update()` en `HijoService` y `TutorService` devuelven la entidad completa **incluyendo el hash del password**. Solo `getHijos()` y `registerHijoForAuthenticatedTutor()` limpian el campo.

---

### 12. Cero tests (Backend + Móvil)
- Backend: Jest configurado, cero archivos de test
- Móvil: Solo el `widget_test.dart` por defecto de Flutter (plantilla vacía)

---

## 🟡 MODERADO — UX, rendimiento y calidad de código

### 13. Token almacenado sin encriptar (Móvil)
El JWT se guarda en `SharedPreferences` (texto plano). En un dispositivo rooteado se puede extraer. Debería usar `flutter_secure_storage`.

---

### 14. ✅ [RESUELTO] Batería hardcodeada a 100% (Móvil)
*   **Solución**: Integramos el paquete `battery_plus` en el servicio en segundo plano del hijo. El nivel de carga física real del dispositivo móvil ahora se envía dinámicamente a través del canal WebSocket.

---

### 15. [PARCIALMENTE RESUELTO] Sin limpieza automática de datos (Backend)
- `cleanOldNotifications()` existe pero **nunca se llama** — no hay cron/scheduler (Backend)
- `registros` crece sin límite — no hay purgado (Backend)
- ✅ **[RESUELTO en Móvil]** `sincronizarOffline()`: Si el celular del niño no tiene señal, las ubicaciones se guardan localmente en un búfer en `SharedPreferences` (`fueOffline = true`). Al reconectarse a internet, se sincronizan automáticamente en bloque usando el endpoint `/sync` y el búfer se limpia.

---

### 16. Historial de rutas hardcodeado a 12 horas (Móvil)
No hay selector de fecha. El tutor no puede ver rutas de días anteriores.

---

### 17. Sin rate limiting (Backend)
No hay throttling en ningún endpoint. Los endpoints sin auth (`verificar-codigo`, `vincular`) son especialmente vulnerables a fuerza bruta. El código de vinculación de 6 caracteres tiene ~887M combinaciones, que sin rate limit se pueden barrer.

---

### 18. ✅ [RESUELTO] Precisión de coordenadas con `float` (Backend)
*   **Solución**: Se modificaron las columnas de coordenadas a `'double precision'` (64-bit IEEE 754) en las entidades `Hijo` y `Registro`. PostgreSQL ahora almacena ubicaciones con precisión milimétrica de 15 decimales.

---

### 19. Inconsistencia en expiración JWT (Backend)
- Auth module: `expiresIn: '24h'`
- Ubicación module: `expiresIn: '7d'`
- Son dos `JwtModule.registerAsync()` separados con valores distintos

---

### 20. APIs deprecated en uso (Móvil)
- `WillPopScope` (deprecated desde Flutter 3.12) → usar `PopScope`
- `Color.withOpacity()` usado ~30 veces → usar `Color.withValues(alpha: x)`
- `print()` con emojis por toda la app → filtrar en release, usar `dart:developer`

---

## 🟢 MENOR — Pulido y mejoras opcionales

| # | Área | Detalle | Estado |
|---|------|---------|--------|
| 21 | Backend | `getHello()` retorna `'aaaa!'` — leftover de debug | Pendiente |
| 22 | Backend | `generateVinculacionCode()` duplicado en `TutorService` y `HijoService` | Pendiente |
| 23 | Backend | Sin Swagger/OpenAPI — no hay documentación de API | Pendiente |
| 24 | Backend | Sin health check real — `/health` no verifica DB ni Firebase | Pendiente |
| 25 | Backend | Sin versionado de API (`/api/v1/`) | Pendiente |
| 26 | Móvil | Sin dark mode (solo `lightTheme`) | Pendiente |
| 27 | Móvil | Sin splash screen ni animación de carga inicial | Pendiente |
| 28 | Móvil | Sin onboarding para usuarios nuevos | Pendiente |
| 29 | Móvil | Notificaciones muestran "Hoy a las HH:MM" para todas, incluso las viejas | Pendiente |
| 30 | Móvil | Sin pull-to-refresh en la pantalla del mapa | Pendiente |
| 31 | Móvil | "Tutor Autenticado" como nombre de perfil — no muestra nombre real | Pendiente |
| 32 | Móvil | Sin feedback háptico ni sonido en SOS | Pendiente |
| 33 | Móvil | Import de `SocketService` sin usar en `dashboard_screen.dart` | Pendiente |

---

## ✅ LO QUE FUNCIONA BIEN

| Área | Detalle |
|------|---------|
| 🗺️ Geofencing | PostGIS con `ST_Contains` — geofencing real con polígonos, no círculos |
| 🔄 Máquina de estados | Transiciones FUERA→DENTRO / DENTRO→FUERA bien diseñadas |
| 🔗 Vinculación | Sistema de códigos elegante para vincular dispositivos del niño |
| 🔔 Notificaciones in-app | CRUD completo con paginación, filtros, acciones bulk |
| 🎨 Diseño visual | Paleta profesional, Material 3, Google Fonts, SOS con progress ring |
| 📡 WebSocket | Autenticación JWT, rooms por hijo, dual-channel (WS + HTTP) |
| ✅ Validación | DTOs bien validados con class-validator |
| 🐳 Docker | docker-compose con PostGIS y health checks |
| 📶 Offline sync | Estructura para batch sync existe e integrada en la re-conexión móvil |

---

## 📊 Resumen por Prioridad

| Severidad | Total Inicial | Resueltos | Pendientes |
|-----------|---------------|-----------|------------|
| 🔴 Crítico | 6 | 3 | 3 |
| 🟠 Mayor | 6 | 1 | 5 |
| 🟡 Moderado | 8 | 2 | 6 |
| 🟢 Menor | 13 | 0 | 13 |
| **Total** | **33** | **6** | **27** |
