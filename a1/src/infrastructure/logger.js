"use strict";

const fs = require("fs");
const winston = require("winston");
const { env } = require("./env");

const { combine, timestamp, json, colorize, simple, errors } = winston.format;

const isProduction = env.NODE_ENV === "production";

if (isProduction && !fs.existsSync("logs")) {
  fs.mkdirSync("logs", { recursive: true });
}

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: combine(
    errors({ stack: true }),
    timestamp(),
    isProduction ? json() : combine(colorize(), simple()),
  ),
  transports: [
    new winston.transports.Console(),
    ...(isProduction
      ? [
          new winston.transports.File({
            filename: "logs/error.log",
            level: "error",
          }),
          new winston.transports.File({ filename: "logs/combined.log" }),
        ]
      : []),
  ],
  exceptionHandlers: isProduction
    ? [new winston.transports.File({ filename: "logs/exceptions.log" })]
    : [new winston.transports.Console()],
  rejectionHandlers: isProduction
    ? [new winston.transports.File({ filename: "logs/rejections.log" })]
    : [new winston.transports.Console()],
});

module.exports = { logger };
