#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.env.production}"
IMAGE_NAME="${IMAGE_NAME:-backend-reports-isi}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_NAME="${CONTAINER_NAME:-backend-reports-isi}"
NETWORK="${NETWORK:-backend-punto-venta_mynetwork}"
PORT_MAPPING="${PORT_MAPPING:-1506:1506}"
VOLUME="${VOLUME:-}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No se encontró el archivo de entorno: $ENV_FILE"
  exit 1
fi

docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" -f "$PROJECT_ROOT/Dockerfile" "$PROJECT_ROOT"

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  docker rm -f "$CONTAINER_NAME"
fi

DOCKER_RUN_ARGS=(
  -d
  --name "$CONTAINER_NAME"
  --network "$NETWORK"
  -p "$PORT_MAPPING"
  --env-file "$ENV_FILE"
)

if [[ -n "$VOLUME" ]]; then
  DOCKER_RUN_ARGS+=(-v "$VOLUME")
fi

docker run "${DOCKER_RUN_ARGS[@]}" "${IMAGE_NAME}:${IMAGE_TAG}"
