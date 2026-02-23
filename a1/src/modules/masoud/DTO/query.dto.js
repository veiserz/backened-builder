'use strict';

const { Type } = require('@sinclair/typebox');

const MasoudListQueryDto = Type.Object({
  page:  Type.Optional(Type.Integer({ minimum: 1, default: 1 })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100, default: 20 })),
});

module.exports = { MasoudListQueryDto };
