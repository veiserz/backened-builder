'use strict';

/**
 * Authorisation policies.
 * Each policy receives (authPayload, resource) and returns boolean.
 */
const policies = {
  'users:read':   (auth) => !!auth,
  'users:write':  (auth) => auth && (auth.role === 'admin' || auth.sub === auth.targetId),
  'users:delete': (auth) => auth && auth.role === 'admin',
};

function can(auth, policy, resource = null) {
  const check = policies[policy];
  if (!check) return false;
  return check(auth, resource);
}

module.exports = { policies, can };
