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
  ${LOWER}Routes:      require('./router'),
};
EOF

# ── Auto-register in bootstrap/router.js ─────────────────────
IMPORT_LINE="const { ${LOWER}Routes } = require('../modules/${LOWER}');"
MOUNT_LINE="router.use('/v1/${ROUTE_PREFIX}', ${LOWER}Routes);"
REGISTER_COMMENT="// Register additional module routers here:"

if grep -qF "$IMPORT_LINE" "$ROUTER_FILE"; then
  echo "⚠   Route already registered in router.js — skipped."
else
  # Insert import after the last require line
  sed -i "s|const router = Router();|${IMPORT_LINE}\n\nconst router = Router();|" "$ROUTER_FILE"
  # Insert mount before the register comment (or at end before module.exports)
  if grep -qF "$REGISTER_COMMENT" "$ROUTER_FILE"; then
    sed -i "s|${REGISTER_COMMENT}|router.use('/v1/${ROUTE_PREFIX}', ${LOWER}Routes);\n\n${REGISTER_COMMENT}|" "$ROUTER_FILE"
  else
    sed -i "s|module.exports = router;|${MOUNT_LINE}\n\nmodule.exports = router;|" "$ROUTER_FILE"
  fi
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
# ── Auto-register in app/container/providers.js ─────────────
PROVIDERS_FILE="$SRC/app/container/providers.js"

if grep -qF "[AUTO-IMPORTS]" "$PROVIDERS_FILE" 2>/dev/null; then
  if grep -qF "${LOWER}Repository" "$PROVIDERS_FILE"; then
    echo "⚠   ${PASCAL} already registered in providers.js — skipped."
  else
    TMP_SCRIPT="$(mktemp)"
    cat > "$TMP_SCRIPT" << 'NODEJS'
const fs     = require('fs');
const file   = process.argv[2];
const lower  = process.argv[3];
const pascal = process.argv[4];

let src = fs.readFileSync(file, 'utf8');

const importLines =
  `const { ${pascal}Repository } = require('../../modules/${lower}/repository');\n` +
  `const { ${pascal}Service }    = require('../../modules/${lower}/service');\n`;

const repoLine =
  `  container.singleton(\n` +
  `    '${lower}Repository',\n` +
  `    (c) => new ${pascal}Repository(c.resolve('db')),\n` +
  `  );\n`;

const serviceLine =
  `  container.singleton(\n` +
  `    '${lower}Service',\n` +
  `    (c) => new ${pascal}Service(c.resolve('${lower}Repository'), c.resolve('dispatcher')),\n` +
  `  );\n`;

src = src.replace('// [AUTO-IMPORTS]', importLines + '// [AUTO-IMPORTS]');
src = src.replace('  // [AUTO-REPOS]',    repoLine    + '  // [AUTO-REPOS]');
src = src.replace('  // [AUTO-SERVICES]', serviceLine + '  // [AUTO-SERVICES]');

fs.writeFileSync(file, src, 'utf8');
NODEJS
    node "$TMP_SCRIPT" "$PROVIDERS_FILE" "$LOWER" "$PASCAL"
    rm -f "$TMP_SCRIPT"

    echo "✔   Registered ${LOWER}Repository + ${LOWER}Service in providers.js"
  fi
else
  echo "⚠   providers.js missing AUTO markers — add manually:"
  echo "      container.singleton('${LOWER}Repository', (c) => new ${PASCAL}Repository(c.resolve('db')));"
  echo "      container.singleton('${LOWER}Service',     (c) => new ${PASCAL}Service(c.resolve('${LOWER}Repository'), c.resolve('dispatcher')));"
fi

echo "   Next steps:"
echo "   1. Edit DTO fields   → src/modules/${LOWER}/DTO/create.dto.js"
echo "   2. Edit model fields → src/modules/${LOWER}/models/${LOWER}.model.js"
echo "   3. Edit SQL queries  → src/modules/${LOWER}/repository/queries.js"
echo ""

# ── DTO/create.dto.js ────────────────────────────────────────
cat > "$DEST/DTO/create.dto.js" << EOF
'use strict';

const { Type } = require('@sinclair/typebox');

/** Input schema for creating a ${PASCAL}. TODO: adjust fields. */
const Create${PASCAL}Dto = Type.Object({
  name: Type.String({ minLength: 1, maxLength: 255 }),
});

module.exports = { Create${PASCAL}Dto };
EOF

# ── DTO/update.dto.js ────────────────────────────────────────
cat > "$DEST/DTO/update.dto.js" << EOF
'use strict';

const { Type } = require('@sinclair/typebox');

/** Input schema for updating a ${PASCAL}. All fields optional. */
const Update${PASCAL}Dto = Type.Object({
  name: Type.Optional(Type.String({ minLength: 1, maxLength: 255 })),
});

module.exports = { Update${PASCAL}Dto };
EOF

# ── DTO/param.dto.js ─────────────────────────────────────────
cat > "$DEST/DTO/param.dto.js" << EOF
'use strict';

const { Type } = require('@sinclair/typebox');

const ${PASCAL}ParamDto = Type.Object({
  id: Type.String({ format: 'uuid' }),
});

