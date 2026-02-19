# Back-end Builder

Production-ready modular Node.js backend using Express, PostgreSQL, Redis, Bull, and Winston.

## Architecture

```
bootstrap  → application startup
http       → HTTP layer (middleware, error mapping, responses)
app        → application layer (config, DI container, dispatcher)
infra      → external adapters (DB, Redis, Queue, EventBus, Logger)
modules    → feature modules (each module owns its full slice)
shared     → reusable cross-cutting utilities
```

## Quick Start

```bash
cp .env.example .env
npm install
npm run dev
```

## Generate a new module

```bash
npm run new:module <module-name>
```
