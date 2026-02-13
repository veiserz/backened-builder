# Back-end Builder

A powerful Bash script to instantly scaffold a production-ready, modular Express.js backend architecture.

## 🚀 Features

- **Clean Architecture:** Modular structure separating config, common utilities, and business modules.
- **Pre-configured Stack:**
  - **Express.js** configuration with security (Helmet, CORS) and logging (Morgan).
  - **MongoDB** connection setup using Mongoose.
  - **Redis** client setup.
  - **Authentication** middleware with JWT.
  - **Validation** middleware setup using Joi.
  - **Error Handling** & Standardization.
- **Module Generator:** Includes a `make-module.sh` script in the generated project to instantly create new business modules (Controller, Service, Repository, Model, Routes).

## 🛠️ Usage

1. **Make the script executable:**
   ```bash
   chmod +x app.sh
   ```

2. **Run the builder:**
   Pass your desired project name as an argument.

   ```bash
   ./app.sh <project-name>
   ```

   **Example:**

   ```bash
   ./app.sh my-awesome-api
   ```

3. **Wait for installation:**
   The script will create a new directory with your project name, generate all necessary files, and install NPM dependencies automatically.

## 📂 Generated Project Structure

The tool creates the following directory structure for your new application:

```text
my-project/
├── make-module.sh        # 🛠 Tool to generate new business modules
├── package.json
├── .env
├── src/
│   ├── config/           # ⚙️ Configuration (DB, Redis, Server)
│   ├── common/           # 🏗️ Shared Infrastructure
│   │   ├── database/     # DB Connection Logic
│   │   ├── middlewares/  # Auth, Error, Logger, Validate
│   │   ├── redis/        # Redis Client
│   │   └── utils/        # Helper functions
│   ├── modules/          # 📦 Business Modules (Where your code goes)
│   ├── app.js            # 🔌 Express App Setup
│   └── server.js         # 🚀 Server Entry Point
└── README.md
```

## 📦 Generating Modules (Inside your new project)

Once your project is generated, you can easily add new features using the included helper script.

1. Navigate to your new project:

   ```bash
   cd <project-name>
   ```

2. Generate a new module (e.g., `products`):
   ```bash
   ./make-module.sh products
   ```

This will automatically create:

- `products.model.js`
- `products.repository.js`
- `products.service.js`
- `products.controller.js`
- `products.routes.js`
