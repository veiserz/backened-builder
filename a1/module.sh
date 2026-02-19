#!/usr/bin/env bash
# Usage: bash module.sh <module-name>
# Generates a new module following the standard template.
set -euo pipefail

MODULE="${1:?Usage: bash module.sh <module-name>}"
LOWER="$(echo "$MODULE" | tr '[:upper:]' '[:lower:]')"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/src"
DEST="$SRC/modules/$LOWER"

if [[ -d "$DEST" ]]; then
  echo "Module '$LOWER' already exists at $DEST"
  exit 1
fi

mkdir -p \
  "$DEST/routes" \
  "$DEST/controllers" \
  "$DEST/services" \
  "$DEST/repositories" \
  "$DEST/dtos" \
  "$DEST/middlewares" \

echo "// Public API of the ${LOWER} module" > "$DEST/index.js"
echo "// TODO: export service, repository interface, entity" >> "$DEST/index.js"

echo "✔  Module '$LOWER' scaffolded at $DEST"
echo "   Next steps:"
echo "   1. Define the domain entity in /${LOWER}.entity.js"
echo "   2. Define the repository interface in repositories/${LOWER}.repository.js"
echo "   3. Implement the adapter in infrastructure/${LOWER}.pg.repository.js"
echo "   4. Register in app/container/providers.js"
echo "   5. Mount routes in bootstrap/router.js"
