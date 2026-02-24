#!/usr/bin/env bash
# =============================================================
#  Usage:  bash module.sh <module-name> [route-prefix]
#  Creates a full module scaffold under src/modules/<name>/
#  and auto-registers the route in src/bootstrap/router.js
# =============================================================
set -euo pipefail

MODULE="${1:?Usage: bash module.sh <module-name> [route-prefix]}"
ROUTE="${2:-$1}"

# ── Name derivations ─────────────────────────────────────────
LOWER="$(echo "$MODULE" | tr '[:upper:] -' '[:lower:]_')"
PASCAL="$(echo "$LOWER" | awk -F_ '{r=""; for(i=1;i<=NF;i++) r=r toupper(substr($i,1,1)) substr($i,2); print r}')"
ROUTE_PREFIX="$(echo "$ROUTE" | tr '[:upper:]' '[:lower:]')"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/src"
DEST="$SRC/modules/$LOWER"
ROUTER_FILE="$SRC/bootstrap/router.js"

[[ -d "$DEST" ]] && { echo "❌  Module '$LOWER' already exists."; exit 1; }
echo "⚙  Scaffolding '$LOWER' → /v1/$ROUTE_PREFIX …"

mkdir -p "$DEST" "$DEST/DTO" "$DEST/models" "$DEST/repository" \
         "$DEST/service" "$DEST/controller" "$DEST/middleware" "$DEST/router"

# ── index.js ─────────────────────────────────────────────────
cat > "$DEST/index.js" << EOF
'use strict';

/**
 * Public API of the ${LOWER} module.
 * Only these exports should be consumed by other modules.
 * Direct access to internals breaks encapsulation.
 */
module.exports = {
  ${PASCAL}Service:    require('./service').${PASCAL}Service,
  ${PASCAL}Repository: require('./repository').${PASCAL}Repository,
  ${PASCAL}Model:      require('./models').${PASCAL},
  createRouter:        require('./router').createRouter,
};
EOF

# ── Auto-register in bootstrap/router.js ─────────────────────
# The refactored router.js exports createRouter(container) and uses
# [AUTO-ROUTES-IMPORT] and [AUTO-USE] markers.
IMPORT_LINE="const { createRouter: create${PASCAL}Router } = require('../modules/${LOWER}');"
MOUNT_LINE="  router.use('/v1/${ROUTE_PREFIX}', create${PASCAL}Router(container.resolve('${LOWER}Service')));"

if grep -qF "create${PASCAL}Router" "$ROUTER_FILE"; then
  echo "⚠   Route already registered in router.js — skipped."
else
  sed -i "s|// \[AUTO-ROUTES-IMPORT\]|${IMPORT_LINE}\n// [AUTO-ROUTES-IMPORT]|" "$ROUTER_FILE"
  sed -i "s|  // \[AUTO-USE\]|${MOUNT_LINE}\n  // [AUTO-USE]|" "$ROUTER_FILE"
  echo "✔   Registered /v1/${ROUTE_PREFIX} in bootstrap/router.js"
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "✅  Module '${LOWER}' scaffolded at src/modules/${LOWER}/"
echo ""
echo "   Files created:"
echo "   ├── index.js"
echo "   ├── DTO/           (create · update · param · query · validate)"
echo "   ├── models/        (${LOWER}.model.js)"
echo "   ├── repository/    (${LOWER}.repository.js · queries.js)"
echo "   ├── service/       (${LOWER}.service.js)"
echo "   ├── controller/    (${LOWER}.controller.js)"
echo "   ├── middleware/    (${LOWER}.middleware.js)"
echo "   └── router/        (index.js)"
echo ""

# ── Auto-register in app/container/providers/ ────────────────
# The refactored structure splits providers into three files.
# We patch repositories.js and services.js independently.
REPOS_FILE="$SRC/app/container/providers/repositories.js"
SERVICES_FILE="$SRC/app/container/providers/services.js"

if [[ -f "$REPOS_FILE" && -f "$SERVICES_FILE" ]]; then
  if grep -qF "${LOWER}Repository" "$REPOS_FILE"; then
    echo "⚠   ${PASCAL} already registered in providers — skipped."
  else
    TMP_SCRIPT="$(mktemp)"
    cat > "$TMP_SCRIPT" << 'NODEJS'
const fs     = require('fs');
const lower  = process.argv[2];
const pascal = process.argv[3];
const reposFile    = process.argv[4];
const servicesFile = process.argv[5];

// ── repositories.js ──────────────────────────────────────────
let reposSrc = fs.readFileSync(reposFile, 'utf8');

