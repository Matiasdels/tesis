# Kancha — Contexto completo del proyecto

> Documento generado el 03/07/2026 para onboarding de IA.
> Basado en análisis del código fuente real del repositorio.

---

## 1. Descripción general del sistema

**Kancha** es una aplicación móvil y de escritorio para la gestión deportiva del fútbol amateur. Permite a entrenadores y cuerpo técnico:

- Administrar jugadores (alta, edición, estados, categorías)
- Planificar y registrar partidos
- Cargar alineaciones visualmente con formaciones tácticas
- Registrar eventos en tiempo real durante el partido (goles, pases, faltas, etc.)
- Consultar estadísticas y exportar reportes en PDF

**Contexto:** Es la tesis de grado de la carrera de Analista Programador, desarrollada para el club **Colón FC (Uruguay)**. Resuelve la necesidad de contar con una herramienta propia para el seguimiento técnico sin depender de planillas manuales.

**Público objetivo:** Entrenadores, asistentes técnicos y analistas de clubes de fútbol amateur y semiprofesional.

---

## 2. Tecnologías utilizadas

| Capa | Tecnología |
|---|---|
| Frontend | Flutter (SDK ≥ 3.0) · Dart |
| Backend | .NET 10 · ASP.NET Core Web API |
| ORM | Entity Framework Core (SQL Server provider) |
| Base de datos | SQL Server Express — instancia `FutbolStatsDb` |
| Autenticación | JWT Bearer (HMAC-SHA256) · PBKDF2-SHA256 para passwords |
| PDF | `pdf ^3.11` + `printing ^5.13` |
| Navegación | `go_router ^13.2.0` |
| Estado global | `provider ^6.1.2` |
| HTTP | `http ^1.2.2` |
| SQLite local | `sqflite ^2.4.2` (caché + sync queue offline) |
| Gráficos | `fl_chart ^0.67.0` |
| Tipografía | `google_fonts ^6.2.1` (Inter + JetBrains Mono) |

### Arquitectura de comunicación

Flutter **no se conecta directamente a SQL Server**. Todo pasa por el backend REST:

```
Flutter (mobile/desktop)
  └─► HTTP/REST ──► ASP.NET Core Web API (puerto 5224)
                        └─► Entity Framework Core
                              └─► SQL Server Express (FutbolStatsDb)
```

La URL base se define en `lib/data/remote/api_config.dart` como variable de entorno `API_BASE_URL`. El valor por defecto es `http://10.0.2.2:5224` (host del emulador Android). En dispositivos físicos hay que cambiar la IP.

### Módulos implementados vs. pendientes

| Módulo | Estado | Notas |
|---|---|---|
| Login / registro | ✅ Completo | JWT, sesión persistida en SQLite |
| Gestión de jugadores | ✅ Completo | Alta, edición, soft delete, filtros |
| Gestión de partidos | ✅ Completo | CRUD, estados, orden, filtro por año |
| Carga de alineación | ✅ Completo | Visual con cancha, formaciones, suplentes |
| Partido en vivo | ✅ Completo | Menú radial, eventos, cronómetro |
| Resumen post-partido | ⚠️ Básico | Existe, mejoras de métricas pendientes |
| PDF / Reportes | ⚠️ Básico | Funcional pero sin métricas avanzadas |
| Estadísticas globales | ❌ Stub | Pantalla vacía, pendiente |
| Entrenamientos | ❌ Stub | Tabla SQL existe, sin API ni UI real |
| Observaciones | ❌ Stub | Tabla SQL existe, sin API ni UI real |

---

## 3. Estructura del proyecto

