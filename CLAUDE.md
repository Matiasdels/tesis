# Kancha — contexto para Claude

App de gestión y estadística de fútbol amateur/semiprofesional (Flutter + .NET + SQL Server).
Nació como tesis (Analista Programador, club Colón FC, Uruguay; defendida con 100/100).
**Objetivo actual: terminar el producto para poder venderlo a clubes reales.**

`KANCHA_CONTEXTO.md` (03/07) y `AUDITORIA.md` (30/07) son **históricos y están desactualizados**.
Este archivo manda; verificá siempre contra el código antes de afirmar algo.

## Estructura

```
backend/FutbolStats.api/    API REST .NET 10 (controllers, Services, Models, Data, Auth, Options)
backend/FutbolStats.Tests/  xUnit, 111 tests (lógica pura: validadores, estados, plantel, estadísticas)
backend/database/           Scripts SQL manuales 01..10 (NO hay EF migrations)
frontend/estadisticas_futbol/  Flutter (lib/core, data/{local,remote}, models, screens, widgets, services)
docs/CONFIGURATION.md       Cómo configurar y correr (dart-define, user-secrets)
dev.sh                      Levanta backend + frontend
```

Stack: Flutter (go_router, provider, sqflite, fl_chart, pdf+printing) · ASP.NET Core + EF Core · SQL Server
(local: `localhost\SQLEXPRESS`, DB `FutbolStatsDb`) · JWT + refresh token · Gemini para análisis con IA.
Flutter nunca habla con SQL Server: todo va por la API (puerto 5224).

## Comandos

```bash
cd backend && dotnet build && dotnet test            # 111 tests, todos pasan
cd frontend/estadisticas_futbol && flutter analyze && flutter test   # 1 info menor, 47 tests pasan
dotnet run --project backend/FutbolStats.api         # http://localhost:5224 (Swagger en /swagger)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5224   # Android emu; 127.0.0.1 iOS sim
```

`MATCH_SECONDS_PER_MINUTE` por defecto es 60 (tiempo real). Con `=1` el partido dura 90 s: solo para pruebas.
En release `API_BASE_URL` es obligatoria.

## Estado funcional (octubre 2026)

Hecho y funcionando: login/registro/refresh silencioso/logout · usuarios y roles · jugadores (CRUD, estados
Disponible/Lesionado/Suspendido con fecha de regreso, soft delete, detalle con partidos, actividad, carga física,
observaciones) · partidos (CRUD, ciclo de vida con máquina de estados, soft delete) · alineación visual con 5
formaciones y suplentes · partido en vivo (cancha con menú radial configurable, cronómetro, entretiempo,
alargue, penales, cambios con límite, undo 15 s, multiusuario con refresco cada 5 s, offline-first con cola de
sync y reintentos) · resumen post-partido con mapa de calor · PDF (mapa de calor, métricas) · análisis con IA
(Gemini, opcional) · entrenamientos con asistencia/RPE · observaciones · estadísticas globales · dashboard ·
configuración de la app · tema claro/oscuro · acceso de solo lectura para rol Jugador.

El backend ya no tiene los problemas críticos de la auditoría: transiciones de estado validadas
(`PartidoEstados`), eventos solo en `EnJuego`/`EsperandoPenales`, alineación solo en `Programado`, límite de
cambios (`MatchRules:MaxCambiosPorPartido`=5), rate limit en login, `GlobalExceptionHandler`, constantes de
eventos en `EventTypeNames`, registro público restringido a "Cuerpo tecnico" y "Jugador".

## Reglas de dominio que no se deben romper

- **Los eventos son la fuente de verdad.** Marcador y estadísticas se derivan de `EventosPartido`
  (Gol / Gol rival). Nunca subir el marcador sin crear el evento.
- **Soft delete** (`Activo=false`) en jugadores, partidos y entrenamientos. Nunca `Remove()`.
- **Estados de partido:** `Programado → EnJuego → (EsperandoPenales) → Finalizado`; `Cancelado` desde los no
  terminales. `Finalizado` y `Cancelado` son terminales. Toda lógica pasa por `PartidoEstados`.
- **Cambio de jugador:** `JugadorId` = el que sale, `JugadorRelacionadoId` = el que entra.
- **Asistencia en vivo:** 2 pasos (asistidor → goleador); registra Asistencia + Gol.
- Strings sincronizados backend/frontend/BD, **no renombrar**: estados de jugador y partido, códigos de
  posición (ARQ, LD, DFC, LI, MD, MCD, MC, MCO, MI, ED, EI, DC, DEL), nombres de tipos de evento
  (`EventTypeNames.cs` ↔ `EventTypes` en `app_constants.dart`), nombres de rol, `PeriodoActual`.