const repoImport =
  `const { ${pascal}Repository } = require('../../../modules/${lower}/repository');\n`;

const repoBinding =
  `  c.singleton('${lower}Repository', ({ resolve }) => new ${pascal}Repository(resolve('db')));\n`;

reposSrc = reposSrc.replace('// [AUTO-REPO-IMPORTS]', repoImport + '// [AUTO-REPO-IMPORTS]');
reposSrc = reposSrc.replace('  // [AUTO-REPOS]',      repoBinding + '  // [AUTO-REPOS]');

fs.writeFileSync(reposFile, reposSrc, 'utf8');

// ── services.js ──────────────────────────────────────────────
let servicesSrc = fs.readFileSync(servicesFile, 'utf8');

const serviceImport =
  `const { ${pascal}Service } = require('../../../modules/${lower}/service');\n`;

const serviceBinding =
  `  c.singleton('${lower}Service', ({ resolve }) => new ${pascal}Service(resolve('${lower}Repository'), resolve('dispatcher')));\n`;

servicesSrc = servicesSrc.replace('// [AUTO-SERVICE-IMPORTS]', serviceImport + '// [AUTO-SERVICE-IMPORTS]');
servicesSrc = servicesSrc.replace('  // [AUTO-SERVICES]',      serviceBinding + '  // [AUTO-SERVICES]');

fs.writeFileSync(servicesFile, servicesSrc, 'utf8');
NODEJS
    node "$TMP_SCRIPT" "$LOWER" "$PASCAL" "$REPOS_FILE" "$SERVICES_FILE"
    rm -f "$TMP_SCRIPT"
    echo "✔   Registered ${LOWER}Repository in providers/repositories.js"
    echo "✔   Registered ${LOWER}Service    in providers/services.js"
  fi
else
  echo "⚠   providers/repositories.js or providers/services.js not found — add manually:"
  echo "      // in providers/repositories.js:"
  echo "      c.singleton('${LOWER}Repository', ({ resolve }) => new ${PASCAL}Repository(resolve('db')));"
  echo "      // in providers/services.js:"
  echo "      c.singleton('${LOWER}Service', ({ resolve }) => new ${PASCAL}Service(resolve('${LOWER}Repository'), resolve('dispatcher')));"
fi

echo "   Next steps:"
echo "   1. Edit DTO fields   → src/modules/${LOWER}/DTO/create.dto.js"
echo "   2. Edit model fields → src/modules/${LOWER}/models/${LOWER}.model.js"
echo "   3. Edit SQL queries  → src/modules/${LOWER}/repository/queries.js"
echo ""

# ── DTO/index.js ─────────────────────────────────────────────
cat > "$DEST/DTO/index.js" << EOF

// src/modules/store/DTO/index.js
"use strict";

const { Type } = require("@sinclair/typebox");

// ── Create ────────────────────────────────────────────────────────────────────

const CreateStoreDto = Type.Object({
  name: Type.String({
    minLength: 1,
    maxLength: 255,
    description: "Store display name",
  }),
});

// ── Update ────────────────────────────────────────────────────────────────────

const UpdateStoreDto = Type.Object({
  name: Type.Optional(Type.String({ minLength: 1, maxLength: 255 })),
});

// ── URL Params ────────────────────────────────────────────────────────────────

const StoreParamDto = Type.Object({
  id: Type.String({ format: "uuid" }),
});

// ── List Query ────────────────────────────────────────────────────────────────

const StoreListQueryDto = Type.Object({
  page: Type.Optional(Type.Integer({ minimum: 1, default: 1 })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100, default: 20 })),
});

// ── Response (for JSDoc typing only — not used for validation) ────────────────

const StoreResponseDto = Type.Object({
  id: Type.String({ format: "uuid" }),
  name: Type.String(),
  createdAt: Type.String({ format: "date-time" }),
  updatedAt: Type.String({ format: "date-time" }),
});

// ── Exports ───────────────────────────────────────────────────────────────────

module.exports = {
  CreateStoreDto,
  UpdateStoreDto,
  StoreParamDto,
  StoreListQueryDto,
  StoreResponseDto,
};

EOF

# ── models/<name>.model.js ───────────────────────────────────
cat > "$DEST/models/${LOWER}.model.js" << EOF
'use strict';

const { generateId } = require('../../../shared/utils/id');
const { now }        = require('../../../shared/utils/time');

