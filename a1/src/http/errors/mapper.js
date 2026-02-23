"use strict";

const { HttpError } = require("./httpError");
const { DomainError } = require("../../shared/errors/domainError");

/**
 * Translates any thrown error into a normalised HttpError.
 * Domain errors receive explicit status mappings; everything
 * else falls back to 500.
 */
function mapToHttpError(err) {
  if (err instanceof HttpError) return err;

  if (err instanceof DomainError) {
    const statusMap = {
      NOT_FOUND: 404,
      FORBIDDEN: 403,
      CONFLICT: 409,
      VALIDATION: 422,
      UNAUTHORISED: 401,
      BAD_REQUEST: 400,
      INTERNAL: 500,
    };
    const status = statusMap[err.code] ?? 400;
    return new HttpError(status, err.message, err.meta);
  }

  // Unknown / infrastructure errors → 500
  return new HttpError(500, "Internal server error");
}

module.exports = { mapToHttpError };
