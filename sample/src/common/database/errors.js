/**
 * Custom Database Error Classes
 * Maps PostgreSQL error codes to domain-specific errors
 */

class DatabaseError extends Error {
  constructor(message, code, originalError = null) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
    this.originalError = originalError;
    this.statusCode = 500;
    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Unique Constraint Violation (e.g., duplicate key)
 * PostgreSQL Error Code: 23505
 */
class UniqueViolationError extends DatabaseError {
  constructor(message, detail, originalError) {
    super(message, "UNIQUE_VIOLATION", originalError);
    this.statusCode = 409;
    this.detail = detail;
  }
}

/**
 * Foreign Key Violation
 * PostgreSQL Error Code: 23503
 */
class ForeignKeyViolationError extends DatabaseError {
  constructor(message, detail, originalError) {
    super(message, "FOREIGN_KEY_VIOLATION", originalError);
    this.statusCode = 400;
    this.detail = detail;
  }
}

/**
 * Not Null Violation
 * PostgreSQL Error Code: 23502
 */
class NotNullViolationError extends DatabaseError {
  constructor(message, column, originalError) {
    super(message, "NOT_NULL_VIOLATION", originalError);
    this.statusCode = 400;
    this.column = column;
  }
}

/**
 * Check Constraint Violation
 * PostgreSQL Error Code: 23514
 */
class CheckViolationError extends DatabaseError {
  constructor(message, constraint, originalError) {
    super(message, "CHECK_VIOLATION", originalError);
    this.statusCode = 400;
    this.constraint = constraint;
  }
}

/**
 * Query Timeout Error
 * PostgreSQL Error Code: 57014
 */
class QueryTimeoutError extends DatabaseError {
  constructor(message, originalError) {
    super(message, "QUERY_TIMEOUT", originalError);
    this.statusCode = 408;
  }
}

/**
 * Connection Error
 */
class ConnectionError extends DatabaseError {
  constructor(message, originalError) {
    super(message, "CONNECTION_ERROR", originalError);
    this.statusCode = 503;
  }
}

/**
 * Query Cancelled Error (AbortSignal triggered)
 */
class QueryCancelledError extends DatabaseError {
  constructor(message, originalError) {
    super(message, "QUERY_CANCELLED", originalError);
    this.statusCode = 499;
  }
}

/**
 * Maps PostgreSQL error codes to custom domain errors
 * @param {Error} error - Original pg error
 * @returns {DatabaseError} Normalized error
 */
function normalizeError(error) {
  if (!error.code) {
    return new DatabaseError(error.message, "UNKNOWN_ERROR", error);
  }

  switch (error.code) {
    case "23505": // unique_violation
      return new UniqueViolationError(
        error.message || "Duplicate key value violates unique constraint",
        error.detail,
        error,
      );

    case "23503": // foreign_key_violation
      return new ForeignKeyViolationError(
        error.message || "Foreign key constraint violation",
        error.detail,
        error,
      );

    case "23502": // not_null_violation
      return new NotNullViolationError(
        error.message || "Null value violates not-null constraint",
        error.column,
        error,
      );

    case "23514": // check_violation
      return new CheckViolationError(
        error.message || "Check constraint violation",
        error.constraint,
        error,
      );

    case "57014": // query_canceled (timeout)
      return new QueryTimeoutError(
        error.message || "Query execution timeout",
        error,
      );

    case "ECONNREFUSED":
    case "ENOTFOUND":
    case "ETIMEDOUT":
      return new ConnectionError(
        error.message || "Database connection failed",
        error,
      );

    default:
      return new DatabaseError(
        error.message || "Database operation failed",
        error.code,
        error,
      );
  }
}

module.exports = {
  DatabaseError,
  UniqueViolationError,
  ForeignKeyViolationError,
  NotNullViolationError,
  CheckViolationError,
  QueryTimeoutError,
  ConnectionError,
  QueryCancelledError,
  normalizeError,
};
