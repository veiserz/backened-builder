const { Type } = require("@sinclair/typebox");

const DTO = {
  create: Type.Object({
    title: Type.String({ minLength: 3, maxLength: 100 }),
    description: Type.Optional(Type.String({ maxLength: 500 })),
    isActive: Type.Optional(Type.Boolean()),
  }),

  update: Type.Object({
    title: Type.Optional(Type.String({ minLength: 3, maxLength: 100 })),
    description: Type.Optional(Type.String({ maxLength: 500 })),
    isActive: Type.Optional(Type.Boolean()),
  }),
};

module.exports = DTO;