```
futbolTesis/
├── backend/
│   ├── FutbolStats.api/
│   │   ├── Controllers/         ← Endpoints REST
│   │   │   ├── AuthController.cs
│   │   │   ├── JugadoresController.cs
│   │   │   ├── PartidosController.cs
│   │   │   ├── EventosPartidoController.cs
│   │   │   ├── CatalogosController.cs
│   │   │   └── HealthController.cs
│   │   ├── Data/
│   │   │   └── FutbolStatsDbContext.cs   ← EF Core DbContext
│   │   ├── Models/              ← Entidades EF
│   │   │   ├── Jugador.cs
│   │   │   ├── Partido.cs
│   │   │   ├── Alineacion.cs
│   │   │   ├── EventoPartido.cs
│   │   │   ├── Usuario.cs
│   │   │   ├── Rol.cs
│   │   │   ├── Categoria.cs
│   │   │   └── TipoEvento.cs
│   │   ├── Services/
│   │   │   ├── PasswordHasher.cs   ← PBKDF2-SHA256
│   │   │   ├── TokenService.cs     ← Generación de JWT
│   │   │   └── BusinessRules.cs    ← Normalización de texto
│   │   ├── Options/
│   │   │   └── JwtOptions.cs
│   │   ├── Program.cs           ← Entry point, DI, middlewares
│   │   └── appsettings.json     ← Connection string, JWT config
│   └── database/
│       ├── 01_create_tables.sql     ← Esquema completo (11 tablas)
│       └── 02_seed_data.sql         ← Datos iniciales
└── frontend/
    └── estadisticas_futbol/
        ├── lib/
        │   ├── core/
        │   │   ├── constants/app_constants.dart  ← Rutas, EventTypes, posiciones, estados
        │   │   ├── router/app_router.dart         ← GoRouter con redirect de auth
        │   │   └── theme/
        │   │       ├── app_colors.dart            ← Paleta centralizada (NO hardcodear colores)
        │   │       ├── app_theme.dart             ← ThemeData dark
        │   │       └── app_typography.dart        ← Escalas tipográficas
        │   ├── data/
        │   │   ├── local/
        │   │   │   ├── database_helper.dart       ← SQLite: caché JSON + sync queue
        │   │   │   └── sync_service.dart          ← Reenvío de acciones pendientes offline
        │   │   └── remote/
        │   │       ├── api_config.dart            ← URL base del backend
        │   │       ├── auth_api.dart
        │   │       ├── auth_state.dart            ← ChangeNotifier, sesión global
        │   │       ├── event_api.dart             ← Eventos (offline-first)
        │   │       ├── match_api.dart             ← Partidos + alineaciones
        │   │       └── player_api.dart            ← Jugadores + categorías
        │   ├── models/models.dart                 ← Todos los modelos de dominio Flutter
        │   ├── screens/
        │   │   ├── auth/           ← LoginScreen, SplashScreen
        │   │   ├── dashboard/      ← DashboardScreen
        │   │   ├── live_match/     ← LiveMatchScreen (partido en vivo)
        │   │   ├── matches/        ← MatchesScreen, MatchDetailScreen,
        │   │   │                      MatchFormScreen, MatchSummaryScreen,
        │   │   │                      LineupScreen
        │   │   ├── players/        ← PlayersScreen, PlayerDetailScreen, PlayerFormScreen
        │   │   ├── reports/        ← ReportsScreen, MatchReportPdfExporter
        │   │   ├── statistics/     ← StatisticsScreen (stub)
        │   │   ├── training/       ← TrainingScreen (stub)
        │   │   └── observations/   ← ObservationsScreen (stub)
        │   └── widgets/common/
        │       ├── app_widgets.dart   ← Componentes compartidos (cards, badges, avatars, etc.)
        │       └── main_shell.dart    ← Shell de navegación (sidebar + bottom nav)
        └── pubspec.yaml
```

---

## 4. Base de datos

Los scripts están en `backend/database/`. Ejecutar en orden: primero `01_create_tables.sql`, luego `02_seed_data.sql`.

### Tablas con entidad EF Core

| Tabla | PK | Campos clave |
|---|---|---|
| `Roles` | `RolId` | `Nombre` |
| `Usuarios` | `UsuarioId` | `NombreUsuario`, `Email`, `PasswordHash`, `RolId`, `Activo` |
| `Categorias` | `CategoriaId` | `Nombre`, `Descripcion` |
| `Jugadores` | `JugadorId` | `Nombre`, `Apellido`, `PosicionPrincipal`, `Estado`, `CategoriaId`, `Activo` |
| `Partidos` | `PartidoId` | `CategoriaId`, `Rival`, `Estado`, `GolesEquipo`, `GolesRival`, `MinutoActual`, `Formacion`, `Activo` |
| `Alineaciones` | `AlineacionId` | `PartidoId`, `JugadorId`, `EsTitular`, `PosicionAsignada` |
| `TiposEvento` | `TipoEventoId` | `Nombre` |
| `EventosPartido` | `EventoId` | `PartidoId`, `JugadorId`?, `TipoEventoId`, `Minuto`, `PitchX`, `PitchY`, `JugadorRelacionadoId`? |

