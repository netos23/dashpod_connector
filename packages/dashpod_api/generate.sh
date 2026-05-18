#!/usr/bin/env bash
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$PACKAGE_DIR/../.." && pwd)"
PACKAGE_REL="packages/dashpod_api"

echo "==> Generating API from OpenAPI spec..."
(cd "$WORKSPACE_ROOT" && dart run "$PACKAGE_REL/bin/gen.dart" \
  -i https://dashpod.fbtw.pro/api/v3/api-docs \
  -o "$PACKAGE_REL")

echo "==> Running build_runner..."
(cd "$PACKAGE_DIR" && dart run build_runner build)

echo "==> Done."
