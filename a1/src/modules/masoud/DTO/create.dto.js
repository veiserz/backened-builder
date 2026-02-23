'use strict';

const { Type } = require('@sinclair/typebox');

/** Input schema for creating a Masoud. TODO: adjust fields. */
const CreateMasoudDto = Type.Object({
  name: Type.String({ minLength: 1, maxLength: 255 }),
});

module.exports = { CreateMasoudDto };