### Restricciones importantes del modelo EF

- `Jugadores.Dni`: índice único filtrado (`IS NOT NULL`)
- `Alineaciones`: índice único en `(PartidoId, JugadorId)`. FK a `Partidos` con cascade delete.
- `Usuario.FechaCreacion`: default `SYSDATETIME()`
- `Jugador.Estado`: default `"Disponible"`
- `Partido.TipoCompeticion`: default `"Amistoso"`

### Tablas SQL sin entidad EF (futuras)

Existen en el script SQL pero **sin modelos EF ni controladores**:
- `Entrenamientos`
- `AsistenciasEntrenamiento`
- `Observaciones`

### Columna Formacion en Partidos

Se agregó recientemente. Si la base no la tiene ejecutar:
```sql
ALTER TABLE Partidos ADD Formacion NVARCHAR(10) NULL;
```

### Tipo de evento "Gol rival" — INSERT manual requerido

El seed `02_seed_data.sql` **no incluye** este tipo de evento. Ejecutar una vez:
```sql
INSERT INTO TiposEvento (Nombre) VALUES ('Gol rival');
```

### Decisiones sobre validaciones

- **La base de datos** garantiza: PK, FK, integridad referencial, NOT NULL básicos, índices únicos.
- **El backend** valida reglas de negocio: formato de nombre, rango de edad, camiseta 1–99, estado válido, jugador pertenece a categoría del partido, sin duplicados en alineación, etc.
- **El frontend** valida para dar feedback inmediato al usuario. La validación definitiva es siempre del backend.

### Seed data incluido en 02_seed_data.sql

- 1 Categoría: `Primera` (plantel principal)
- 5 Roles: `Admin`, `Entrenador`, `Asistente`, `Analista`, `Preparador físico`
- 17 TiposEvento: Pase correcto, Pase incorrecto, Remate, Gol, Recuperación, Falta, Intercepción, Centro, Asistencia, Tarjeta amarilla, Tarjeta roja, Atajada, Corner, Offside, Pérdida, Entrada exitosa, Entrada fallida

---

## 5. Gestión de usuarios y permisos

### Flujo de autenticación

1. Usuario ingresa credenciales en `LoginScreen`
2. `AuthState.login()` llama a `POST /api/Auth/login`
3. El backend valida con PBKDF2-SHA256 y devuelve JWT (HMAC-SHA256, 120 minutos)
4. El frontend persiste la `AuthSession` completa como JSON en SQLite (tabla `auth_session`, fila única con `id=1`)
5. Al arrancar la app, `AuthState.initialize()` lee la sesión, verifica expiración y llama `GET /api/Auth/me` para confirmar validez
6. Si el token venció o no hay sesión → redirige a `/login`

### Roles disponibles (seeded)

- Admin, Entrenador, Asistente, Analista, Preparador físico

### Estado actual de permisos

- El registro en `LoginScreen` **hardcodea `rolId = 1` (Admin)**. Todos los usuarios creados son Admin. Intencional para la beta.
- Todos los endpoints solo requieren `[Authorize]` (token válido). No hay control de acceso por rol todavía.
- El claim `Role` está en el JWT para futura implementación de permisos por rol.

### JWT

- Algoritmo: HMAC-SHA256
- Claims: Sub, NameIdentifier, Email, Name (username), GivenName, Surname, Role
- Expiración: 120 minutos
- **⚠️ El SecretKey en `appsettings.json` es un placeholder.** Cambiar antes de producción.

---

## 6. Gestión de jugadores

### Funcionalidades implementadas

- **Listado** (`PlayersScreen`): búsqueda por texto, filtro por estado, filtro por grupo de posición, caché offline
- **Alta** (`PlayerFormScreen`): formulario completo con validación cliente y servidor
- **Edición**: misma pantalla con datos precargados
- **Detalle** (`PlayerDetailScreen`): tab "Datos" completo. Tabs "Carga física", "Partidos", "Observaciones" — pendientes
- **Baja**: soft delete — campo `Activo = false`. El jugador desaparece de listados pero sus estadísticas se preservan

