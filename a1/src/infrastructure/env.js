'use strict';

const { z } = require('zod');

const envSchema = z.object({
  NODE_ENV:   z.enum(['development', 'test', 'production']).default('development'),
  PORT:       z.string().regex(/^\d+$/).default('3000'),
  DB_HOST:    z.string().min(1),
  DB_PORT:    z.string().regex(/^\d+$/).default('5432'),
  DB_NAME:    z.string().min(1),
  DB_USER:    z.string().min(1),
  DB_PASSWORD:z.string(),
  REDIS_HOST: z.string().min(1),
  REDIS_PORT: z.string().regex(/^\d+$/).default('6379'),
  JWT_SECRET: z.string().min(12),
});

function validateEnv() {
  const result = envSchema.safeParse(process.env);
  if (!result.success) {
    const formatted = result.error.errors
      .map((e) => `  ${e.path.join('.')}: ${e.message}`)
      .join('\n');
    throw new Error(`Environment validation failed:\n${formatted}`);
  }
}

module.exports = { validateEnv };
