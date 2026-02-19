'use strict';

const { v4: uuidv4 } = require('uuid');

function generateId() {
  return uuidv4();
}

function isValidId(id) {
  return typeof id === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id);
}

module.exports = { generateId, isValidId };