### Estados de jugador

| Valor backend (string) | Valor UI (frontend) | Badge |
|---|---|---|
| `Disponible` | `available` | Verde |
| `Lesionado` | `injured` | Rojo |
| `Suspendido` | `suspended` | Amarillo |

La conversión se hace en `PlayerModel.statusFromApi()` y `statusToApi()`. **No cambiar estos strings** — están sincronizados entre backend, frontend y base de datos.

### Posiciones disponibles

| Código | Nombre completo | Grupo |
|---|---|---|
| `ARQ` | Arquero | Arquero |
| `LD` | Lateral Derecho | Defensas |
| `DFC` | Defensa Central | Defensas |
| `LI` | Lateral Izquierdo | Defensas |
| `MD` | Mediocampista Derecho | Mediocampistas |
| `MCD` | Mediocentro Defensivo | Mediocampistas |
| `MC` | Mediocampista Central | Mediocampistas |
| `MCO` | Mediocampista Ofensivo | Mediocampistas |
| `MI` | Mediocampista Izquierdo | Mediocampistas |
| `ED` | Extremo Derecho | Delanteros |
| `EI` | Extremo Izquierdo | Delanteros |
| `DC` | Delantero Centro | Delanteros |
| `DEL` | Delantero | Delanteros |

> **Importante:** Los códigos de posición se usan en filtros de jugadores, slots de alineación y preferencia en el picker. **No renombrar ni agregar posiciones sin revisar todos los usos.**

### Filtros de la pantalla de jugadores

- **Estado:** Todas / Disponible / Lesionado / Suspendido
- **Posición:** Todas / Arquero / Defensas / Mediocampistas / Delanteros

Agrupaciones:
- Arquero: `ARQ`
- Defensas: `LD`, `DFC`, `LI`
- Mediocampistas: `MD`, `MCD`, `MC`, `MCO`, `MI`
- Delanteros: `ED`, `EI`, `DC`, `DEL`

### Campo País / Nacionalidad

El campo en BD y modelo se llama `Nacionalidad`. En UI se puede mostrar como "País". Lista predefinida en `Nacionalidades.all` (`app_constants.dart`):

Uruguay, Argentina, Brasil, Chile, Paraguay, Bolivia, Perú, Ecuador, Colombia, Venezuela, Estados Unidos, España, Italia, Otra.

Default: Uruguay.

---

## 7. Gestión de partidos

### Funcionalidades implementadas

- **Listado** (`MatchesScreen`): chips de filtro por año, ordenados EnJuego primero → Programado → Finalizado/Cancelado, dentro del grupo por fecha descendente
- **Creación/Edición** (`MatchFormScreen`): rival, fecha, hora, tipo de competición, categoría, lugar, esLocal
- **Detalle** (`MatchDetailScreen`): información + resumen de alineación + botón de acción según estado
- **Soft delete**: campo `Activo = false`. El partido desaparece del listado pero eventos y estadísticas se conservan

### Estados de partido

| Valor | Descripción | Transición |
|---|---|---|
| `Programado` | Partido futuro sin empezar | → EnJuego al iniciar |
| `EnJuego` | Partido en curso | → Finalizado al terminar |
| `Finalizado` | Partido terminado | Estado final |
| `Cancelado` | Partido no jugado | Estado final |

### Navegación desde detalle según estado

- `Programado` → botón "Iniciar partido" → `patchEstado("EnJuego")` → navega a live
- `EnJuego` → botón "Continuar partido en vivo" → navega a live
- `Finalizado` → botón "Ver resumen" → navega a summary

### Endpoint PATCH de estado

`PATCH /api/Partidos/{id}/estado` acepta: `Estado`, `GolesEquipo?`, `GolesRival?`, `MinutoActual?`. Se usa para persistir minuto, marcador y estado durante el partido en vivo.

### Política de borrado

- **No borrar físicamente** partidos con eventos registrados (se perdería historial)
- Usar siempre soft delete: `Activo = false`
- Filtro por año en listado para que partidos viejos no saturen la pantalla

