'use strict';

/**
 * Feature flags – read from env so they can be toggled without deploys.
 */
const features = {
  emailVerification: process.env.FEATURE_EMAIL_VERIFICATION === 'true',
  rateLimiting:      process.env.FEATURE_RATE_LIMITING      !== 'false',
  auditLog:          process.env.FEATURE_AUDIT_LOG          === 'true',
};

module.exports = { features };
