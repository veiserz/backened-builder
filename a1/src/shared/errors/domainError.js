"use strict";

/**
 * Base class for all domain / application errors.
 * The HTTP mapper translates these via their `code`.
 *
 * Codes and their default HTTP mappings (see http/errors/mapper.js):
 *   NOT_FOUND    → 404
 *   FORBIDDEN    → 403
 *   CONFLICT     → 409
 *   VALIDATION   → 422
 *   UNAUTHORISED → 401
 *   BAD_REQUEST  → 400
 *   INTERNAL     → 500
 */
class DomainError extends Error {
  /**
   * @param {string} message  Human-readable description
   * @param {string} code     Machine-readable code (NOT_FOUND, CONFLICT, …)
   * @param {any}    [meta]   Optional context data (field details, resource info)
   */
  constructor(message, code = "DOMAIN_ERROR", meta = null) {
    super(message);
    this.name = "DomainError";
    this.code = code;
    this.meta = meta;
    Error.captureStackTrace(this, this.constructor);
  }

  // ── Static factories ─────────────────────────────────────────────────────

  static notFound(message = "Resource not found", meta = null) {
    return new DomainError(message, "NOT_FOUND", meta);
  }

  static conflict(message = "Resource already exists", meta = null) {
    return new DomainError(message, "CONFLICT", meta);
  }

  static forbidden(message = "Access denied", meta = null) {
    return new DomainError(message, "FORBIDDEN", meta);
  }

  static validation(message = "Validation failed", meta = null) {
    return new DomainError(message, "VALIDATION", meta);
  }

  static unauthorised(message = "Unauthorised", meta = null) {
    return new DomainError(message, "UNAUTHORISED", meta);
  }

  static badRequest(message = "Bad request", meta = null) {
    return new DomainError(message, "BAD_REQUEST", meta);
  }

  /**
   * Use for unexpected conditions that represent bugs or infrastructure
   * failures — not user errors. Maps to HTTP 500.
   */
  static internal(message = "Internal error", meta = null) {
    return new DomainError(message, "INTERNAL", meta);
  }

  // ── Instance helpers ─────────────────────────────────────────────────────

  /**
   * Check whether this error carries a specific code.
   * @param {string} code
   * @returns {boolean}
   */
  is(code) {
    return this.code === code;
  }
}

module.exports = { DomainError };
