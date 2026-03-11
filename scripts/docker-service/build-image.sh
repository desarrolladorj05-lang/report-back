#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

IMAGE_NAME="${IMAGE_NAME:-backend-reports-isi}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE_TAR="${IMAGE_TAR:-$PROJECT_ROOT/${IMAGE_NAME}.tar}"

echo "[1/2] Construyendo imagen Docker..."
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" -f "$PROJECT_ROOT/Dockerfile" "$PROJECT_ROOT"

echo "[2/2] Exportando imagen a tar..."
docker save "${IMAGE_NAME}:${IMAGE_TAG}" > "${IMAGE_TAR}"

echo "Imagen generada: ${IMAGE_TAR}"
