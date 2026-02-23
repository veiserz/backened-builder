"use strict";

const { HttpError } = require("../errors/httpError");

/**
 * Base class for all module-specific middleware classes.
 *
 * Subclasses extend this and add module-only middlewares
 * (ownership checks, role gates, etc.).
 *
 * Usage:
 *   class ProductMiddleware extends BaseMiddleware { ... }
 *   const productMiddleware = new ProductMiddleware();
 *   router.get('/:id', productMiddleware.requireOwner(), ctrl.getById);
 */
class BaseMiddleware {
  /**
   * Wraps an async middleware function so that any thrown error
   * is automatically forwarded to Express's next(err).
   *
   * @param {Function} fn  async (req, res, next) => void
   * @returns {Function}   Express middleware
   */
  static wrap(fn) {
    return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
  }

  /**
   * Require the request to have a valid auth token (req.auth set by authMiddleware).
   * Useful when you need an auth gate outside the global auth middleware.
   */
  requireAuth() {
    return BaseMiddleware.wrap(async (req, _res, next) => {
      if (!req.auth) {
        return next(new HttpError(401, "Authentication required"));
      }
      next();
    });
  }

  /**
   * Require the authenticated user to have one of the allowed roles.
   *
   * @param {...string} roles
   */
  requireRole(...roles) {
    return BaseMiddleware.wrap(async (req, _res, next) => {
      if (!req.auth || !roles.includes(req.auth.role)) {
        return next(new HttpError(403, "Insufficient permissions"));
      }
      next();
    });
  }

  /**
   * Override in subclasses to return the resource owner's user ID.
   * Used by requireOwnership() to determine access.
   *
   * @param {import('express').Request} _req
   * @returns {Promise<string|null>}
   */
  // eslint-disable-next-line no-unused-vars
  async resolveOwnerId(_req) {
    return null;
  }

  /**
   * Deny access unless req.auth.sub equals the value returned by resolveOwnerId().
   * Default: compares req.auth.sub to req.params.id.
   * Override resolveOwnerId() for custom ownership resolution.
   */
  requireOwnership() {
    return BaseMiddleware.wrap(async (req, _res, next) => {
      const ownerId = await this.resolveOwnerId(req);
      const subject = req.auth?.sub;
      if (!subject || subject !== (ownerId ?? req.params?.id)) {
        return next(new HttpError(403, "Access denied"));
      }
      next();
    });
  }
}

module.exports = { BaseMiddleware };
