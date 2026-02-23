'use strict';

const { Value }       = require('@sinclair/typebox/value');
const { DomainError } = require('../../../shared/errors/domainError');

/**
 * Returns an Express middleware that validates req[source] against
 * a TypeBox schema. On success it coerces / defaults values in place.
 *
 * @param {import('@sinclair/typebox').TObject} schema
 * @param {'body'|'params'|'query'} [source='body']
 */
function validate(schema, source = 'body') {
  return (req, _res, next) => {
    const data = req[source] ?? {};
    if (!Value.Check(schema, data)) {
      const details = [...Value.Errors(schema, data)].map((e) => ({
        field:   e.path,
        message: e.message,
      }));
      return next(DomainError.validation('Validation failed', details));
    }
    req[source] = Value.Cast(schema, data);
    next();
  };
}

module.exports = { validate };