---

## 8. Carga de alineación

### Flujo completo

1. Desde detalle del partido → "Cargar alineación" → `LineupScreen` (`/matches/:id/lineup`)
2. Selector de formación (chips horizontales)
3. Cancha visual dibujada con `CustomPainter` con 11 slots posicionados
4. Tap en un slot → bottom sheet con selector de jugadores
5. Selector: jugadores de la posición esperada primero, luego el resto. Búsqueda por nombre
6. Si se asigna un jugador que ya estaba en otro slot → se mueve automáticamente
7. Barra fija al fondo → "Suplentes (N) ▲" → sheet con lista de suplentes y botón "Agregar"
8. Botón "Guardar (N/11)" habilitado solo cuando los 11 titulares están completos

### Formaciones disponibles

| Formación | Defensa | Mediocampo | Delantera | Notas |
|---|---|---|---|---|
| `4-3-3` | LD, DFC, DFC, LI | MC, MC, MC | EI, DC, ED | Los 3 mediocampistas son todos MC |
| `4-4-2` | LD, DFC, DFC, LI | MD, MC, MC, MI | DC, DC | MD y MI más adelantados visualmente |
| `4-2-3-1` | LD, DFC, DFC, LI | MCD, MCD + ED, MCO, EI | DC | Dos pivotes + tridente detrás del punta |
| `3-5-2` | DFC, DFC, DFC | MD, MC, MC, MC, MI | DC, DC | MD y MI más adelantados visualmente |
| `3-4-3` | DFC, DFC, DFC | MD, MC, MC, MI | EI, DC, ED | MD y MI más adelantados visualmente |

### Reglas de elegibilidad en el picker

- Solo `Estado = Disponible` (excluye Lesionado y Suspendido)
- Solo jugadores de la misma `CategoriaId` que el partido
- Solo `Activo = true`
- Un jugador no puede ocupar dos slots titulares a la vez
- Un titular no puede ser suplente simultáneamente

> **Nota sobre reconstrucción al reentrar:** El picker usa solo jugadores disponibles. Pero para reconstruir la alineación guardada (mostrar en cancha), se usa la lista completa de activos de la categoría — así un jugador lesionado *después* de ser asignado sigue apareciendo en su slot.

### Persistencia en la BD

- **Titulares:** `EsTitular = true`, `PosicionAsignada = slotKey` (ej. `"DFC1"`, `"MC2"`, `"ARQ"`)
- **Suplentes:** `EsTitular = false`, `PosicionAsignada = null`
- **Formación elegida:** se guarda en `Partido.Formacion` via `PUT /api/Partidos/{id}/alineacion` con campo `Formacion`
- El endpoint reemplaza **toda** la alineación en cada guardado

---

## 9. Registro de eventos en vivo

### LiveMatchScreen (`/matches/live/:id`)

Pantalla full-screen. Al cargar: carga partido, alineación, tipos de evento y eventos existentes. El marcador se **reconstruye desde los eventos** (no desde `partido.golesEquipo`).

### Interacción con la cancha

1. Tap en la cancha → coordenadas normalizadas (0.0–1.0) guardadas como `PitchX`, `PitchY`
2. Aparece menú radial con 8 sectores
3. Arrastrar sobre un sector → se resalta
4. Soltar → selecciona el tipo de evento

### Sectores del menú radial (8 primarios, definidos en `EventTypes.radialPrimary`)

Pase correcto, Pase incorrecto, Remate, Gol, Falta, Recuperación, Centro, Intercepción.

### Todos los tipos de evento disponibles

Pase correcto, Pase clave, Pase incorrecto, Remate, **Gol**, **Gol rival**, Recuperación, Falta, Intercepción, Centro, Asistencia, Tarjeta amarilla, Tarjeta roja, Atajada, Corner, Offside, Pérdida, Entrada exitosa, Entrada fallida.

### Flujos especiales

- **Gol rival:** no pide jugador. Registra evento con `jugadorId = null` y sube el marcador visitante
- **Asistencia:** flujo de 2 pasos — primero elige asistidor, luego elige goleador. Registra `Asistencia` para el asistidor y `Gol` para el goleador
- **Undo:** ventana de 5 segundos post-registro para deshacer; llama `DELETE /api/Partidos/{id}/eventos/{eventoId}`

