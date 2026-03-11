#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REMOTE_DIR="${REMOTE_DIR:-$PROJECT_ROOT}"
IMAGE_NAME="${IMAGE_NAME:-backend-reports-isi}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CONTAINER_NAME="${CONTAINER_NAME:-backend-reports-isi}"
NETWORK="${NETWORK:-backend-managment-report_mynetwork}"
PORT_MAPPING="${PORT_MAPPING:-1506:1506}"
IMAGE_TAR_NAME="${IMAGE_TAR_NAME:-${IMAGE_NAME}.tar}"
ENV_FILE_NAME="${ENV_FILE_NAME:-.env.production}"

run_deploy() {
  local run_dir="$1"
  local image_name="$2"
  local image_tag="$3"
  local container_name="$4"
  local network="$5"
  local port_mapping="$6"
  local image_tar_name="$7"
  local env_file_name="$8"

  local image_tar_path="$run_dir/$image_tar_name"
  local env_file_path="$run_dir/$env_file_name"

  if [[ ! -f "$image_tar_path" ]]; then
    echo "No se encontró la imagen en: $image_tar_path"
    exit 1
  fi

  if [[ ! -f "$env_file_path" ]]; then
    echo "No se encontró el env file en: $env_file_path"
    exit 1
  fi

  if ! docker network inspect "$network" >/dev/null 2>&1; then
    echo "La red Docker no existe: $network"
    exit 1
  fi

  echo "[DEPLOY] Cargando imagen desde tar..."
  docker load -i "$image_tar_path"

  if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
    echo "[DEPLOY] Eliminando contenedor anterior: $container_name"
    docker rm -f "$container_name"
  fi

  echo "[DEPLOY] Creando nuevo contenedor..."
  docker run -d \
    --name "$container_name" \
    --network "$network" \
    -p "$port_mapping" \
    --env-file "$env_file_path" \
    "$image_name:$image_tag"

  echo "[DEPLOY] Despliegue completado."
}

run_deploy "$REMOTE_DIR" "$IMAGE_NAME" "$IMAGE_TAG" "$CONTAINER_NAME" "$NETWORK" "$PORT_MAPPING" "$IMAGE_TAR_NAME" "$ENV_FILE_NAME"
