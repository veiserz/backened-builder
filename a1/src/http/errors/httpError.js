'use strict';

class HttpError extends Error {
  /**
   * @param {number} status  HTTP status code
   * @param {string} message Human-readable message
   * @param {any}    [details] Optional structured detail
   */
  constructor(status, message, details = null) {
    super(message);
    this.name    = 'HttpError';
    this.status  = status;
    this.details = details;
    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = { HttpError };
