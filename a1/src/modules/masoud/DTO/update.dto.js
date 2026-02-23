'use strict';

const { Type } = require('@sinclair/typebox');

/** Input schema for updating a Masoud. All fields optional. */
const UpdateMasoudDto = Type.Object({
  name: Type.Optional(Type.String({ minLength: 1, maxLength: 255 })),
});

module.exports = { UpdateMasoudDto };
