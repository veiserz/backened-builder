#!/bin/bash
MODULE_NAME=$1

if [ -z "$MODULE_NAME" ]; then
  echo "❌ Usage: ./module.sh <module_name>"
  echo "Example: ./module.sh users"
  exit 1
fi

# Capitalize first letter (user -> User)
CAP_NAME="$(tr '[:lower:]' '[:upper:]' <<< ${MODULE_NAME:0:1})${MODULE_NAME:1}"
DIR="src/modules/$MODULE_NAME"

if [ -d "$DIR" ]; then 
  echo "❌ Module '$MODULE_NAME' already exists!"
  exit 1
fi

mkdir -p "$DIR/middlewares"
echo "🚀 Creating module: $MODULE_NAME..."

# 1. DTO (Data Transfer Object / Validation)
cat <<EOD > "$DIR/$MODULE_NAME.dto.js"
const { Type } = require("@sinclair/typebox");

const DTO = {
  create: Type.Object({
    title: Type.String({ minLength: 3, maxLength: 100 }),
    description: Type.Optional(Type.String({ maxLength: 500 })),
    isActive: Type.Optional(Type.Boolean()),
  }),

  update: Type.Object({
    title: Type.Optional(Type.String({ minLength: 3, maxLength: 100 })),
    description: Type.Optional(Type.String({ maxLength: 500 })),
    isActive: Type.Optional(Type.Boolean()),
  }),
};

module.exports = DTO;
EOD

# 2. Repository (Database Access Layer)
cat <<EOD > "$DIR/$MODULE_NAME.repository.js"
const qry = {
  findAll: `SELECT * FROM auths ORDER BY created_at DESC LIMIT $1 OFFSET $2`,
  findById: `SELECT * FROM auths WHERE id = $1`,
  create: `INSERT INTO auths (title, description, status) VALUES ($1, $2, $3) RETURNING *`,
  update: `UPDATE auths SET title = $1, description = $2, status = $3, updated_at = NOW() WHERE id = $4 RETURNING *`,
  delete: `DELETE FROM auths WHERE id = $1 RETURNING *`,
  exists: `SELECT EXISTS(SELECT 1 FROM auths WHERE title = $1)`,
  count: `SELECT COUNT(*) as total FROM auths`,
};

module.exports = qry;

EOD

# 3. Service (Business Logic)
cat <<EOD > "$DIR/$MODULE_NAME.service.js"
const qry = require('./${MODULE_NAME}.repository');
const pg = require('../../common/database/pg');

class Service {
  constructor() {
    this.db = pg;
  }

  async getAll(filters = {}, options = {}) {
    const query = this.db.transactions(qry.findAll, filters, options);
    return await this.db.execute(query);
  }

  async getById(id) {
    const query = this.db.findById(qry.findById, id);
    const result = await this.db.execute(query);

    if (!result || result.length === 0) {
      const error = new Error('${CAP_NAME} not found');
      error.statusCode = 404;
      throw error;
    }
    return result[0];
  }

  async create(data) {
    // Check duplicates
    const existsQuery = this.db.findById(qry.exists, data.title);
    const exists = await this.db.execute(existsQuery);

    if (exists && exists.length > 0) {
      const error = new Error('${CAP_NAME} with this title already exists');
      error.statusCode = 409;
      throw error;
    }

    const createQuery = this.db.create(qry.create, data);
    const result = await this.db.execute(createQuery);
    return result[0];
  }

  async update(id, data) {
    const query = this.db.update(qry.update, id, data);
    const result = await this.db.execute(query);

    if (!result || result.length === 0) {
      const error = new Error('${CAP_NAME} not found');
      error.statusCode = 404;
      throw error;
    }
    return result[0];
  }

  async delete(id) {
    const query = this.db.delete(qry.delete, id);
    const result = await this.db.execute(query);

    if (!result || result.length === 0) {
      const error = new Error('${CAP_NAME} not found');
      error.statusCode = 404;
      throw error;
    }
    return result[0];
  }
}

module.exports = new Service();
EOD

# 4. Controller
cat <<EOD > "$DIR/$MODULE_NAME.controller.js"
const ${MODULE_NAME}Service = require('./${MODULE_NAME}.service');
const ApiResponse = require('../../common/utils/response');

class Controller {
  async getAll(req, res, next) {
    try {
      const filters = req.query.filters || {};
      const options = {
        page: parseInt(req.query.page) || 1,
        limit: parseInt(req.query.limit) || 10,
        sort: req.query.sort || '-createdAt'
      };

      const result = await ${MODULE_NAME}Service.getAll(filters, options);
      ApiResponse.success(res, result);
    } catch (error) {
      next(error);
    }
  }

  async getById(req, res, next) {
    try {
      const data = await ${MODULE_NAME}Service.getById(req.params.id);
      ApiResponse.success(res, data);
    } catch (error) {
      next(error);
    }
  }

