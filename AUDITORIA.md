# Auditoría técnica — Kancha (FutbolStats)

Stack: Flutter + .NET Core 10 + SQL Server (sin EF migrations, scripts manuales)  
Fecha: 2026-07-30

---

## 1. Inconsistencias funcionales

**1.1 — Transiciones de estado de partido sin restricción**
`PATCH /api/Partidos/{id}/estado` no valida la FSM de estados. Se puede hacer `Finalizado → EnJuego`, o `Cancelado → Finalizado`. Un partido ya concluido puede "reabrirse" accidentalmente.
- Reproducción: Finalizar un partido → volver a parchear el estado a `EnJuego` → el backend acepta.
- Solución: Definir una matriz de transiciones permitidas y rechazar con 409 las no válidas.

**1.2 — La alineación puede modificarse en un partido Finalizado**
`PUT /api/Partidos/{id}/alineacion` (SetAlineacion) no valida el estado del partido. Se puede cambiar la alineación de un partido ya concluido, afectando retroactivamente las estadísticas del jugador (titularidades, ingresos, minutos).
- Reproducción: Finalizar un partido → llamar SetAlineacion → el backend acepta.
- Solución: Rechazar con 409 si `Estado != "Programado"`.

**1.3 — GuardarPenales puede llamarse sin que el partido esté en el estado correcto**
`POST /api/Partidos/{id}/penales` no verifica que el estado sea `EsperandoPenales`. Puede ejecutarse sobre partidos `Programado` o `EnJuego`.
- Solución: Validar `partido.Estado == "EsperandoPenales"` al inicio del endpoint.

**1.4 — Sin límite de sustituciones por partido**
`CambioValidator` valida que los jugadores sean correctos pero no el total de cambios realizados. Un partido puede tener 10, 20 o más cambios sin ningún rechazo.
- Solución: Contar eventos de tipo Cambio en el partido y rechazar si supera el límite configurado (3 ó 5).

**1.5 — Hard delete en Entrenamientos vs soft delete en Jugadores y Partidos**
`DeleteEntrenamiento` elimina físicamente. Los demás recursos usan `Activo = false`. Comportamiento inconsistente: borrar un entrenamiento con asistencias registradas las elimina en cascada sin posibilidad de recuperación.

**1.6 — Todos los usuarios registrados reciben el mismo rol**
En `login_screen.dart` el cuerpo del POST de registro envía `rolId: 1` hardcodeado. Si el rol 1 es `Admin` (como indica el seed), cualquier persona que conozca el endpoint puede auto-asignarse rol de administrador.
- Reproducción: Registrarse desde la app → el usuario obtiene `rolId: 1` siempre.

---

## 2. Funcionalidades incompletas

**2.1 — Módulo de Entrenamientos no implementado en el frontend (CRÍTICO)**
`lib/screens/training/training_screen.dart` contiene 3 líneas y el texto `'Entrenamientos'` con un comentario `// TODO Implement this library.`. El backend tiene endpoints completos, los modelos Flutter existen, pero la pantalla es un stub visible en la navegación principal.

**2.2 — Módulo de Observaciones no implementado**
`lib/screens/observations/observations_screen.dart` muestra `'Próximamente'`. Los endpoints del backend existen y funcionan, pero la pantalla no está implementada.

**2.3 — `TrainingSessionModel` desconectado de la API**
El modelo tiene campos (`avgRpe`, `type`) que no coinciden con la estructura real del backend (`Titulo`, `Tipo`, etc.). No hay `fromApi()`. Si se implementa el frontend de entrenamientos, este modelo debe rehacerse desde cero.

**2.4 — `ObservationModel` y `PlayerObservacionModel` coexisten para el mismo concepto**
Hay dos clases de dominio para observaciones en `models.dart`. Solo una (`PlayerObservacionModel`) tiene `fromApi()`. La otra (`ObservationModel`) es un placeholder que no se usa con datos reales.

