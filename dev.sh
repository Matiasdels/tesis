#!/usr/bin/env bash
# Levanta backend y frontend en paralelo.
# Uso: ./dev.sh [flutter-device-id]
# Ejemplo: ./dev.sh chrome

set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
DEVICE="${1:-macos}"

cleanup() {
  echo "\nDeteniendo procesos..."
  kill "$BE_PID" "$FE_PID" 2>/dev/null
  wait "$BE_PID" "$FE_PID" 2>/dev/null
}
trap cleanup INT TERM

echo "▶ Backend (compilando)..."
dotnet run \
  --project "$ROOT/backend/FutbolStats.api/FutbolStats.api.csproj" &
BE_PID=$!

echo "▶ Frontend..."
cd "$ROOT/frontend/estadisticas_futbol"
flutter run ${DEVICE:+--device-id "$DEVICE"} &
FE_PID=$!

wait "$BE_PID" "$FE_PID"