class ${PASCAL} {
  constructor({ id, name, createdAt, updatedAt }) {
    this.id        = id        || generateId();
    this.name      = ${PASCAL}._normaliseName(name);
    this.createdAt = createdAt || now();
    this.updatedAt = updatedAt || now();
  }

  // ── Normalisation ──────────────────────────────────────────
  static _normaliseName(v) {
    return typeof v === 'string' ? v.trim().replace(/\s+/g, ' ') : v;
  }

  // ── Factories ─────────────────────────────────────────────

  /** Reconstruct entity from a PostgreSQL row (snake_case → camelCase). */
  static fromRecord(row) {
    return new ${PASCAL}({
      id:        row.id,
      name:      row.name,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    });
  }

  // ── Domain behaviour ──────────────────────────────────────

  /** Apply a validated update DTO onto this entity in-place. */
  applyUpdate(dto) {
    if (dto.name !== undefined) this.name = ${PASCAL}._normaliseName(dto.name);
    this.updatedAt = now();
  }

  // ── Serialisation ─────────────────────────────────────────

  /** Persist-ready record (camelCase → snake_case). */
  toRecord() {
    return {
      id:         this.id,
      name:       this.name,
      created_at: this.createdAt,
      updated_at: this.updatedAt,
    };
  }

  /** Safe public serialisation — no internal/sensitive fields. */
  toResponse() {
    return {
      id:        this.id,
      name:      this.name,
      createdAt: this.createdAt instanceof Date ? this.createdAt.toISOString() : this.createdAt,
      updatedAt: this.updatedAt instanceof Date ? this.updatedAt.toISOString() : this.updatedAt,
    };
  }
}

module.exports = { ${PASCAL} };
EOF

cat > "$DEST/models/index.js" << EOF
'use strict';
module.exports = require('./${LOWER}.model');
EOF

# ── repository/queries.js ────────────────────────────────────
cat > "$DEST/repository/queries.js" << EOF
'use strict';

// TODO: verify TABLE matches your migration file
const TABLE = '${LOWER}s';

const QUERIES = {
  FIND_BY_ID: 'SELECT * FROM ' + TABLE + ' WHERE id = \$1 LIMIT 1',
  FIND_ALL:   'SELECT * FROM ' + TABLE + ' ORDER BY created_at DESC LIMIT \$1 OFFSET \$2',
  COUNT:      'SELECT COUNT(*)::int AS total FROM ' + TABLE,
  CREATE:     'INSERT INTO ' + TABLE + ' (id, name, created_at, updated_at) VALUES (\$1, \$2, \$3, \$4) RETURNING *',
  UPDATE:     'UPDATE '     + TABLE + ' SET name = COALESCE(\$1, name), updated_at = \$2 WHERE id = \$3 RETURNING *',
  DELETE:     'DELETE FROM ' + TABLE + ' WHERE id = \$1',
};

module.exports = { QUERIES };
EOF

cat > "$DEST/repository/index.js" << EOF
'use strict';
module.exports = {
  QUERIES: require('./queries').QUERIES,
};
EOF

# ── service/<name>.service.js ────────────────────────────────
cat > "$DEST/service/${LOWER}.service.js" << EOF
'use strict';

const { ${PASCAL} } = require('../models');

class ${PASCAL}Service {
  /**
   * @param {import('../repository').${PASCAL}Repository} repository
   * @param {import('../../../app/dispatch').Dispatcher}  dispatcher
   */
  constructor(repository, dispatcher) {
    this._repo       = repository;
    this._dispatcher = dispatcher;
  }

  async create(dto) {
    const entity  = new ${PASCAL}(dto);
    const created = await this._repo.create(entity);
    await this._dispatcher.dispatch('${LOWER}.created', created.toResponse());
    return created.toResponse();
  }

  async getById(id) {
    const entity = await this._repo.findById(id);
    return entity.toResponse();
  }

  async list({ page = 1, limit = 20 } = {}) {
    const offset = (page - 1) * limit;
    const [items, total] = await Promise.all([
      this._repo.findAll({ limit, offset }),
      this._repo.count(),
    ]);
    return { items: items.map((e) => e.toResponse()), total, page, limit };
  }

  async update(id, dto) {
    const entity  = await this._repo.findById(id);
    entity.applyUpdate(dto);
    const updated = await this._repo.update(id, { name: entity.name });
    return updated.toResponse();
  }

  async delete(id) {
    await this._repo.delete(id);
    await this._dispatcher.dispatch('${LOWER}.deleted', { id });
  }
}

module.exports = { ${PASCAL}Service };
EOF