**2.5 — `Observacion.Tipo` siempre es "General"**
El backend hardcodea `Tipo = "General"` en el endpoint POST. El campo tiene sentido semántico (podría ser "Técnica", "Táctica", "Física"), pero nunca se usa.

**2.6 — Sin refresh token**
El JWT expira (default 120 minutos). Al expirar, el próximo request falla con 401 y el usuario es desconectado. No hay mecanismo de refresco silencioso. En una sesión larga (partido de 90 minutos + edición post-partido), el token puede expirar durante el uso.

**2.7 — Campos de PlayerModel que nunca se calculan**
`PlayerModel.rating` y `PlayerModel.matchesPlayed` siempre son 0. Son campos heredados de un diseño anterior que nunca se calculan.

---

## 3. Casos borde

**3.1 — Eliminar (soft delete) un jugador que está en alineaciones de partidos futuros**
`DeleteJugador` desactiva el jugador pero no verifica si tiene partidos `Programado` o `EnJuego`. El jugador aparecerá en alineaciones activas aunque esté inactivo.

**3.2 — Eventos registrados en partidos Finalizados o Cancelados**
`POST /api/Partidos/{id}/eventos` no valida el estado del partido. Se pueden registrar goles, tarjetas o cambios en un partido ya finalizado.

**3.3 — DeleteEvento en partido Finalizado**
`DELETE /api/Partidos/{id}/eventos/{eventId}` no valida el estado del partido. Borrar un gol de un partido finalizado modifica retroactivamente el resultado y las estadísticas sin ninguna restricción.

**3.4 — Sincronización offline genera duplicados**
Cuando un evento se registra offline (ID negativo) y luego se sincroniza, el evento local y el del servidor coexisten en la caché. El usuario ve el evento duplicado hasta el próximo reload.

**3.5 — Cola de sync bloqueada permanentemente**
Si una acción en `sync_queue` falla por validación del servidor (ej: el cambio ya no es válido porque el plantel cambió), puede bloquear las acciones posteriores indefinidamente. No hay límite de reintentos.

**3.6 — `SetAsistencia` no es atómico**
El endpoint llama `Clear()` → `SaveChangesAsync()` → agrega nuevos ítems → `SaveChangesAsync()`. Si el segundo `SaveChanges` falla, la asistencia queda vacía. No hay transacción explícita con rollback.

**3.7 — Tarjeta roja a jugador ya sustituido**
`PlantelPartidoStateBuilder` no procesa la expulsión de un jugador que ya fue sustituido. El jugador no aparecerá en `expulsados`. El sistema lo ignora silenciosamente.

**3.8 — `GetPenales` con null-forgiving operator sobre dato potencialmente nulo**
`partido.ResultadoPenalesEquipo!.Value` lanza `NullReferenceException` si `HuboPenales = true` pero `ResultadoPenalesEquipo = null` (posible si los datos están corruptos o la operación de guardar falló a medias).

**3.9 — Jugador con número de camiseta 0**
`PlayerModel.toApiJson()` envía `null` cuando `number == 0`. Si el jugador tiene camiseta 0, se pierde silenciosamente.

**3.10 — Observaciones sobre jugadores inactivos**
`ObservacionesController` no filtra por `j.Activo`. Se pueden agregar y ver observaciones de jugadores dados de baja.

---

## 4. UX

**4.1 — Splash de 3 segundos fijos**
`AuthState.initialize()` espera 3 segundos independientemente de si la verificación de sesión tarda 200ms. Se siente lento sin razón.
- Mejora: Esperar el mínimo entre el tiempo de verificación y 1.5 segundos.

**4.2 — El módulo de Entrenamientos aparece en el menú principal pero es un stub**
El usuario ve "Entrenamientos" en la navegación, hace tap, y aparece solo el texto "Entrenamientos".
- Mejora inmediata: Ocultar la opción del menú o mostrar un EmptyState con mensaje claro.

**4.3 — Observaciones también aparece en el menú como "Próximamente"**
La navegación presenta una función que no existe.

