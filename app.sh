#!/bin/bash

# 1. دریافت نام پروژه
PROJECT_NAME=$1

if [ -z "$PROJECT_NAME" ]; then
  echo "❌ Error: Project name is required."
  echo "Usage: ./app.sh <project-name>"
  exit 1
fi

echo "🚀 Building Express Architecture: $PROJECT_NAME..."

mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# ---------------------------------------------------------
# 2. فایل package.json
# ---------------------------------------------------------
echo "📦 Creating package.json..."
cat <<EOF > package.json
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "Modular Express App with Clean Architecture",
  "main": "src/bootstrap/server.js",
  "scripts": {
    "start": "node src/bootstrap/server.js",
    "dev": "nodemon src/bootstrap/server.js",
    "generate:module": "./module.sh"
  },
  "dependencies": {
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "redis": "^4.6.0",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "joi": "^17.10.1",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

# ---------------------------------------------------------
# 3. ساختار پوشه‌ها
# ---------------------------------------------------------
echo "📂 Creating directories..."
mkdir -p src/bootstrap
mkdir -p src/http
mkdir -p src/app
mkdir -p src/config
mkdir -p src/infrastructure/db/postgres
mkdir -p src/infrastructure/db/redis
mkdir -p src/infrastructure/queue
mkdir -p src/infrastructure/dispatch
mkdir -p src/modules/users
mkdir -p src/modules/auth
mkdir -p src/modules/health
mkdir -p src/shared

echo "⚙️ Config files..."
cat <<EOF > .gitignore
node_modules
.env
.DS_Store
*.log
EOF

cat <<EOF > .env
# Server
PORT=3000
NODE_ENV=development

# PostgreSQL
PG_HOST=localhost
PG_PORT=5432
PG_DATABASE=$PROJECT_NAME
PG_USER=postgres
PG_PASSWORD=postgres
PG_POOL_MAX=20
PG_POOL_IDLE_TIMEOUT=30000
PG_POOL_CONNECTION_TIMEOUT=2000
PG_STATEMENT_TIMEOUT=30000
PG_SLOW_QUERY_THRESHOLD=1000

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# JWT
JWT_SECRET=change_me_please_very_secure_key
JWT_EXPIRES_IN=7d

# Other
API_PREFIX=/api/v1
EOF

# ---------------------------------------------------------
# 4. Config - PostgreSQL
# ---------------------------------------------------------
echo "⚙️ Creating config/pg.config.js..."
cat <<EOF > src/config/pg.config.js
require('dotenv').config();

module.exports = {
  connection: {
    host:     process.env.PG_HOST     || 'localhost',
    port:     parseInt(process.env.PG_PORT) || 5432,
    database: process.env.PG_DATABASE || 'mydb',
    user:     process.env.PG_USER     || 'postgres',
    password: process.env.PG_PASSWORD || 'postgres',
  },
  pool: {
    max:               parseInt(process.env.PG_POOL_MAX)                || 20,
    idleTimeoutMillis: parseInt(process.env.PG_POOL_IDLE_TIMEOUT)       || 30000,
    connectionTimeoutMillis: parseInt(process.env.PG_POOL_CONNECTION_TIMEOUT) || 2000,
  },
  query: {
    statement_timeout:  parseInt(process.env.PG_STATEMENT_TIMEOUT)      || 30000,
    slowQueryThreshold: parseInt(process.env.PG_SLOW_QUERY_THRESHOLD)   || 1000,
  },
};
EOF

# ---------------------------------------------------------
# 5. Infrastructure - Env
# ---------------------------------------------------------
echo "⚙️ Creating infrastructure/env.js..."
cat <<EOF > src/infrastructure/env.js
require('dotenv').config();

module.exports = {
  server: {
    port: process.env.PORT || 3000,
    env: process.env.NODE_ENV || 'development',
    apiPrefix: process.env.API_PREFIX || '/api/v1'
  },
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '7d'
  }
};
EOF

# ---------------------------------------------------------
# 6. Infrastructure - Config (placeholder)
# ---------------------------------------------------------
touch src/infrastructure/config.js

# ---------------------------------------------------------
# 7. Infrastructure - Logger
# ---------------------------------------------------------
echo "📋 Creating infrastructure/logger.js..."
cat <<EOF > src/infrastructure/logger.js
const morgan = require('morgan');

const logger = morgan(':method :url :status :res[content-length] - :response-time ms');

module.exports = logger;
EOF

