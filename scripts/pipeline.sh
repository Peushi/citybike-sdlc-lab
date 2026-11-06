#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:?Usage: ./scripts/pipeline.sh <image-tag>}"
PROD_API_KEY="lab-secret"

export TARGET_URL="http://localhost:4174"
export IMAGE_NAME="$IMAGE"
wait_for_health() {
  local container="$1"

  for attempt in {1..30}; do
    if curl -sf "$TARGET_URL/health" >/dev/null; then
      return 0
    fi

    if ! docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null | grep -q true; then
      break
    fi

    sleep 1
  done

  echo "ERROR: $container failed its health check."
  docker logs "$container" || true
  docker rm -f "$container" 2>/dev/null || true
  return 1
}
echo "=== STAGING ==="
docker rm -f citybike-gate 2>/dev/null || true
docker run -d --name citybike-gate -p 4174:4173 \
  -e APP_ENV=staging "$IMAGE"
wait_for_health citybike-gate
./scripts/test-staging.sh
docker rm -f citybike-gate

echo "=== UAT ==="
docker run -d --name citybike-gate -p 4174:4173 \
  -e APP_ENV=uat "$IMAGE"
wait_for_health citybike-gate
./scripts/test-uat.sh
docker rm -f citybike-gate

echo "=== OAT ==="
docker run -d --name citybike-gate -p 4174:4173 \
  -e APP_ENV=oat "$IMAGE"
wait_for_health citybike-gate
./scripts/test-oat.sh
docker rm -f citybike-gate

echo "=== PRE-PROD ==="
docker run -d --name citybike-gate -p 4174:4173 \
  -e APP_ENV=preprod -e PROD_API_KEY="$PROD_API_KEY" "$IMAGE"
wait_for_health citybike-gate
./scripts/test-preprod.sh
docker rm -f citybike-gate

echo "=== PRODUCTION ==="
docker rm -f citybike-prod 2>/dev/null || true
docker run -d --name citybike-prod -p 4173:4173 \
  -e APP_ENV=production -e PROD_API_KEY="$PROD_API_KEY" "$IMAGE"
export TARGET_URL="http://localhost:4173"
wait_for_health citybike-prod
./scripts/test-prod.sh

echo "=== ALL FIVE GATES PASSED ==="
