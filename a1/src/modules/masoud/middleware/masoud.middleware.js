'use strict';

const { BaseMiddleware } = require('../../../http/middlewares/BaseMiddleware');
const { HttpError }      = require('../../../http/errors/httpError');

class MasoudMiddleware extends BaseMiddleware {
  /**
   * Ensure the authenticated user owns the requested resource.
   * Default: compares req.params.id to req.auth.sub.
   * Override resolveOwnerId() for custom ownership logic.
   */
  requireOwner() {
    return BaseMiddleware.wrap(async (req, _res, next) => {
      if (req.params.id !== req.auth?.sub) {
        return next(new HttpError(403, 'Access denied'));
      }
      next();
    });
  }
}

/** Singleton instance for direct use in the router. */
const masoudMiddleware = new MasoudMiddleware();

module.exports = { MasoudMiddleware, masoudMiddleware };