### Regla conceptual fundamental

> **Los eventos son la fuente de verdad.** El marcador, las estadísticas y el PDF deben derivarse desde los eventos registrados. El marcador se reconstruye contando eventos tipo "Gol" y "Gol rival". Nunca subir el marcador en pantalla sin crear el evento correspondiente.

---

## 10. Marcador y goles

### Lógica de reconstrucción al cargar

```dart
_homeScore = events.where((e) => e.tipoEventoNombre == 'Gol').length;
_awayScore = events.where((e) => e.tipoEventoNombre == 'Gol rival').length;
```

Esto se ejecuta en `_loadData()` al iniciar `LiveMatchScreen`.

### Persistencia al salir

Al pausar el cronómetro o al presionar Atrás, se llama `_saveProgress()` que hace fire-and-forget de `PATCH /estado` con marcador y minuto actuales. Esto persiste en `Partido.GolesEquipo` y `Partido.GolesRival`.

---

## 11. Asistencias

### Problema resuelto

Antes, registrar asistencia no creaba el evento de gol ni subía el marcador.

### Flujo actual (2 pasos)

1. Usuario selecciona "Asistencia"
2. **Paso 1:** Picker muestra "¿Quién asistió?" → elige jugador asistidor (o "Sin jugador")
3. **Paso 2:** Picker muestra "¿Quién hizo el gol?" → elige goleador
4. Se registra evento `Asistencia` para el asistidor
5. Se registra evento `Gol` para el goleador
6. Se incrementa `_homeScore`

Estado interno en `LiveMatchScreen`: `_assistPlayer` (PlayerModel? del asistidor), `_pickingGoalScorer` (bool que activa el paso 2).

---

## 12. Cronómetro / tiempo de partido

### Problema resuelto

El cronómetro vivía solo en memoria (`Timer.periodic` + `_minute`). Al salir y volver, se reiniciaba desde 0.

### Solución implementada

Al **pausar** y al presionar **Atrás**, se llama `_saveProgress()` que persiste `MinutoActual` en el backend via `PATCH /estado`. Al reentrar, se carga `partido.minutoActual` e inicializa `_minute` desde ese valor.

**Limitación conocida:** Si el dispositivo pierde conexión durante el partido, el minuto puede no persistirse. La lógica offline-first aplica para eventos pero no para el minuto del cronómetro.

---

## 13. Resumen post-partido

### MatchSummaryScreen (`/matches/:id/summary`)

Accesible desde el detalle cuando `Estado = Finalizado`. Carga partido y eventos en paralelo.

### Componentes actuales

- **ScoreBanner:** resultado, rival, fecha
- **InfoCard:** metadatos (categoría, lugar, tipo, local/visitante)
- **StatsCard:** conteo de eventos por tipo
- **HighlightsCard:** goles, tarjetas amarillas, tarjetas rojas con jugador
- **EventsCard:** timeline cronológico completo de eventos
- **Botón PDF:** exporta via `MatchReportPdfExporter.export(match, events)`

### Mejoras pendientes

- Top jugadores por participación
- Comparativa primer tiempo vs. segundo tiempo (eventos antes y después del minuto 45)
- Zonas de eventos en mapa de cancha (si hay coordenadas `PitchX`, `PitchY`)
- Eficacia ofensiva (goles / remates)

El resumen también es accesible desde `ReportsScreen` (`/reports`), donde se lista todos los partidos con opción de exportar PDF directamente.

---

## 14. PDF y estadísticas

### Estado actual

`MatchReportPdfExporter` genera un PDF A4 con: título, marcador, metadatos, tabla de eventos por tipo, sección de goles y tarjetas, lista completa de eventos. Es funcional pero básico.

Nombre del archivo: `partido_vs_{rival}_{YYYYMMDD}.pdf`.

### Métricas recomendadas para mejorar

- Resumen ejecutivo (goles, asistencias, remates, faltas)
- Participaciones de gol = goles + asistencias por jugador
- Eficacia ofensiva = goles / remates totales
- Top jugadores por cantidad de eventos positivos
- Timeline visual de eventos
- Comparativa 1T vs 2T