  async create(req, res, next) {
    try {
      const data = await ${MODULE_NAME}Service.create(req.body);
      ApiResponse.created(res, data, '${CAP_NAME} created successfully');
    } catch (error) {
      next(error);
    }
  }

  async update(req, res, next) {
    try {
      const data = await ${MODULE_NAME}Service.update(req.params.id, req.body);
      ApiResponse.success(res, data, '${CAP_NAME} updated successfully');
    } catch (error) {
      next(error);
    }
  }

  async delete(req, res, next) {
    try {
      await ${MODULE_NAME}Service.delete(req.params.id);
      ApiResponse.success(res, null, '${CAP_NAME} deleted successfully');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new Controller();
EOD

# 5. Middleware (Module-specific)
cat <<EOD > "$DIR/${MODULE_NAME}.middleware.js"
const ${MODULE_NAME}Repository = require('../${MODULE_NAME}.repository');
const CommonMiddleware = require('../../common/middlewares/common.middleware');

class ${MODULE_NAME}Middleware extends CommonMiddleware {
  constructor() {
    super();
    this.repository = AuthRepository;
  }

  async checkAuthExists(req, res, next) {
    try {
      const id = req.params.id;
      const exists = await this.repository.exists({ _id: id });

      if (!exists) {
        return res.status(404).json({
          success: false,
          message: "Auth not found",
        });
      }

      next();
    } catch (error) {
      next(error);
    }
  }

  async checkOwnership(req, res, next) {
    try {
      const item = await this.repository.findById(req.params.id);
      next();
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ${MODULE_NAME}Middleware();
EOD

# 6. Routes
cat <<EOD > "$DIR/$MODULE_NAME.routes.js"
const express = require('express');
const controller = require('./${MODULE_NAME}.controller');
const Middleware = require('./middlewares/${MODULE_NAME}.middleware');
const dto = require('./${MODULE_NAME}.dto');

class ${MODULE_NAME} {
  constructor() {
    this.router = express.Router();
    this.controller = new ${MODULE_NAME}Controller();
    this.middleware = new ${MODULE_NAME}Middleware(); // فقط یک middleware
    this.initializeRoutes();
  }

  initializeRoutes() {
    // Get all auths
    this.router.get("/", this.controller.getAll.bind(this.controller));

    // Get auth by id
    this.router.get(
      "/:id",
      this.middleware.checkAuthExists.bind(this.middleware), // متد module
      this.controller.getById.bind(this.controller),
    );

    // Create new auth
    this.router.post(
      "/",
      this.middleware.validate(dto.create).bind(this.middleware), // متد common
      this.controller.create.bind(this.controller),
    );

    // Update auth
    this.router.put(
      "/:id",
      this.middleware.checkAuthExists.bind(this.middleware), // متد module
      this.middleware.validate(dto.update).bind(this.middleware), // متد common
      this.controller.update.bind(this.controller),
    );

    // Delete auth
    this.router.delete(
      "/:id",
      this.middleware.checkAuthExists.bind(this.middleware), // متد module
      this.controller.delete.bind(this.controller),
    );
  }

  getRouter() {
    return this.router;
  }
}

module.exports = new ${MODULE_NAME}().getRouter();

EOD

echo ""
echo "✅ Module '$MODULE_NAME' created successfully!"
echo ""
echo "📁 Generated files:"
echo "   ├── ${MODULE_NAME}.model.js         (Schema)"
echo "   ├── ${MODULE_NAME}.repository.js    (Data Access Layer)"
echo "   ├── ${MODULE_NAME}.service.js       (Business Logic)"
echo "   ├── ${MODULE_NAME}.controller.js    (HTTP Layer)"
echo "   ├── ${MODULE_NAME}.routes.js        (Routes)"
echo "   ├── middlewares/"
echo "   │   └── ${MODULE_NAME}.middleware.js (Custom Middleware)"
echo "   └── ${MODULE_NAME}.js                        (Module Export)"
echo ""
echo "📝 Next steps:"
echo "   1. Add to src/modules/index.js:"
echo "      const ${MODULE_NAME}Routes = require('./${MODULE_NAME}');"
echo "      router.use('/${MODULE_NAME}', ${MODULE_NAME}Routes);"
echo ""
echo "   2. Test your endpoidto.js           (Validation DTO)"
echo "   ├── ${MODULE_NAME}.nts:"
echo "      GET    /api/v1/${MODULE_NAME}"
echo "      GET    /api/v1/${MODULE_NAME}/:id"
echo "      POST   /api/v1/${MODULE_NAME}"
echo "      PUT    /api/v1/${MODULE_NAME}/:id"
echo "      DELETE /api/v1/${MODULE_NAME}/:id"
echo ""
