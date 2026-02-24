"use strict";

const env = {
  NODE_ENV: process.env.NODE_ENV || "development",
  PORT: process.env.PORT || "3000",
  DB_HOST: process.env.DB_HOST || null,
  DB_PORT: process.env.DB_PORT || "5432",
  DB_NAME: process.env.DB_NAME || null,
  DB_USER: process.env.DB_USER || null,
  DB_PASSWORD: process.env.DB_PASSWORD || null,
  REDIS_HOST: process.env.REDIS_HOST || null,
  REDIS_PORT: process.env.REDIS_PORT || "6379",
  JWT_SECRET: process.env.JWT_SECRET || null,
  GRAFANA_ADMIN_USER: process.env.GRAFANA_ADMIN_USER || "admin",
  GRAFANA_ADMIN_PASSWORD: process.env.GRAFANA_ADMIN_PASSWORD || "CHANGE_ME_STRONG_PASSWORD",
  GRAFANA_ROOT_URL: process.env.GRAFANA_ROOT_URL || "https://grafana.example.com",
  GRAFANA_DOMAIN: process.env.GRAFANA_DOMAIN || "grafana.example.com",
  SLACK_WEBHOOK_URL: process.env.SLACK_WEBHOOK_URL || "https://hooks.slack.com/services/CHANGE/ME",
  ALERT_EMAIL_TO: process.env.ALERT_EMAIL_TO || "ops@example.com"
};

const required = [
  "DB_HOST",
  "DB_NAME",
  "DB_USER",
  "DB_PASSWORD",
  "REDIS_HOST",
  "JWT_SECRET",
];

function validateEnv() {
  const errors = [];

  for (const key of required) {
    if (!env[key]) {
      errors.push(`  ${key}: Required`);
    }
  }

  if (env.JWT_SECRET && env.JWT_SECRET.length < 12) {
    errors.push("  JWT_SECRET: Must be at least 12 characters");
  }

  if (errors.length > 0) {
    throw new Error(`Environment validation failed:\n${errors.join("\n")}`);
  }
}

module.exports = { env, validateEnv };