> **Principio:** No inventar métricas si no hay datos suficientes. No implementar xG. Los eventos son la única fuente de datos para estadísticas.

---

## 15. Navegación

### Rutas definidas en `app_router.dart`

| Ruta | Pantalla | En shell |
|---|---|---|
| `/` | Dashboard | Sí |
| `/players` | Listado jugadores | Sí |
| `/players/new` | Crear jugador | No |
| `/players/:id` | Detalle jugador | No |
| `/players/:id/edit` | Editar jugador | No |
| `/matches` | Listado partidos | Sí |
| `/matches/new` | Crear partido | Sí (sub) |
| `/matches/:id` | Detalle partido | Sí (sub) |
| `/matches/:id/summary` | Resumen partido | Sí (sub) |
| `/matches/:id/edit` | Editar partido | No |
| `/matches/:id/lineup` | Alineación | No |
| `/matches/live/:id` | Partido en vivo | No |
| `/statistics` | Estadísticas (stub) | Sí |
| `/reports` | Reportes | Sí |
| `/training` | Entrenamientos (stub) | Sí |
| `/observations` | Observaciones (stub) | Sí |

### Reglas de navegación

- Redirect global: sin sesión → `/login`. Autenticado en `/login` → `/`
- Desde resumen post-partido, la flecha atrás vuelve al detalle
- Para volver directamente a gestión de partidos usar `context.go('/matches')` (no `context.pop()`)
- **Verificar siempre las rutas reales en `app_router.dart`** antes de hardcodear strings

---

## 16. Tema visual

### Paleta de colores (dark theme — única implementada)

| Token | Valor | Uso |
|---|---|---|
| `bgDeep` | `#080E1A` | Fondo más oscuro (body) |
| `bgSurface` | `#0F172A` | AppBar, sidebar, barra de suplentes |
| `bgCard` | `#1E293B` | Cards, tiles |
| `bgMuted` | `#263045` | Fondos secundarios |
| `accent` | `#10B981` | Verde esmeralda — acento principal |
| `accentDim` | Variante oscura de accent | Fondos de elementos seleccionados |
| `textPrimary` | Blanco suave | Texto principal |
| `textSecondary` | Gris medio | Texto secundario |
| `textMuted` | Gris oscuro | Texto terciario, placeholders |
| `danger` | Rojo | Errores, acciones destructivas |
| `warning` | Ámbar | Advertencias |

**Regla:** No hardcodear colores en widgets. Siempre usar las constantes de `AppColors`.

### Tipografía

- **Inter** (Google Fonts): toda la interfaz
- **JetBrains Mono** (Google Fonts): valores numéricos en stats

### Decisión sobre modo claro/oscuro

No se implementa todavía. La app usa exclusivamente dark theme. Si se desea en el futuro, habría que migrar `AppColors` de `static const` a valores dinámicos y usar `ThemeData` de Flutter — eso implica modificar todos los widgets. Es deuda técnica conocida.

---

## 17. Decisiones técnicas importantes

- **Flutter no se conecta directamente a SQL Server.** Todo pasa por la API REST. No usar paquetes de conexión directa desde Flutter.
- **No cambiar la estructura de la BD sin evaluar el impacto completo.** Cada cambio en tabla requiere actualizar: modelo EF, DTO, endpoint, y modelo Flutter.
- **Validaciones de negocio van en el backend.** El frontend valida solo para UX rápida.
- **Offline-first para eventos.** `EventApi.createEvento` intenta la API; si falla por red, encola en `sync_queue` con ID negativo local. `SyncService.syncPendingActions()` los reenvía cuando hay conexión.
- **Caché sin TTL.** La caché JSON en SQLite no expira por tiempo, solo se invalida al escribir. Tener en cuenta al debuggear datos desactualizados.
- **Soft delete en jugadores y partidos** via campo `Activo`. Todos los `GET` filtran por `Activo = true`. El historial se conserva.
- **Toda categoría debe existir previamente.** El seed solo incluye "Primera". Para Sub-17, Reserva, etc., hay que insertarlas en `Categorias`.
- **Evitar sobreingeniería.** El objetivo es una tesis funcional y defendible. Priorizar funcionalidad sobre abstracción.

