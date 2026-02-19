'use strict';

/**
 * Base class for all domain / application errors.
 * The HTTP mapper translates these via their `code`.
 */
class DomainError extends Error {
  /**
   * @param {string} message  Human-readable description
   * @param {string} code     Machine-readable code (NOT_FOUND, CONFLICT, …)
   * @param {any}    [meta]   Optional context data
   */
  constructor(message, code = 'DOMAIN_ERROR', meta = null) {
    super(message);
    this.name = 'DomainError';
    this.code = code;
    this.meta = meta;
    Error.captureStackTrace(this, this.constructor);
  }

  static notFound(message = 'Resource not found', meta = null) {
    return new DomainError(message, 'NOT_FOUND', meta);
  }

  static conflict(message = 'Resource already exists', meta = null) {
    return new DomainError(message, 'CONFLICT', meta);
  }

  static forbidden(message = 'Access denied', meta = null) {
    return new DomainError(message, 'FORBIDDEN', meta);
  }

  static validation(message = 'Validation failed', meta = null) {
    return new DomainError(message, 'VALIDATION', meta);
  }

  static unauthorised(message = 'Unauthorised', meta = null) {
    return new DomainError(message, 'UNAUTHORISED', meta);
  }
}

module.exports = { DomainError };
