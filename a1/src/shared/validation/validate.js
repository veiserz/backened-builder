'use strict';

const { DomainError } = require('../errors/domainError');

/**
 * Validates data against a Zod schema.
 * Throws DomainError(VALIDATION) on failure.
 *
 * @template T
 * @param {import('zod').ZodType<T>} schema
 * @param {unknown} data
 * @returns {T}
 */
function validate(schema, data) {
  const result = schema.safeParse(data);
  if (!result.success) {
    const details = result.error.errors.map((e) => ({
      field:   e.path.join('.'),
      message: e.message,
    }));
    throw DomainError.validation('Validation failed', details);
  }
  return result.data;
}

module.exports = { validate };
