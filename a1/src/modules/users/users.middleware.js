'use strict';

const { HttpError } = require('../../../http/errors/httpError');
const { isValidId } = require('../../../shared/utils/id');

/**
 * Validates that :id route params are valid UUIDs.
 */
function validateUserId(req, _res, next) {
  if (!isValidId(req.params.id)) {
    return next(new HttpError(400, 'Invalid user ID format'));
  }
  next();
}

module.exports = { validateUserId };