**4.4 — Desconexión silenciosa al expirar el token**
Cuando el JWT expira, el usuario es redirigido al login sin mensaje explicativo. En medio de un partido en vivo esto es crítico.
- Mejora: Interceptar 401 con mensaje "Tu sesión expiró. Volvé a iniciar sesión."

**4.5 — Sin feedback de sincronización fallida**
Si la sync_queue tiene errores, el indicador de pendientes puede mostrar items que nunca se van a sincronizar. El usuario no sabe que debe tomar acción.

**4.6 — URL de API solo funciona en emulador Android**
`api_config.dart` tiene `10.0.2.2:5224` como default. En iOS simulator, dispositivo físico o producción, esta URL no funciona. No hay documentación de cómo cambiarla para la demo.

---

## 5. Modelo de datos

**5.1 — `Partido.UsuarioCreadorId` es un campo huérfano**
Existe en el modelo C# y en el SQL, pero en `OnModelCreating` no hay configuración de FK. EF no puede navegar a través de él. No se usa en ningún endpoint.

**5.2 — `Entrenamiento.Titulo` y `Tipo` son NOT NULL en SQL pero nullable en C#**
El script `01_create_tables.sql` define `Titulo NVARCHAR(100) NOT NULL` y `Tipo NVARCHAR(50) NOT NULL`. El modelo C# los declara como `string?`. Si se intenta insertar un entrenamiento sin Titulo, la BD rechazará en `SaveChanges`.

**5.3 — `06_entrenamientos.sql` es incompatible con `01_create_tables.sql`**
El script 06 redefine `Entrenamientos` con una estructura diferente (`Descripcion` en lugar de `Titulo/Tipo/Lugar`) y crea `AsistenciaEntrenamiento` (sin 's') que ya existe como `AsistenciasEntrenamiento` en el 01. Si alguien clona el proyecto y ejecuta todos los scripts en orden, obtendrá un error de "tabla ya existe" o una BD en estado inválido.
- Solución: Reescribir el 06 como script idempotente con IF NOT EXISTS, o eliminarlo si todo ya está en el 01.

**5.4 — `AsistenciaEntrenamiento.Rpe` existe pero no se expone en ningún endpoint**
El campo `Rpe (double?)` está en el modelo C# y en la BD, pero `EntrenamientosController` no lo recibe ni devuelve.

**5.5 — `Observacion.Fecha` es `DateTime` pero se asigna solo la fecha**
El controller asigna `DateTime.UtcNow.Date`. El tipo correcto sería `DateOnly`.

**5.6 — `PlayerModel.id` es `String` en Flutter siendo `int` en el backend**
Toda la capa Flutter convierte `jugadorId` (int) a String y back. Genera casteos en múltiples lugares.

---

## 6. Backend

**6.1 — `Console.WriteLine` de debug en `EventosPartidoController` (línea 42)**
Código de debug en producción. Debería usar `ILogger` o eliminarse.

**6.2 — Sin global exception handler**
Excepciones no controladas devuelven stack traces cuando `ASPNETCORE_ENVIRONMENT=Development`. En una demo hecha en ese entorno, cualquier error 500 expone la estructura interna del backend.

**6.3 — Sin rate limiting en el endpoint de login**
`POST /api/Auth/login` no tiene ningún mecanismo de throttling. Permite intentos de contraseña ilimitados.

**6.4 — Strings de tipo evento hardcodeados en 4 lugares distintos**
`"Gol"`, `"Asistencia"`, `"Cambio"`, `"Tarjeta roja"` aparecen como literales en JugadoresController, EventosPartidoController, EstadisticasGlobalesService y PlantelPartidoStateBuilder. Si se renombra un tipo de evento en la BD, se rompen en silencio.
- PlantelPartidoStateBuilder ya tiene constantes `NombreCambio` y `NombreTarjetaRoja` — usar ese mismo patrón en todos los demás.

**6.5 — O(n) queries por evento registrado**
`EventosPartidoController.CreateEvento` reconstruye el estado del plantel (2 queries adicionales a BD) en cada evento registrado. En un partido con 30 eventos, son 60 queries extra. Sin caché.

