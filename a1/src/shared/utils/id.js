"use strict";

const { v4: uuidv4 } = require("uuid");
const { DomainError } = require("../errors/domainError");

/** Generate a new UUID v4. */
function generateId() {
  return uuidv4();
}

/**
 * Return true if `id` is a valid UUID v4 string.
 * @param {any} id
 * @returns {boolean}
 */
function isValidId(id) {
  return (
    typeof id === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      id,
    )
  );
}

/**
 * Assert that `id` is a valid UUID v4; throw DomainError(BAD_REQUEST) otherwise.
 * Convenient for use in repositories and services.
 *
 * @param {any}    id
 * @param {string} [label='id']  Field name used in the error message
 * @returns {string} The validated id
 */
function assertValidId(id, label = "id") {
  if (!isValidId(id)) {
    throw DomainError.badRequest(
      `Invalid ${label}: "${id}" is not a valid UUID`,
    );
  }
  return id;
}

module.exports = { generateId, isValidId, assertValidId };
