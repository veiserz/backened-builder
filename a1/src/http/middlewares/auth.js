'use strict';

const jwt = require('jsonwebtoken');
const { HttpError } = require('../errors/httpError');

/**
 * Validates a Bearer JWT and attaches `req.auth` to the request.
 */
function authMiddleware(req, _res, next) {
  const header = req.headers['authorization'] || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return next(new HttpError(401, 'Missing or malformed token'));
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.auth = payload;
    next();
  } catch {
    next(new HttpError(401, 'Invalid or expired token'));
  }
}

module.exports = authMiddleware;
