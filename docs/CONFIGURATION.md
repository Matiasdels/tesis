# Kancha — Guía de configuración y ejecución

## Requisitos

- Flutter 3.x
- .NET 10 SDK
- SQL Server (Express o superior)
- Android emulator, simulador iOS o dispositivo físico

---

## Backend

### Iniciar el servidor

```bash
cd backend/FutbolStats.api
dotnet run
```

La API estará disponible en `http://localhost:5224` (o el puerto configurado en `launchSettings.json`).

### Configurar JWT (requerido)

El valor por defecto en `appsettings.json` es un placeholder. Configurar en variables de entorno o en `secrets.json`:

```bash
dotnet user-secrets set "Jwt:SecretKey" "CLAVE_SECRETA_MUY_LARGA_Y_ALEATORIA"
```

### Configurar Gemini (opcional)

La IA es opcional. Si no se configura, el endpoint `/api/Partidos/{id}/analisis` responde con un mensaje controlado indicando que la función no está disponible.

El **modelo** ya está configurado en `appsettings.json` (compartido por el equipo).
La **API key** nunca se versiona — cada integrante la agrega localmente:

```bash
cd backend/FutbolStats.api
dotnet user-secrets set "Gemini:ApiKey" "tu-api-key-aqui"
```

O mediante variable de entorno (útil en CI o servidores):

```bash
export Gemini__ApiKey="tu-api-key-aqui"
```

Si necesitaras cambiar el modelo localmente (sobreescribe el valor de `appsettings.json`):

```bash
dotnet user-secrets set "Gemini:Model" "nombre-del-modelo"
```

> **Nunca commitear la API key.** `appsettings.json` contiene el modelo compartido pero no tiene `ApiKey`. La clave siempre va en user-secrets o variable de entorno.

---

## Frontend (Flutter)

### Configuración de la URL de la API

La URL se pasa como `dart-define`. Si no se pasa, en debug se usa `http://10.0.2.2:5224` (Android emulator). En release es obligatoria.

#### Emulador Android

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5224
```

#### Simulador iOS

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5224
```

#### Dispositivo físico (misma red que el servidor)

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.X:5224
```

Reemplazar `192.168.1.X` con la IP local del equipo donde corre el backend.

---

## Configuración del tiempo de partido

> ⚠️ **ADVERTENCIA CRÍTICA**
>
> Para una demo real o producción, el tiempo **debe ser 60**.
> Con `MATCH_SECONDS_PER_MINUTE=1` un partido dura 90 segundos reales.

### Modo real — demo / producción (OBLIGATORIO para la defensa)

```bash
flutter run \
  --dart-define=API_BASE_URL=http://<URL_BACKEND> \
  --dart-define=MATCH_SECONDS_PER_MINUTE=60
```

### Modo acelerado — pruebas internas

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:5224 \
  --dart-define=MATCH_SECONDS_PER_MINUTE=1
```

Con este modo: 1 segundo real = 1 minuto de partido. Un partido dura 90 segundos.

---

## Comandos de verificación

### Backend

```bash
cd backend
dotnet build
dotnet test
```

### Flutter

```bash
cd frontend/estadisticas_futbol
flutter analyze
flutter test
```

Tests de MatchTime con modo acelerado explícito:

```bash
flutter test --dart-define=MATCH_SECONDS_PER_MINUTE=1
```

Tests de MatchTime con modo real (valor por defecto):

```bash
flutter test
```

---

## Resumen para la defensa

| Configuración | Valor |
|---|---|
| `API_BASE_URL` | URL real del servidor de demo |
| `MATCH_SECONDS_PER_MINUTE` | **60** |
| `Gemini:ApiKey` | En user-secrets local — si no está, la IA muestra mensaje controlado |
| `Gemini:Model` | Ya en `appsettings.json` — no requiere configuración adicional |

Ejemplo completo para defensa en dispositivo físico:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://192.168.1.X:5224 \
  --dart-define=MATCH_SECONDS_PER_MINUTE=60
```