# ---------------------------------------------------------
# 8. Infrastructure - DB - PostgreSQL errors
# ---------------------------------------------------------
echo "🔌 Creating infrastructure/db/postgres/errors.js..."
cat <<EOF > src/infrastructure/db/postgres/errors.js
class DatabaseError extends Error {
  constructor(message, code, original) {
    super(message);
    this.name = 'DatabaseError';
    this.code = code;
    this.original = original;
  }
}

class ConnectionError extends Error {
  constructor(message, original) {
    super(message);
    this.name = 'ConnectionError';
    this.original = original;
  }
}

class QueryError extends Error {
  constructor(message, code, original) {
    super(message);
    this.name = 'QueryError';
    this.code = code;
    this.original = original;
  }
}

class UniqueViolationError extends DatabaseError {
  constructor(message, original) {
    super(message, '23505', original);
    this.name = 'UniqueViolationError';
  }
}

class ForeignKeyViolationError extends DatabaseError {
  constructor(message, original) {
    super(message, '23503', original);
    this.name = 'ForeignKeyViolationError';
  }
}

class NotNullViolationError extends DatabaseError {
  constructor(message, original) {
    super(message, '23502', original);
    this.name = 'NotNullViolationError';
  }
}

/**
 * Normalize raw pg errors into structured domain errors
 * @param {Error} error - Raw pg error
 * @returns {DatabaseError|QueryError|ConnectionError|Error}
 */
