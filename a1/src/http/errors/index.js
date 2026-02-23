"use strict";

const { logger } = require("../../infrastructure/logger");
const { mapToHttpError } = require("./mapper");

/**
 * Express 4-argument error-handling middleware.
 * Must be registered LAST in app.js.
 */
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  const httpErr = mapToHttpError(err);

  if (httpErr.status >= 500) {
    logger.error("Unhandled error", {
      requestId: req.requestId,
      stack: err.stack,
    });
  }

  return res.status(httpErr.status).json({
    success: false,
    error: {
      message: httpErr.message,
      ...(httpErr.details ? { details: httpErr.details } : {}),
      ...(process.env.NODE_ENV !== "production" && httpErr.status >= 500
        ? { stack: err.stack }
        : {}),
    },
  });
}

module.exports = {
  errorHandler,
  HttpError: require("./httpError").HttpError,
  mapToHttpError: require("./mapper").mapToHttpError,
};
