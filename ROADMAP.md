# Roadmap Kancha — de tesis a producto

Objetivo: tener una versión que se pueda ofrecer a clubes reales. Cada fase se trabaja en ramas
chicas (`feature/...`, `fix/...`, `chore/...`) que se integran a `develop`.

## Fase 0 — Higiene (base para trabajar tranquilo)
- [ ] Restaurar `02_seed_data.sql` (el working copy lo pisó con la migración 10)
- [ ] CI en GitHub Actions: `dotnet build` + `dotnet test` y `flutter analyze` + `flutter test` en cada push/PR
- [ ] Corregir el aviso de `flutter analyze` (`_posOrder` en `match_detail_screen.dart`)
- [ ] Sincronizar `main` con `develop` (hoy `main` quedó en el commit inicial) y definir cómo se etiquetan versiones
- [ ] Borrar `.gitignore.rtf` del repo (es un duplicado en formato RTF de `.gitignore`)

## Fase 1 — Seguridad de acceso
- [ ] Cerrar el registro público: alta por invitación o solo por el Responsable institucional
- [ ] Clave JWT obligatoria por entorno (que la API no arranque con el placeholder en producción)
- [ ] Guardar la sesión en almacenamiento seguro (`flutter_secure_storage`) en vez de SQLite plano
- [ ] CORS configurable por entorno
- [ ] Recuperación de contraseña

## Fase 2 — Datos y despliegue
- [ ] Migraciones versionadas (EF Core migrations) que reemplacen los scripts `01`–`10`
- [ ] Tests de integración de la API (permisos por rol, ciclo de vida del partido) con base de prueba
- [ ] Despliegue automático a un entorno de staging en Azure
- [ ] Backups y política de restauración de la base

## Fase 3 — Multi-club (el cambio más grande)
- [ ] Entidad `Club` y aislamiento de datos por club en todas las consultas
- [ ] Alta y edición de categorías desde la app
- [ ] Vincular usuarios con rol Jugador a su ficha de `Jugador`
- [ ] Onboarding de un club nuevo (primer usuario Responsable, categorías, plantel)

## Fase 4 — Producto
- [ ] Revisar la lista de pendientes de la auditoría (asistencia atómica, baja de jugador con partidos programados, etc.)
- [ ] Reportes y estadísticas por temporada/categoría
- [ ] Notificaciones y exportaciones (Excel/CSV además de PDF)
- [ ] Partir las pantallas gigantes (`live_match_screen`, `match_report_pdf_exporter`, `main_shell`)

## Fase 5 — Salida comercial
- [ ] Política de privacidad y términos (hay datos de personas, incluidos menores)
- [ ] Planes y cobro
- [ ] Publicación en tiendas (Play Store / App Store)
- [ ] Soporte, monitoreo de errores y métricas de uso

El orden es una propuesta: las fases 0–2 son prerrequisitos de vender; la 3 es la que habilita tener
más de un cliente en la misma instalación.