---

## 18. Pendientes identificados

| Ítem | Prioridad | Notas |
|---|---|---|
| INSERT manual "Gol rival" en TiposEvento | 🔴 Alta | Sin esto el registro de gol rival falla |
| `ALTER TABLE Partidos ADD Formacion` | 🔴 Alta | Si la columna no existe, la alineación no guarda formación |
| Resumen post-partido: métricas avanzadas | 🟡 Media | Pantalla existe, métricas adicionales pendientes |
| PDF: reporte más completo | 🟡 Media | Funcional pero básico |
| PlayerDetailScreen: tabs 2, 3 y 4 | 🟡 Media | Carga física, Partidos, Observaciones — vacíos |
| Dashboard: KPIs desde datos reales | 🟡 Media | Parcialmente estático |
| StatisticsScreen | 🟢 Baja | Stub total |
| TrainingScreen | 🟢 Baja | Stub total — tabla SQL existe sin API |
| ObservationsScreen | 🟢 Baja | Stub total — tabla SQL existe sin API |
| Registro hardcodea rolId=1 | 🟢 Baja | Intencional para beta |
| SyncService no se llama automáticamente | 🟢 Baja | Requiere trigger manual al reconectar |

---

## 19. Riesgos

- **Cambiar nombres de campos en BD o backend** puede romper el frontend silenciosamente. Los campos se mapean por nombre en `fromApi()` con `json['fieldName']`.
- **Cambiar los códigos de posición** (ARQ, DFC, MC, etc.) afecta filtros de jugadores, slots de alineación y preferencia en el picker. Son strings idénticos en toda la app.
- **Borrar físicamente un partido con eventos** puede dejar eventos huérfanos. **Siempre usar soft delete.**
- **Subir marcador sin crear evento correspondiente:** el marcador se desfasa al recargar porque se reconstruye contando eventos.
- **Modificar múltiples pantallas a la vez** sin verificar compilación aumenta el riesgo de romper la navegación.
- **La caché SQLite puede mostrar datos viejos** si se modifica algo en la BD directamente (sin pasar por la API).

---

## 20. Cómo debe trabajar la IA a partir de este contexto

1. **Leer antes de modificar.** Antes de tocar cualquier archivo, leerlo completo. No asumir su contenido basándose en el nombre o en este documento (puede haber cambiado).

2. **Proponer archivos antes de cambiarlos.** Identificar y mencionar qué archivos se van a modificar y por qué, antes de escribir código.

3. **Cambios incrementales.** No reescribir pantallas completas sin que el usuario lo pida. Modificar solo lo estrictamente necesario para la tarea.

4. **No tocar módulos no relacionados.** Un cambio en eventos no debe alterar la gestión de jugadores. Un cambio en la alineación no debe tocar el cronómetro.

5. **Respetar decisiones ya tomadas.** No proponer refactors de arquitectura ni cambio de librerías sin que el usuario lo solicite. El stack está definido.

6. **Si requiere cambio de base de datos, explicarlo primero.** Indicar exactamente el SQL a ejecutar antes de implementar el cambio en backend/frontend.

7. **Verificar compilación.** Después de cada cambio, confirmar que no hay errores (`dart analyze` o `dotnet build`). No reportar trabajo como terminado si hay errores.

8. **Mantener coherencia visual.** Usar siempre `AppColors` para colores. No hardcodear `Colors.red` ni hex directamente en widgets. Seguir el estilo de `app_widgets.dart`.

9. **Priorizar solución simple y defendible.** Es una tesis, no un producto de empresa. Una solución que funcione correctamente y se pueda explicar vale más que una arquitectura perfecta.

10. **Los eventos son la fuente de verdad.** El marcador, las estadísticas y los reportes se calculan desde los eventos guardados. No mantener estado duplicado que pueda desincronizarse.

11. **No inventar rutas, endpoints ni nombres de campos.** Verificar siempre en `app_router.dart`, en los controllers del backend y en `models.dart` antes de usarlos en código nuevo.

12. **Soft delete siempre.** Jugadores y partidos usan `Activo = false`. Nunca `context.Jugadores.Remove()` ni `context.Partidos.Remove()`.