const normalizeError = (error) => {
  switch (error.code) {
    case '23505':
      return new UniqueViolationError(
        \`Unique constraint violated: \${error.detail || error.message}\`,
        error
      );
    case '23503':
      return new ForeignKeyViolationError(
        \`Foreign key constraint violated: \${error.detail || error.message}\`,
        error
      );
    case '23502':
      return new NotNullViolationError(
        \`Not null constraint violated: \${error.detail || error.message}\`,
        error
      );
    case 'ECONNREFUSED':
    case '08006':
    case '08001':
    case '08004':
      return new ConnectionError(
        \`Database connection failed: \${error.message}\`,
        error
      );
    case '42601':
      return new QueryError(
        \`SQL syntax error: \${error.message}\`,
        error.code,
        error
      );
    case '42703':
      return new QueryError(
        \`Column does not exist: \${error.message}\`,
        error.code,
        error
      );
    case '42P01':
      return new QueryError(
        \`Table does not exist: \${error.message}\`,
        error.code,
        error
      );
    default:
      return new DatabaseError(
        error.message || 'Unknown database error',
        error.code,
        error
      );
  }
};

module.exports = {
  normalizeError,
  DatabaseError,
  ConnectionError,
  QueryError,
  UniqueViolationError,
  ForeignKeyViolationError,
  NotNullViolationError,
};
EOF

# ---------------------------------------------------------
# 9. Infrastructure - DB - PostgreSQL pg.js
# ---------------------------------------------------------
echo "🔌 Creating infrastructure/db/postgres/pg.js..."
cat <<'EOF' > src/infrastructure/db/postgres/pg.js
/**
 * High-Performance PostgreSQL Database Wrapper
 * Simple API: db.execute() and db.Transaction()
 */

const { Pool } = require("pg");
const pgConfig = require("../../../config/pg.config");
const { normalizeError } = require("./errors");

class Database {
  constructor() {
    this.pool = null;
  }

  async init() {
    if (this.pool) return this.pool;

    try {
      this.pool = new Pool({
        ...pgConfig.connection,
        ...pgConfig.pool,
      });

      this.pool.on("connect", (client) => {
        client.query(
          `SET statement_timeout = ${pgConfig.query.statement_timeout}`,
        );
      });

      this.pool.on("error", (err) => {
        console.error("💥 Unexpected database pool error:", err);
      });

      const client = await this.pool.connect();
      try {
        await client.query("SELECT NOW()");
        console.log("✅ PostgreSQL Pool Connected");
      } finally {
        client.release();
      }

      return this.pool;
    } catch (error) {
      console.error("❌ PostgreSQL Pool Connection Error:", error.message);
      throw normalizeError(error);
    }
  }

  async close() {
    if (this.pool) {
      await this.pool.end();
      this.pool = null;
      console.log("✅ PostgreSQL Pool Closed");
    }
  }

  ensurePool() {
    if (!this.pool) {
      throw new Error("Database pool not initialized. Call db.init() first.");
    }
  }

  /**
   * Build query object
   * @param {string} sql - SQL query template
   * @param  {...any} params - Query parameters
   * @returns {Object} Query object { text, values }
   */
  Transaction(sql, ...params) {
    return {
      text: sql,
      values:
        params.length === 1 && Array.isArray(params[0]) ? params[0] : params,
    };
  }

  /**
   * Execute simple query (for SELECT)
   * @param {Object|string} query - Query object or SQL string
   * @param {Array} args - Query arguments (if query is string)
   * @returns {Promise<Array>} Query results
   */
  async execute(query, args = []) {
    this.ensurePool();

    const sql = typeof query === "string" ? query : query.text;
    const values = typeof query === "string" ? args : query.values;

    const startTime = Date.now();

    try {
      const result = await this.pool.query(sql, values);
      const executionTime = Date.now() - startTime;

      if (executionTime > pgConfig.query.slowQueryThreshold) {
        console.warn(`🐌 Slow Query Detected (${executionTime}ms):`, {
          query: sql.substring(0, 100),
          executionTime,
          rowCount: result.rowCount,
        });
      }

      return result.rows || [];
    } catch (error) {
      const executionTime = Date.now() - startTime;

      console.error("💥 Query Execution Error:", {
        error: error.message,
        query: sql.substring(0, 100),
        executionTime,
        code: error.code,
      });

      throw normalizeError(error);
    }
  }

  /**
   * Execute transaction for complex operations with multiple queries
   * @param {Function} callback - Callback receives executeInTx(queryObj)
   * @returns {Promise<any>} Transaction result
   *
   * @example
   * await db.executeTransaction(async (executeInTx) => {
   *   const user = await executeInTx(db.Transaction(qry.findUser, userId));
   *   if (user.length === 0) throw new Error('Not found');
   *
   *   await executeInTx(db.Transaction(qry.updateBalance, userId, newBalance));
   *   await executeInTx(db.Transaction(qry.insertLog, userId, 'update'));
   *   return user[0];
   * });
   */
  async executeTransaction(callback) {
    this.ensurePool();

    const client = await this.pool.connect();
    let hasError = false;

    try {
      await client.query(
        `SET statement_timeout = ${pgConfig.query.statement_timeout}`,
      );
      await client.query("BEGIN");

      const executeInTx = async (queryObj) => {
        const sql = typeof queryObj === "string" ? queryObj : queryObj.text;
        const values = typeof queryObj === "string" ? [] : queryObj.values;

        const startTime = Date.now();

        try {
          const result = await client.query(sql, values);
          const executionTime = Date.now() - startTime;

          if (executionTime > pgConfig.query.slowQueryThreshold) {
            console.warn(`🐌 Slow Query in TX (${executionTime}ms):`, {
              query: sql.substring(0, 100),
              executionTime,
              rowCount: result.rowCount,
            });
          }

          return result.rows || [];
        } catch (error) {
          const executionTime = Date.now() - startTime;

          console.error("💥 TX Query Error:", {
            error: error.message,
            query: sql.substring(0, 100),
            executionTime,
            code: error.code,
          });

          throw normalizeError(error);
        }
      };

      const result = await callback(executeInTx);
      await client.query("COMMIT");

      return result;
    } catch (error) {
      hasError = true;

      try {
        await client.query("ROLLBACK");
      } catch (rollbackError) {
        console.error("💥 ROLLBACK failed:", rollbackError.message);
      }

      if (error.name && error.name.endsWith("Error") && error.code) {
        throw error;
      }
      throw normalizeError(error);
    } finally {
      client.release(hasError);
    }
  }
}

module.exports = new Database();
EOF

# ---------------------------------------------------------
# 10. Infrastructure - DB - Redis
# ---------------------------------------------------------
echo "🔌 Creating infrastructure/db/redis/client.js..."
cat <<EOF > src/infrastructure/db/redis/client.js
const redis = require('redis');

let client = null;

const connectRedis = async () => {
  try {
    client = redis.createClient({
      socket: {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT) || 6379,
      }
    });

    client.on('error',     (err) => console.error('❌ Redis Error:', err));
    client.on('connect',   ()    => console.log('✅ Redis Connected'));
    client.on('reconnecting', () => console.warn('⚠️  Redis Reconnecting...'));

    await client.connect();
    return client;
  } catch (error) {
    console.error('❌ Redis Connection Error:', error.message);
    throw error;
  }
};

const getClient = () => {
  if (!client) {
    throw new Error('Redis client not initialized. Call connectRedis() first.');
  }
  return client;
};

const closeRedis = async () => {
  if (client) {
    await client.quit();
    client = null;
    console.log('✅ Redis Connection Closed');
  }
};

module.exports = { connectRedis, getClient, closeRedis };
EOF

# ---------------------------------------------------------
# 11. Infrastructure - Queue
# ---------------------------------------------------------
echo "📨 Creating infrastructure/queue..."
touch src/infrastructure/queue/client.js
touch src/infrastructure/queue/producer.js
touch src/infrastructure/queue/consumer.js

# ---------------------------------------------------------
# 12. Infrastructure - Dispatch
# ---------------------------------------------------------
echo "📡 Creating infrastructure/dispatch..."
touch src/infrastructure/dispatch/bus.js
touch src/infrastructure/dispatch/registry.js

# ---------------------------------------------------------
# 13. HTTP Layer
# ---------------------------------------------------------
echo "🛡️ Creating http layer..."

cat <<EOF > src/http/middlewares.js
const jwt = require('jsonwebtoken');
const config = require('../infrastructure/env');

class Middlewares {
  auth(req, res, next) {
    try {
      const token = req.headers.authorization?.split(' ')[1];

      if (!token) {
        return res.status(401).json({
          success: false,
          message: 'Authentication required'
        });
      }

      const decoded = jwt.verify(token, config.jwt.secret);
      req.user = decoded;
      next();
    } catch (error) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }
  }

  validate(schema) {
    return (req, res, next) => {
      const { error } = schema.validate(req.body, { abortEarly: false });

      if (error) {
        return res.status(400).json({
          success: false,
          message: 'Validation error',
          errors: error.details.map(d => d.message)
        });
      }

      next();
    };
  }

  errorHandler(err, req, res, next) {
    console.error('💥 Error:', err);

    const statusCode = err.statusCode || 500;
    const message = err.message || 'Internal Server Error';

    res.status(statusCode).json({
      success: false,
      error: {
        message,
        ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
      }
    });
  }

  notFound(req, res) {
    res.status(404).json({
      success: false,
      message: 'Route not found'
    });
  }
}

module.exports = new Middlewares();
EOF

touch src/http/errors.js
touch src/http/response.js

# ---------------------------------------------------------
# 14. App Layer
# ---------------------------------------------------------
echo "🧩 Creating app layer..."
touch src/app/config.js
touch src/app/dispatch.js
touch src/app/container.js

# ---------------------------------------------------------
# 15. Shared
# ---------------------------------------------------------
echo "🛠️ Creating shared utilities..."

cat <<EOF > src/shared/utils.js
class ApiResponse {
  static success(res, data, message = 'Success', statusCode = 200) {
    return res.status(statusCode).json({
      success: true,
      message,
      data
    });
  }

  static error(res, message = 'Error', statusCode = 500) {
    return res.status(statusCode).json({
      success: false,
      message
    });
  }

  static created(res, data, message = 'Created') {
    return this.success(res, data, message, 201);
  }
}

module.exports = ApiResponse;
EOF

cat <<EOF > src/shared/time.js
const formatDate = (date) => {
  return new Date(date).toISOString();
};

const addDays = (date, days) => {
  const result = new Date(date);
  result.setDate(result.getDate() + days);
  return result;
};

module.exports = { formatDate, addDays };
EOF

touch src/shared/validate.js
touch src/shared/id.js
touch src/shared/errors.js

# ---------------------------------------------------------
# 16. Modules (single-file class-based)
# ---------------------------------------------------------
echo "📦 Creating module stubs..."
touch src/modules/users/users.module.js
touch src/modules/auth/auth.module.js
touch src/modules/health/health.module.js

# ---------------------------------------------------------
# 17. Bootstrap - Router
# ---------------------------------------------------------
echo "🌟 Creating bootstrap/router.js..."
cat <<EOF > src/bootstrap/router.js
const express = require('express');
const router = express.Router();

// Mount module routers here
// Example:
// const UsersModule = require('../modules/users/users.module');
// router.use('/users', new UsersModule().router);

router.get('/health', (req, res) => {
  res.json({ success: true, message: 'API is running' });
});

module.exports = router;
EOF

# ---------------------------------------------------------
# 18. Bootstrap - App.js
# ---------------------------------------------------------
echo "🔌 Creating bootstrap/app.js..."
cat <<EOF > src/bootstrap/app.js
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const config = require('../infrastructure/env');
const logger = require('../infrastructure/logger');
const middlewares = require('../http/middlewares');
const router = require('./router');

const app = express();

// Security & Parsing
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Logging
if (config.server.env === 'development') {
  app.use(logger);
}

// API Routes
app.use(config.server.apiPrefix, router);

// Error Handling
app.use(middlewares.notFound);
app.use(middlewares.errorHandler);

module.exports = app;
EOF

# ---------------------------------------------------------
# 19. Bootstrap - Server.js
# ---------------------------------------------------------
echo "🚀 Creating bootstrap/server.js..."
cat <<EOF > src/bootstrap/server.js
const app = require('./app');
const config = require('../infrastructure/env');
const db = require('../infrastructure/db/postgres/pg');
const { connectRedis } = require('../infrastructure/db/redis/client');

const startServer = async () => {
  try {
    // Connect to PostgreSQL
    await db.init();

    // Connect to Redis (Optional)
    try {
      await connectRedis();
    } catch (error) {
      console.warn('⚠️  Redis not connected, continuing without cache...');
    }

    // Start Server
    const PORT = config.server.port;
    app.listen(PORT, () => {
      console.log(\`🚀 Server running on port \${PORT}\`);
      console.log(\`📡 Environment: \${config.server.env}\`);
      console.log(\`🔗 API Base: \${config.server.apiPrefix}\`);
    });

  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
};

process.on('unhandledRejection', (err) => {
  console.error('💥 Unhandled Rejection:', err);
  process.exit(1);
});

startServer();
EOF

# =========================================================
# 20. تولید فایل module.sh
# =========================================================
echo "🔨 Creating module.sh tool..."

cat <<'MAKER_EOF' > module.sh
#!/bin/bash
MODULE_NAME=$1

if [ -z "$MODULE_NAME" ]; then
  echo "❌ Usage: ./module.sh <module_name>"
  echo "Example: ./module.sh users"
  exit 1
fi

CAP_NAME="$(tr '[:lower:]' '[:upper:]' <<< ${MODULE_NAME:0:1})${MODULE_NAME:1}"
DIR="src/modules/$MODULE_NAME"

if [ -d "$DIR" ]; then
  echo "❌ Module '$MODULE_NAME' already exists!"
  exit 1
fi

mkdir -p "$DIR"
echo "🚀 Creating module: $MODULE_NAME..."

cat <<EOD > "$DIR/$MODULE_NAME.module.js"
const express = require('express');
const ApiResponse = require('../../shared/utils');
const middlewares = require('../../http/middlewares');
const db = require('../../infrastructure/db/postgres/pg');

// ── Queries ──────────────────────────────────────────────
const qry = {
  findAll:  'SELECT * FROM ${MODULE_NAME}s ORDER BY created_at DESC LIMIT \$1 OFFSET \$2',
  findById: 'SELECT * FROM ${MODULE_NAME}s WHERE id = \$1',
  create:   'INSERT INTO ${MODULE_NAME}s (title, description) VALUES (\$1, \$2) RETURNING *',
  update:   'UPDATE ${MODULE_NAME}s SET title = \$1, description = \$2 WHERE id = \$3 RETURNING *',
  delete:   'DELETE FROM ${MODULE_NAME}s WHERE id = \$1 RETURNING id',
};

// ── Repository ───────────────────────────────────────────
class ${CAP_NAME}Repository {
  async findAll(limit = 10, offset = 0) {
    return await db.execute(qry.findAll, [limit, offset]);
  }

  async findById(id) {
    const rows = await db.execute(qry.findById, [id]);
    return rows[0] || null;
  }

  async create(data) {
    const rows = await db.execute(qry.create, [data.title, data.description]);
    return rows[0];
  }

  async update(id, data) {
    const rows = await db.execute(qry.update, [data.title, data.description, id]);
    return rows[0] || null;
  }

  async delete(id) {
    const rows = await db.execute(qry.delete, [id]);
    return rows[0] || null;
  }
}

// ── Service ──────────────────────────────────────────────
class ${CAP_NAME}Service {
  constructor() {
    this.repo = new ${CAP_NAME}Repository();
  }

  async getAll(page = 1, limit = 10) {
    const offset = (page - 1) * limit;
    return await this.repo.findAll(limit, offset);
  }

  async getById(id) {
    const item = await this.repo.findById(id);
    if (!item) {
      const error = new Error('${CAP_NAME} not found');
      error.statusCode = 404;
      throw error;
    }
    return item;
  }

  async create(data) {
    return await this.repo.create(data);
  }

  async update(id, data) {
    const item = await this.repo.update(id, data);
    if (!item) {
      const error = new Error('${CAP_NAME} not found');
      error.statusCode = 404;
      throw error;
    }
    return item;
  }

  async delete(id) {
    const item = await this.repo.delete(id);
    if (!item) {
      const error = new Error('${CAP_NAME} not found');
      error.statusCode = 404;
      throw error;
    }
    return item;
  }
}

// ── Controller ───────────────────────────────────────────
class ${CAP_NAME}Controller {
  constructor() {
    this.service = new ${CAP_NAME}Service();
  }

  async getAll(req, res, next) {
    try {
      const page  = parseInt(req.query.page)  || 1;
      const limit = parseInt(req.query.limit) || 10;
      const data = await this.service.getAll(page, limit);
      ApiResponse.success(res, data);
    } catch (error) { next(error); }
  }

  async getById(req, res, next) {
    try {
      const data = await this.service.getById(req.params.id);
      ApiResponse.success(res, data);
    } catch (error) { next(error); }
  }

  async create(req, res, next) {
    try {
      const data = await this.service.create(req.body);
      ApiResponse.created(res, data, '${CAP_NAME} created successfully');
    } catch (error) { next(error); }
  }

  async update(req, res, next) {
    try {
      const data = await this.service.update(req.params.id, req.body);
      ApiResponse.success(res, data, '${CAP_NAME} updated successfully');
    } catch (error) { next(error); }
  }

  async delete(req, res, next) {
    try {
      await this.service.delete(req.params.id);
      ApiResponse.success(res, null, '${CAP_NAME} deleted successfully');
    } catch (error) { next(error); }
  }
}

// ── Module ───────────────────────────────────────────────
class ${CAP_NAME}Module {
  constructor() {
    this.controller = new ${CAP_NAME}Controller();
    this.router = express.Router();
    this._registerRoutes();
  }

  _registerRoutes() {
    const c = this.controller;

    this.router.get('/',       (req, res, next) => c.getAll(req, res, next));
    this.router.get('/:id',    (req, res, next) => c.getById(req, res, next));
    this.router.post('/',      middlewares.auth, (req, res, next) => c.create(req, res, next));
    this.router.put('/:id',    middlewares.auth, (req, res, next) => c.update(req, res, next));
    this.router.delete('/:id', middlewares.auth, (req, res, next) => c.delete(req, res, next));
  }
}

module.exports = ${CAP_NAME}Module;
EOD

echo ""
echo "✅ Module '$MODULE_NAME' created successfully!"
echo ""
echo "📁 Generated files:"
echo "   src/modules/${MODULE_NAME}/"
echo "   └── ${MODULE_NAME}.module.js"
echo ""
echo "📝 Next steps:"
echo "   Add to src/bootstrap/router.js:"
echo "      const ${CAP_NAME}Module = require('../modules/${MODULE_NAME}/${MODULE_NAME}.module');"
echo "      router.use('/${MODULE_NAME}', new ${CAP_NAME}Module().router);"
echo ""
echo "   Endpoints:"
echo "      GET    /api/v1/${MODULE_NAME}"
echo "      GET    /api/v1/${MODULE_NAME}/:id"
echo "      POST   /api/v1/${MODULE_NAME}"
echo "      PUT    /api/v1/${MODULE_NAME}/:id"
echo "      DELETE /api/v1/${MODULE_NAME}/:id"
echo ""
MAKER_EOF

chmod +x module.sh

# ---------------------------------------------------------
# 21. نصب پکیج‌ها
# ---------------------------------------------------------
echo ""
echo "📥 Installing dependencies..."
npm install

echo ""
echo "✅✅✅ Project Ready! ✅✅✅"
echo ""
echo "📁 Structure:"
echo "   ├── .gitignore"
echo "   ├── module.sh"
echo "   └── src/"
echo "       ├── bootstrap/        🚀 app.js · server.js · router.js"
echo "       ├── http/             🌐 middlewares.js · errors.js · response.js"
echo "       ├── app/              🧩 config.js · dispatch.js · container.js"
echo "       ├── config/           ⚙️  pg.config.js"
echo "       ├── infrastructure/   🏗️  env · logger"
echo "       │   └── db/"
echo "       │       ├── postgres/ 🐘 pg.js · errors.js"
echo "       │       └── redis/    🔴 client.js"
echo "       ├── modules/          📦 users · auth · health"
echo "       └── shared/           🛠️  utils · validate · id · time · errors"
echo ""
echo "🚀 Quick Start:"
echo "   cd $PROJECT_NAME"
echo "   npm run dev"
echo ""
echo "📦 Create Module:"
echo "   ./module.sh products"
echo ""