**6.6 — Modelo de Gemini incorrecto**
`GeminiOptions.Model` default es `"gemini-3.5-flash"` — este modelo no existe en la API de Google. El modelo correcto sería `"gemini-1.5-flash"` o `"gemini-2.0-flash"`. La integración IA fallará por defecto.

**6.7 — `BusinessRules.NormalizeRequiredText` puede causar un 500**
Si se llama con string vacío, lanza `ArgumentException`. Si algún controller no valida primero, resulta en un 500 en lugar de 400.

---

## 7. Frontend

**7.1 — `MatchTime.secondsPerMatchMinute = 1` en producción (CRÍTICO)**
El archivo `lib/core/utils/match_time.dart` tiene este valor hardcodeado. Un partido de 90 minutos dura 90 segundos en la UI. Si se presenta en la defensa de tesis con este valor, el reloj del partido irá a 90' en un minuto y medio. No hay configuración externa ni comentario que indique que debe cambiarse a 60.

**7.2 — Token JWT almacenado sin cifrado en SQLite**
La sesión (incluyendo el token) se guarda en SQLite en texto plano. Debería usarse `flutter_secure_storage` para producción.

**7.3 — `AuthState._database()` crea tabla fuera del flujo de `DatabaseHelper`**
La tabla `auth_session` se crea directamente en `AuthState` en lugar de en `DatabaseHelper._createDB`. Si en el futuro se agrega una versión al schema de SQLite, esta tabla puede quedar desincronizada.

**7.4 — Tablas `matches` y `match_events` son dead code en SQLite**
`DatabaseHelper._createLegacyTables()` crea estas tablas que ya no se usan (todo va por `local_cache`). Ocupan espacio y confunden.

**7.5 — `deletePendingEventByLocalId` usa LIKE sobre JSON serializado**
La búsqueda `LIKE '%"localEventoId":X%'` es frágil: si el JSON cambia de formato, no encontrará el registro.

**7.6 — `MaterialApp.router` con `key: ValueKey(themeController.isDarkMode)`**
Cambiar el tema recrea todo el árbol de widgets, perdiendo el estado de las pantallas abiertas.

**7.7 — `AppColors._darkMode` como `static bool` mutable**
Es un antipatrón. Cualquier widget que use `AppColors.accent` fuera del ciclo de rebuild puede leer el valor stale. El sistema de theming de Flutter (`Theme.of(context)`) es el camino correcto.

**7.8 — Sin manejo de expiración de token en el cliente**
Cada API llama su propio `_friendlyError` que devuelve el mensaje, pero no hay interceptor global que limpie la sesión y redirija al login.

---

## 8. Calidad general

| Item                                                               | Impacto |
|--------------------------------------------------------------------|---------|
| `Console.WriteLine` debug en EventosController                     | Medio   |
| `secondsPerMatchMinute = 1` sin documentar                         | Alto    |
| `06_entrenamientos.sql` incompatible con `01_create_tables.sql`    | Alto    |
| `TrainingSessionModel`/`ObservationModel` sin `fromApi`            | Medio   |
| `PlayerModel.rating` / `matchesPlayed` siempre 0                   | Bajo    |
| Tablas `matches` y `match_events` en SQLite sin uso                | Bajo    |
| `Sub` y `NameIdentifier` con el mismo valor en JWT                 | Bajo    |
| `AddOpenApi()` y `AddSwaggerGen()` coexistiendo                    | Bajo    |
| Strings de tipo evento duplicados en 4 servicios                   | Medio   |
| Sin tests de controllers ni de integración                         | Alto    |
| `MatchRosterState` Flutter duplica lógica del backend sin tests    | Medio   |

---

## 9. Funcionalidades faltantes