- Tipos de evento legacy (Pase correcto/incorrecto, Entrada exitosa/fallida) solo se muestran, no se registran.
- Validación de negocio en el backend; el frontend valida solo para UX.

## Roles y permisos

Roles en BD: `Responsable institucional`, `Cuerpo tecnico`, `Jugador` (script 07; los legacy Admin, Entrenador,
etc. se siguen aceptando por compatibilidad en `AppRoles.cs` y `role_permissions.dart`).
- Gestión de usuarios (`/api/Usuarios`, `/users`): solo Responsable institucional.
- Escritura deportiva (`EscrituraDeportiva`): Responsable + Cuerpo técnico.
- Jugador: solo lectura. Lectura de todo requiere solo token válido.
- Los permisos están duplicados en backend (`AppRoles`) y frontend (`RolePermissions`): cambiar ambos.

## Base de datos

Scripts manuales en `backend/database/`, en orden 01→10, los 03+ son migraciones idempotentes o incrementales.
**Ojo:** `02_seed_data.sql` tiene cambios sin commitear que lo pisan con el contenido de la migración 10
(se perdió el seed de categorías/roles/tipos de evento en el working copy). Verificar con `git diff` antes de
commitear; probablemente hay que restaurarlo con `git checkout -- backend/database/02_seed_data.sql`.
Cada cambio de tabla exige tocar: script SQL, modelo EF, DTO/endpoint y modelo Flutter (`fromApi`).

## Configuración y secretos

`appsettings.json` es compartido (JWT con placeholder, modelo Gemini). `appsettings.Development.json` y
`appsettings.Production.json` están en `.gitignore`; la Production local apunta a una Azure SQL
(`kancha-server-2026`) y trae secretos: **nunca imprimirlos, citarlos ni commitearlos**. La API key de Gemini va
por user-secrets o `Gemini__ApiKey`. Ya hay un entorno Azure; no hay IaC ni CI en el repo.

## Flujo de trabajo (git)

`main` es versión estable pero está **muy atrasada** (quedó en el commit inicial); el trabajo real vive en
`develop` (~200 commits por delante). Ramas `feature/...` y `fix/...` por tarea, se integran a `develop`.
No trabajar directo sobre `main`/`develop`. No hacer commit/push sin que el usuario lo pida.

## Convenciones de código

- Dart: colores siempre de `AppColors`, tipografía de `app_typography.dart`, widgets compartidos en
  `widgets/common/app_widgets.dart`. Rutas desde `AppConstants` y `app_router.dart` (verificar antes de usarlas).
- C#: DTOs como records, excepciones de dominio (`DomainValidationException` → 400, `DomainConflictException` → 409).
- Comentarios y textos de UI en español (rioplatense: "Volvé a iniciar sesión").
- Pantallas gigantes: `live_match_screen.dart` (~4400 líneas), `match_report_pdf_exporter.dart` (~1900),
  `main_shell.dart` (~1500). Cambios incrementales y puntuales; leer el archivo antes de tocarlo.
- Después de cada cambio: `dotnet build && dotnet test` y `flutter analyze && flutter test`.

## Brechas conocidas hacia un producto vendible (observadas leyendo el código)

- **Sin multi-tenant:** no existe entidad Club; todos los datos son de una sola organización.
- **Registro público abierto:** cualquiera puede registrarse como "Cuerpo tecnico" y obtener escritura sobre
  todos los datos. Hace falta invitación o alta controlada por el Responsable.
- Categorías: solo hay `GET /api/Catalogos/categorias`; no hay alta/edición desde la app.
- El usuario con rol Jugador no está vinculado a una entidad `Jugador` (`Usuario` no tiene `JugadorId`).
- JWT `SecretKey` placeholder en `appsettings.json`; CORS solo para localhost; sin CI/CD; sin backups ni
  migraciones versionadas (scripts manuales).
- `flutter analyze`: 1 info en `match_detail_screen.dart:321` (`_posOrder` local con guion bajo).
- Sin tests de controllers ni de integración; los 111 tests backend cubren solo lógica pura.
- Pendientes de la auditoría que conviene reverificar: token JWT en SQLite sin cifrar, `Rpe` en asistencias,
  tipo de `Observacion.Tipo` siempre "General", `SetAsistencia` atómico, soft delete de jugador con partidos
  programados.
