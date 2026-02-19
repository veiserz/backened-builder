'use strict';

const { v4: uuidv4 } = require('uuid');
const { logger }     = require('../../infrastructure/logger');

/**
 * Attaches a unique requestId to every request and logs it.
 */
function requestContextMiddleware(req, res, next) {
  const requestId = req.headers['x-request-id'] || uuidv4();
  req.requestId   = requestId;
  res.setHeader('x-request-id', requestId);

  const startAt = Date.now();
  res.on('finish', () => {
    logger.info('HTTP request', {
      requestId,
      method:   req.method,
      url:      req.originalUrl,
      status:   res.statusCode,
      ms:       Date.now() - startAt,
    });
  });

  next();
}

module.exports = requestContextMiddleware;
