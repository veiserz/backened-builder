"use strict";

/**
 * Authorisation policies.
 * Each policy receives (authPayload, resource?) and returns boolean.
 *
 * Naming convention:  '<resource>:<action>'
 * Usage:              if (!can(req.auth, 'users:write')) throw DomainError.forbidden();
 */
const policies = {
  // ── Users ──────────────────────────────────────────────────────
  "users:read": (auth) => !!auth,
  "users:write": (auth) =>
    auth && (auth.role === "admin" || auth.sub === auth.targetId),
  "users:delete": (auth) => auth && auth.role === "admin",

  // ── Store ──────────────────────────────────────────────────────
  "store:read": (auth) => !!auth,
  "store:write": (auth) =>
    auth && (auth.role === "admin" || auth.role === "store_owner"),
  "store:delete": (auth) => auth && auth.role === "admin",

  // ── Auth ───────────────────────────────────────────────────────
  "auth:manage": (auth) => auth && auth.role === "admin",
};

/**
 * Check whether the authenticated principal satisfies a named policy.
 *
 * @param {object|null} auth      Decoded JWT payload (req.auth)
 * @param {string}      policy    Policy key, e.g. 'users:write'
 * @param {any}         [resource] Optional resource for ownership checks
 * @returns {boolean}
 */
function can(auth, policy, resource = null) {
  const check = policies[policy];
  if (!check) return false;
  return !!check(auth, resource);
}

module.exports = { policies, can };
