'use strict';

const { Type } = require('@sinclair/typebox');

const MasoudParamDto = Type.Object({
  id: Type.String({ format: 'uuid' }),
});

module.exports = { MasoudParamDto };
