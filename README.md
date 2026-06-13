# Futbol Stats App

Aplicacion para registrar eventos de futbol, gestionar informacion deportiva y generar estadisticas para el analisis de partidos.

## Tecnologias

- Flutter
- .NET
- SQL Server
- Entity Framework
- JWT para autenticacion

## Estructura del proyecto

```text
backend/
  FutbolStats.api/        API REST en .NET

frontend/
  estadisticas_futbol/   Aplicacion Flutter
```

## Backend

La API se ejecuta por defecto en:

```text
http://localhost:5223
```

Swagger:

```text
http://localhost:5223/swagger
```

Para correr la API:

```bash
dotnet run --project backend/FutbolStats.api/FutbolStats.api.csproj --urls http://localhost:5223
```

## Base de datos

La base utilizada es:

```text
FutbolStatsDb
```

En desarrollo se usa SQL Server. Cada integrante puede tener una configuracion local distinta, por lo que no se deben subir connection strings personales, usuarios, contrasenas ni rutas de la computadora.

## Frontend

Para correr la app Flutter:

```bash
cd frontend/estadisticas_futbol
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5223
```

URLs segun entorno:

- Emulador Android: `http://10.0.2.2:5223`
- Navegador o escritorio: `http://localhost:5223`
- Celular fisico: `http://IP-DE-LA-COMPUTADORA:5223`

## Autenticacion

El proyecto incluye:

- Registro de usuarios
- Inicio de sesion
- Tokens JWT
- Validacion del usuario autenticado
- Persistencia local de sesion en Flutter
- Cierre de sesion
- Rutas protegidas en la app

## Flujo de trabajo

- `main`: versiones estables.
- `develop`: integracion de tareas terminadas.
- `feature/...`: ramas para desarrollar cada funcionalidad.

No se trabaja directo sobre `main` ni `develop`. Cada tarea debe hacerse en una rama propia y luego integrarse cuando este probada.

Antes de crear modelos, tablas, servicios o pantallas nuevas, revisar si ya existe algo relacionado para evitar duplicar codigo o pisar el trabajo de otro integrante.
