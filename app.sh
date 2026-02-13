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
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js",
    "generate:module": "./make-module.sh"
  },
  "dependencies": {
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "mongoose": "^8.0.0",
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
mkdir -p src/config
mkdir -p src/common/database
mkdir -p src/common/redis
mkdir -p src/common/middlewares
mkdir -p src/common/utils
mkdir -p src/modules

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

# Database
DB_URI=mongodb://localhost:27017/$PROJECT_NAME
DB_POOL_SIZE=10

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# JWT
JWT_SECRET=change_me_please_very_secure_key
JWT_EXPIRES_IN=7d

# Other
API_PREFIX=/api/v1
EOF

cat <<EOF > README.md
# $PROJECT_NAME

## 📁 Project Structure
\`\`\`
Back-End/
├── .env
├── package.json
└── src/
    ├── config/           # ⚙️ تنظیمات
    ├── common/           # 🏗️ زیرساخت مشترک
    ├── modules/          # 📦 ماژول‌های بیزنس
    ├── app.js            # 🔌 Express Setup
    └── server.js         # 🚀 Server Entry
\`\`\`

## 🚀 Usage
\`\`\`bash
npm install
npm run dev
\`\`\`

## 📦 Generate Module
\`\`\`bash
./make-module.sh <module-name>
\`\`\`
EOF

# ---------------------------------------------------------
# 4. Config Files
# ---------------------------------------------------------
echo "⚙️ Creating config files..."

cat <<EOF > src/config/index.js
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

cat <<EOF > src/config/db.config.js
module.exports = {
  uri: process.env.DB_URI,
  options: {
    maxPoolSize: parseInt(process.env.DB_POOL_SIZE) || 10,
    minPoolSize: 2,
    serverSelectionTimeoutMS: 5000,
    socketTimeoutMS: 45000,
  }
};
EOF

cat <<EOF > src/config/redis.config.js
module.exports = {
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT) || 6379,
  retryStrategy: (times) => Math.min(times * 50, 2000)
};
EOF

# ---------------------------------------------------------
# 5. Common - Database
# ---------------------------------------------------------
echo "🔌 Creating database connection..."

cat <<EOF > src/common/database/mongoose.js
const mongoose = require('mongoose');
const dbConfig = require('../../config/db.config');

const connectDB = async () => {
  try {
    await mongoose.connect(dbConfig.uri, dbConfig.options);
    console.log('✅ MongoDB Connected');
  } catch (error) {
    console.error('❌ MongoDB Connection Error:', error.message);
    process.exit(1);
  }
};

mongoose.connection.on('disconnected', () => {
  console.log('⚠️  MongoDB Disconnected');
});

module.exports = connectDB;
EOF

# ---------------------------------------------------------
# 6. Common - Redis
# ---------------------------------------------------------
echo "🔌 Creating redis client..."

cat <<EOF > src/common/redis/client.js
const redis = require('redis');
const redisConfig = require('../../config/redis.config');

let client = null;

const connectRedis = async () => {
  try {
    client = redis.createClient(redisConfig);
    
    client.on('error', (err) => console.error('❌ Redis Error:', err));
    client.on('connect', () => console.log('✅ Redis Connected'));
    
    await client.connect();
    return client;
  } catch (error) {
    console.error('❌ Redis Connection Error:', error.message);
  }
};

const getRedisClient = () => client;

module.exports = { connectRedis, getRedisClient };
EOF

# ---------------------------------------------------------
# 7. Common - Middlewares
# ---------------------------------------------------------
echo "🛡️ Creating common middlewares..."

cat <<EOF > src/common/middlewares/auth.js
const jwt = require('jsonwebtoken');
const config = require('../../config');

const authenticate = (req, res, next) => {
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
};

module.exports = { authenticate };
EOF

cat <<EOF > src/common/middlewares/error.js
const errorHandler = (err, req, res, next) => {
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
};

const notFoundHandler = (req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found'
  });
};

module.exports = { errorHandler, notFoundHandler };
EOF

cat <<EOF > src/common/middlewares/logger.js
const morgan = require('morgan');

const logger = morgan(':method :url :status :res[content-length] - :response-time ms');

module.exports = logger;
EOF

cat <<EOF > src/common/middlewares/validate.js
const validate = (schema) => (req, res, next) => {
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

module.exports = validate;
EOF

# ---------------------------------------------------------
# 8. Common - Utils
# ---------------------------------------------------------
echo "🛠️ Creating utils..."

cat <<EOF > src/common/utils/response.js
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

cat <<EOF > src/common/utils/date-util.js
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

# ---------------------------------------------------------
# 9. Modules - Index (Main Aggregator)
# ---------------------------------------------------------
echo "🌟 Creating modules aggregator..."

cat <<EOF > src/modules/index.js
const express = require('express');
const router = express.Router();

// Import all module routes here
// Example: const usersRoutes = require('./users');
// router.use('/users', usersRoutes);

router.get('/health', (req, res) => {
  res.json({ success: true, message: 'API is running' });
});

module.exports = router;
EOF

# ---------------------------------------------------------
# 10. App.js - Express Setup
# ---------------------------------------------------------
echo "🔌 Creating app.js..."

cat <<EOF > src/app.js
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const config = require('./config');
const logger = require('./common/middlewares/logger');
const { errorHandler, notFoundHandler } = require('./common/middlewares/error');
const moduleRoutes = require('./modules');

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
app.use(config.server.apiPrefix, moduleRoutes);

// Error Handling
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
EOF

# ---------------------------------------------------------
# 11. Server.js - Entry Point
# ---------------------------------------------------------
echo "🚀 Creating server.js..."

cat <<EOF > src/server.js
const app = require('./app');
const config = require('./config');
const connectDB = require('./common/database/mongoose');
const { connectRedis } = require('./common/redis/client');

const startServer = async () => {
  try {
    // Connect to Database
    await connectDB();
    
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

// Handle Unhandled Rejection
process.on('unhandledRejection', (err) => {
  console.error('💥 Unhandled Rejection:', err);
  process.exit(1);
});

startServer();
EOF

# =========================================================
# 12. بخش جادویی: تولید فایل make-module.sh
# =========================================================
echo "🔨 Creating make-module.sh tool..."

cat <<'MAKER_EOF' > make-module.sh
#!/bin/bash
MODULE_NAME=$1

if [ -z "$MODULE_NAME" ]; then
  echo "❌ Usage: ./make-module.sh <module_name>"
  echo "Example: ./make-module.sh users"
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

# 1. Model (Mongoose Schema)
cat <<EOD > "$DIR/$MODULE_NAME.model.js"
const mongoose = require('mongoose');

const ${MODULE_NAME}Schema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    trim: true
  },
  isActive: {
    type: Boolean,
    default: true
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('${CAP_NAME}', ${MODULE_NAME}Schema);
EOD

# 2. Repository (Database Access Layer)
cat <<EOD > "$DIR/$MODULE_NAME.repository.js"
const ${CAP_NAME}Model = require('./${MODULE_NAME}.model');

class ${CAP_NAME}Repository {
  async findAll(filters = {}, options = {}) {
    const { page = 1, limit = 10, sort = '-createdAt' } = options;
    const skip = (page - 1) * limit;

    const items = await ${CAP_NAME}Model
      .find(filters)
      .sort(sort)
      .skip(skip)
      .limit(limit);

    const total = await ${CAP_NAME}Model.countDocuments(filters);

    return {
      items,
      pagination: {
        total,
        page,
        limit,
        pages: Math.ceil(total / limit)
      }
    };
  }

  async findById(id) {
    return await ${CAP_NAME}Model.findById(id);
  }

  async findOne(conditions) {
    return await ${CAP_NAME}Model.findOne(conditions);
  }

  async create(data) {
    const item = new ${CAP_NAME}Model(data);
    return await item.save();
  }

  async update(id, data) {
    return await ${CAP_NAME}Model.findByIdAndUpdate(
      id,
      { \$set: data },
      { new: true, runValidators: true }
    );
  }

  async delete(id) {
    return await ${CAP_NAME}Model.findByIdAndDelete(id);
  }

  async exists(conditions) {
    return await ${CAP_NAME}Model.exists(conditions);
  }
}

module.exports = new ${CAP_NAME}Repository();
EOD

# 3. Service (Business Logic)
cat <<EOD > "$DIR/$MODULE_NAME.service.js"
const ${MODULE_NAME}Repository = require('./${MODULE_NAME}.repository');

class ${CAP_NAME}Service {
  async getAll(filters = {}, options = {}) {
    return await ${MODULE_NAME}Repository.findAll(filters, options);
  }

  async getById(id) {
    const item = await ${MODULE_NAME}Repository.findById(id);
    if (!item) {
      const error = new Error('${CAP_NAME} not found');
      error.statusCode = 404;
      throw error;
    }
    return item;
  }

  async create(data) {
    // Business logic here (e.g., check duplicates)
    const exists = await ${MODULE_NAME}Repository.exists({ title: data.title });
    if (exists) {
      const error = new Error('${CAP_NAME} with this title already exists');
      error.statusCode = 409;
      throw error;
    }

    return await ${MODULE_NAME}Repository.create(data);
  }

  async update(id, data) {
    const item = await ${MODULE_NAME}Repository.update(id, data);
    if (!item) {
      const error = new Error('${CAP_NAME} not found');
      error.statusCode = 404;
      throw error;
    }
    return item;
  }

  async delete(id) {
    const item = await ${MODULE_NAME}Repository.delete(id);
    if (!item) {
      const error = new Error('${CAP_NAME} not found');
      error.statusCode = 404;
      throw error;
    }
    return item;
  }
}

module.exports = new ${CAP_NAME}Service();
EOD

# 4. Controller
cat <<EOD > "$DIR/$MODULE_NAME.controller.js"
const ${MODULE_NAME}Service = require('./${MODULE_NAME}.service');
const ApiResponse = require('../../common/utils/response');

class ${CAP_NAME}Controller {
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

module.exports = new ${CAP_NAME}Controller();
EOD

# 5. Middleware (Module-specific)
cat <<EOD > "$DIR/middlewares/${MODULE_NAME}.middleware.js"
const ${MODULE_NAME}Repository = require('../${MODULE_NAME}.repository');

/**
 * Check if ${MODULE_NAME} exists
 */
const check${CAP_NAME}Exists = async (req, res, next) => {
  try {
    const id = req.params.id;
    const exists = await ${MODULE_NAME}Repository.exists({ _id: id });

    if (!exists) {
      return res.status(404).json({
        success: false,
        message: '${CAP_NAME} not found'
      });
    }

    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Check ownership (example)
 */
const checkOwnership = async (req, res, next) => {
  try {
    const item = await ${MODULE_NAME}Repository.findById(req.params.id);

    // Example: check if user owns this resource
    // if (item.userId.toString() !== req.user.id) {
    //   return res.status(403).json({
    //     success: false,
    //     message: 'Access denied'
    //   });
    // }

    next();
  } catch (error) {
    next(error);
  }
};

module.exports = {
  check${CAP_NAME}Exists,
  checkOwnership
};
EOD

# 6. Routes
cat <<EOD > "$DIR/$MODULE_NAME.routes.js"
const express = require('express');
const router = express.Router();
const controller = require('./${MODULE_NAME}.controller');
const { authenticate } = require('../../common/middlewares/auth');
const validate = require('../../common/middlewares/validate');
const { check${CAP_NAME}Exists } = require('./middlewares/${MODULE_NAME}.middleware');
const Joi = require('joi');

// Validation Schema
const create${CAP_NAME}Schema = Joi.object({
  title: Joi.string().required().min(3).max(100),
  description: Joi.string().optional().max(500),
  isActive: Joi.boolean().optional()
});

const update${CAP_NAME}Schema = Joi.object({
  title: Joi.string().optional().min(3).max(100),
  description: Joi.string().optional().max(500),
  isActive: Joi.boolean().optional()
});

// Routes
router.get('/', controller.getAll);
router.get('/:id', check${CAP_NAME}Exists, controller.getById);
router.post('/', validate(create${CAP_NAME}Schema), controller.create);
router.put('/:id', check${CAP_NAME}Exists, validate(update${CAP_NAME}Schema), controller.update);
router.delete('/:id', check${CAP_NAME}Exists, controller.delete);

module.exports = router;
EOD

# 7. Index (Module Export)
cat <<EOD > "$DIR/index.js"
module.exports = require('./${MODULE_NAME}.routes');
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
echo "   └── index.js                        (Module Export)"
echo ""
echo "📝 Next steps:"
echo "   1. Add to src/modules/index.js:"
echo "      const ${MODULE_NAME}Routes = require('./${MODULE_NAME}');"
echo "      router.use('/${MODULE_NAME}', ${MODULE_NAME}Routes);"
echo ""
echo "   2. Test your endpoints:"
echo "      GET    /api/v1/${MODULE_NAME}"
echo "      GET    /api/v1/${MODULE_NAME}/:id"
echo "      POST   /api/v1/${MODULE_NAME}"
echo "      PUT    /api/v1/${MODULE_NAME}/:id"
echo "      DELETE /api/v1/${MODULE_NAME}/:id"
echo ""
MAKER_EOF

chmod +x make-module.sh

# ---------------------------------------------------------
# 13. نصب پکیج‌ها
# ---------------------------------------------------------
echo ""
echo "📥 Installing dependencies..."
npm install

echo ""
echo "✅✅✅ Project Ready! ✅✅✅"
echo ""
echo "📁 Structure:"
echo "   ├── src/"
echo "   │   ├── config/          ⚙️  Configuration"
echo "   │   ├── common/          🏗️  Shared Infrastructure"
echo "   │   ├── modules/         📦  Business Modules"
echo "   │   ├── app.js           🔌  Express Setup"
echo "   │   └── server.js        🚀  Server Entry"
echo ""
echo "🚀 Quick Start:"
echo "   cd $PROJECT_NAME"
echo "   npm run dev"
echo ""
echo "📦 Create Module:"
echo "   ./make-module.sh users"
echo ""