module.exports = { ${PASCAL}ParamDto };
EOF

# ── DTO/query.dto.js ─────────────────────────────────────────
cat > "$DEST/DTO/query.dto.js" << EOF
'use strict';

const { Type } = require('@sinclair/typebox');

const ${PASCAL}ListQueryDto = Type.Object({
  page:  Type.Optional(Type.Integer({ minimum: 1, default: 1 })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100, default: 20 })),
});

module.exports = { ${PASCAL}ListQueryDto };
EOF

# ── DTO/validate.js (quoted: no var expansion needed) ────────
cat > "$DEST/DTO/validate.js" << 'EOF'
'use strict';

const { Value }       = require('@sinclair/typebox/value');
const { DomainError } = require('../../../shared/errors/domainError');

/**
 * Returns an Express middleware that validates req[source] against
 * a TypeBox schema. On success it coerces / defaults values in place.
 *
 * @param {import('@sinclair/typebox').TObject} schema
 * @param {'body'|'params'|'query'} [source='body']
 */
function validate(schema, source = 'body') {
  return (req, _res, next) => {
    const data = req[source] ?? {};
    if (!Value.Check(schema, data)) {
      const details = [...Value.Errors(schema, data)].map((e) => ({
        field:   e.path,
        message: e.message,
      }));
      return next(DomainError.validation('Validation failed', details));
    }
    req[source] = Value.Cast(schema, data);
    next();
  };
}

module.exports = { validate };
EOF

# ── DTO/index.js ─────────────────────────────────────────────
cat > "$DEST/DTO/index.js" << EOF
'use strict';

module.exports = {
  ...require('./create.dto'),
  ...require('./update.dto'),
  ...require('./param.dto'),
  ...require('./query.dto'),
  validate: require('./validate').validate,
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

# ── repository/<name>.repository.js ─────────────────────────
cat > "$DEST/repository/${LOWER}.repository.js" << EOF
'use strict';

const { ${PASCAL} }   = require('../models');
const { QUERIES }     = require('./queries');
const { DomainError } = require('../../../shared/errors/domainError');
const { now }         = require('../../../shared/utils/time');

class ${PASCAL}Repository {
  /** @param {{ query: Function }} db  pg pool wrapper */
  constructor(db) {
    this._db = db;
  }

  async findById(id) {
    const res = await this._db.query(QUERIES.FIND_BY_ID, [id]);
    if (!res.rows.length) throw DomainError.notFound('${PASCAL} not found');
    return ${PASCAL}.fromRecord(res.rows[0]);
  }

  async findAll({ limit, offset }) {
    const res = await this._db.query(QUERIES.FIND_ALL, [limit, offset]);
    return res.rows.map((r) => ${PASCAL}.fromRecord(r));
  }

  async count() {
    const res = await this._db.query(QUERIES.COUNT);
    return res.rows[0].total;
  }

  async create(entity) {
    const r   = entity.toRecord();
    const res = await this._db.query(QUERIES.CREATE, [r.id, r.name, r.created_at, r.updated_at]);
    return ${PASCAL}.fromRecord(res.rows[0]);
  }

  async update(id, { name = null }) {
    const res = await this._db.query(QUERIES.UPDATE, [name, now(), id]);
    if (!res.rows.length) throw DomainError.notFound('${PASCAL} not found');
    return ${PASCAL}.fromRecord(res.rows[0]);
  }

  async delete(id) {
    await this._db.query(QUERIES.DELETE, [id]);
  }
}

module.exports = { ${PASCAL}Repository };
EOF

cat > "$DEST/repository/index.js" << EOF
'use strict';
module.exports = {
  ...require('./${LOWER}.repository'),
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
cat > "$DEST/controller/${LOWER}.controller.js" << EOF
'use strict';

const { ok, created, noContent, paginated } = require('../../../http/response');
const { container } = require('../../../app/container');

function getService() {
  return container.resolve('${LOWER}Service');
}

async function create(req, res, next) {
  try {
    return created(res, await getService().create(req.body));
  } catch (err) { next(err); }
}

async function getById(req, res, next) {
  try {
    return ok(res, await getService().getById(req.params.id));
  } catch (err) { next(err); }
}

async function list(req, res, next) {
  try {
    const page  = Number(req.query.page  || 1);
    const limit = Number(req.query.limit || 20);
    return paginated(res, await getService().list({ page, limit }));
  } catch (err) { next(err); }
}

async function update(req, res, next) {
  try {
    return ok(res, await getService().update(req.params.id, req.body));
  } catch (err) { next(err); }
}

async function remove(req, res, next) {
  try {
    await getService().delete(req.params.id);
    return noContent(res);
  } catch (err) { next(err); }
}

module.exports = { create, getById, list, update, remove };
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
cat > "$DEST/router/index.js" << EOF
'use strict';

const { Router }         = require('express');
const ctrl               = require('../controller');
const { validate }       = require('../DTO/validate');
const { authMiddleware } = require('../../../http/middlewares');
const {
  Create${PASCAL}Dto,
  Update${PASCAL}Dto,
  ${PASCAL}ParamDto,
  ${PASCAL}ListQueryDto,
} = require('../DTO');

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

module.exports = router;
EOF