| Funcionalidad                              | Clasificación | Justificación |
|--------------------------------------------|--------------|---------------|
| Pantalla de gestión de entrenamientos      | CRÍTICA      | El backend existe, el menú existe, la pantalla no. Sin esto, el módulo de "Carga física" nunca tendrá datos reales de entrenamientos. |
| Pantalla de observaciones técnicas         | IMPORTANTE   | El backend existe, el menú presenta la opción, la pantalla dice "Próximamente". Para una app de gestión deportiva, las observaciones técnicas son una feature central. |
| Límite de sustituciones configurable       | IMPORTANTE   | El fútbol tiene una regla fundamental de máximo 3 ó 5 cambios. Sin este límite el sistema permite casos imposibles que cualquier evaluador notará. |
| Gestión de usuarios desde la UI            | IMPORTANTE   | No hay forma de crear usuarios con rol específico desde la app. Todos los registros son el mismo rol. Para un equipo real necesitas asignar Entrenador, Analista, etc. |
| Estadísticas por categoría                 | DESEABLE     | Si se agregan múltiples categorías, el dashboard mezcla todas. Genera datos confusos. |
| Manejo de expiración de sesión en vivo     | IMPORTANTE   | Si el token expira durante un partido, el sistema falla silenciosamente. |

---

## 10. Prioridad

### DEBE corregirse antes de la entrega de tesis

1. `secondsPerMatchMinute = 1` — el reloj va a 90' en 90 segundos → `match_time.dart`
2. Módulo Entrenamientos visible en menú pero es stub → `training_screen.dart`
3. Módulo Observaciones visible en menú como "Próximamente" → `observations_screen.dart`
4. `Console.WriteLine` debug en código de producción → `EventosPartidoController.cs` línea 42
5. `rolId: 1` hardcodeado — todos los usuarios son el mismo rol → `login_screen.dart`
6. Modelo Gemini `"gemini-3.5-flash"` no existe — IA siempre falla → `GeminiOptions.cs`
7. `06_entrenamientos.sql` incompatible con `01_create_tables.sql` → `database/`
8. Sin límite de sustituciones por partido → `CambioValidator.cs`
9. Transiciones de estado de partido sin validar (Finalizado → EnJuego) → `PartidosController.cs`

### CONVIENE corregirlo

10. `SetAlineacion` sin validar estado del partido
11. `GuardarPenales` sin validar estado del partido
12. `DeleteEvento` sin validar estado del partido
13. Eventos registrables en partidos Finalizados
14. `SetAsistencia` no es atómico (Clear + Save + Add + Save)
15. Strings de tipo evento duplicados en 4 archivos — extraer a constantes
16. `Partido.UsuarioCreadorId` sin FK en DbContext
17. `Entrenamiento.Titulo/Tipo` NOT NULL en BD pero nullable en C#
18. Token JWT sin manejo de expiración en el cliente (redirect al login con mensaje)
19. Soft delete de jugador sin verificar partidos activos
20. Observaciones sobre jugadores inactivos permitidas

### Puede dejarse para versiones futuras

21. Token JWT sin cifrado en SQLite (usar flutter_secure_storage)
22. Sin rate limiting en login
23. Sin refresh token
24. Tablas legacy `matches`/`match_events` en SQLite (dead code)
25. `deletePendingEventByLocalId` usa LIKE sobre JSON
26. `AppColors._darkMode` como static mutable — adoptar Theme.of(context)
27. `MaterialApp.router` con key que recrea el árbol al cambiar tema
28. URL de API hardcodeada para emulador Android — documentar cómo cambiarla
29. Sin caché con expiración en SQLite
30. Estadísticas globales sin filtro por categoría

---

## Resumen ejecutivo

El proyecto tiene una base técnica sólida: validadores puros bien testeados, caché offline bien pensada, arquitectura de separación de responsabilidades correcta.

Los problemas críticos para la tesis son principalmente de presentación y coherencia:
- El reloj acelerado (secondsPerMatchMinute = 1)
- Los módulos incompletos visibles en el menú
- El modelo de Gemini incorrecto

Son los que un evaluador notará de inmediato sin necesidad de revisar el código.

Los problemas de negocio (límite de cambios, transiciones de estado) son los que un evaluador técnico preguntará durante la defensa.
