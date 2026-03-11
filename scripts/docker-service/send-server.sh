#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

IMAGE_NAME="${IMAGE_NAME:-backend-reports-isi}"
IMAGE_TAR="${IMAGE_TAR:-$PROJECT_ROOT/${IMAGE_NAME}.tar}"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env.production}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$PROJECT_ROOT/scripts/docker-service}"
TARGET="${TARGET:-isi:/home/ubuntu/proyects/backend-reports-isi}"
SSH_OPTS="${SSH_OPTS:--o StrictHostKeyChecking=accept-new}"

if [[ ! -f "$IMAGE_TAR" ]]; then
  echo "No se encontró la imagen exportada: $IMAGE_TAR"
  echo "Ejecuta primero: bash $SCRIPT_DIR/build-image.sh"
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No se encontró el archivo de entorno: $ENV_FILE"
  exit 1
fi

if [[ ! -d "$SCRIPTS_DIR" ]]; then
  echo "No se encontró la carpeta de scripts: $SCRIPTS_DIR"
  exit 1
fi

TARGET_HOST="${TARGET%%:*}"
TARGET_DIR="${TARGET#*:}"
REMOTE_SCRIPTS_DIR="$TARGET_DIR/scripts"
echo "[SYNC] Creando carpeta remota si no existe: $TARGET_DIR"
ssh $SSH_OPTS "$TARGET_HOST" "mkdir -p '$TARGET_DIR' '$REMOTE_SCRIPTS_DIR'"

echo "[SYNC] Enviando imagen y .env.production al servidor..."
rsync -avz --progress -e "ssh $SSH_OPTS" "$IMAGE_TAR" "$ENV_FILE" "$TARGET"

echo "[SYNC] Enviando scripts al servidor..."
rsync -avz --progress -e "ssh $SSH_OPTS" "$SCRIPTS_DIR/" "$TARGET_HOST:$REMOTE_SCRIPTS_DIR/"
ssh $SSH_OPTS "$TARGET_HOST" "chmod +x '$REMOTE_SCRIPTS_DIR/'*.sh"

echo "[SYNC] Archivos enviados correctamente."