cat > "$DEST/service/index.js" << EOF
'use strict';
module.exports = require('./${LOWER}.service');
EOF

# ── controller/<name>.controller.js ─────────────────────────
# No container import — service is injected by the router factory.
cat > "$DEST/controller/${LOWER}.controller.js" << EOF
'use strict';

const { ok, created, noContent, paginated } = require('../../../http/response');

/**
 * Build a ${PASCAL} controller bound to the provided service.
 * The controller has zero knowledge of the DI container.
 *
 * @param {import('../service').${PASCAL}Service} ${LOWER}Service
 */
function makeController(${LOWER}Service) {
  async function create(req, res, next) {
    try {
      return created(res, await ${LOWER}Service.create(req.body));
    } catch (err) { next(err); }
  }

  async function getById(req, res, next) {
    try {
      return ok(res, await ${LOWER}Service.getById(req.params.id));
    } catch (err) { next(err); }
  }

  async function list(req, res, next) {
    try {
      const page  = Number(req.query.page  || 1);
      const limit = Number(req.query.limit || 20);
      return paginated(res, await ${LOWER}Service.list({ page, limit }));
    } catch (err) { next(err); }
  }

  async function update(req, res, next) {
    try {
      return ok(res, await ${LOWER}Service.update(req.params.id, req.body));
    } catch (err) { next(err); }
  }

  async function remove(req, res, next) {
    try {
      await ${LOWER}Service.delete(req.params.id);
      return noContent(res);
    } catch (err) { next(err); }
  }

  return { create, getById, list, update, remove };
}

module.exports = { makeController };
EOF

cat > "$DEST/controller/index.js" << EOF
'use strict';
module.exports = require('./${LOWER}.controller');
EOF

# ── middleware/<name>.middleware.js ──────────────────────────
cat > "$DEST/middleware/${LOWER}.middleware.js" << EOF
'use strict';

const { BaseMiddleware } = require('../../../http/middlewares/BaseMiddleware');
const { HttpError }      = require('../../../http/errors/httpError');

class ${PASCAL}Middleware extends BaseMiddleware {
  /**
   * Ensure the authenticated user owns the requested resource.
   * Default: compares req.params.id to req.auth.sub.
   * Override resolveOwnerId() for custom ownership logic.
   */
  requireOwner() {
    return BaseMiddleware.wrap(async (req, _res, next) => {
      if (req.params.id !== req.auth?.sub) {
        return next(new HttpError(403, 'Access denied'));
      }
      next();
    });
  }
}

/** Singleton instance for direct use in the router. */
const ${LOWER}Middleware = new ${PASCAL}Middleware();

module.exports = { ${PASCAL}Middleware, ${LOWER}Middleware };
EOF

cat > "$DEST/middleware/index.js" << EOF
'use strict';
module.exports = require('./${LOWER}.middleware');
EOF

# ── router/index.js ──────────────────────────────────────────
# Exports createRouter(service) — a factory, not a pre-wired instance.
# The composition root (bootstrap/router.js) calls it with the resolved service.
cat > "$DEST/router/index.js" << EOF
'use strict';

const { Router }           = require('express');
const { makeController }   = require('../controller');
const { validate }         = require('../DTO/validate');
const { authMiddleware }   = require('../../../http/middlewares');
const {
  Create${PASCAL}Dto,
  Update${PASCAL}Dto,
  ${PASCAL}ParamDto,
  ${PASCAL}ListQueryDto,
} = require('../DTO');

/**
 * Create the ${PASCAL} Express router.
 *
 * @param {import('../service').${PASCAL}Service} ${LOWER}Service
 * @returns {import('express').Router}
 */
function createRouter(${LOWER}Service) {
  const ctrl   = makeController(${LOWER}Service);
  const router = Router();

  // ── Public ───────────────────────────────────────────────────
  router.post('/',
    validate(Create${PASCAL}Dto, 'body'),
    ctrl.create);

  // ── Protected ────────────────────────────────────────────────
  router.use(authMiddleware);

  router.get('/',
    validate(${PASCAL}ListQueryDto, 'query'),
    ctrl.list);

  router.get('/:id',
    validate(${PASCAL}ParamDto, 'params'),
    ctrl.getById);

  router.patch('/:id',
    validate(${PASCAL}ParamDto, 'params'),
    validate(Update${PASCAL}Dto, 'body'),
    ctrl.update);

  router.delete('/:id',
    validate(${PASCAL}ParamDto, 'params'),
    ctrl.remove);

  return router;
}

module.exports = { createRouter };
EOF