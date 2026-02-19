"use strict";

const { Type } = require("@sinclair/typebox");

/**
 * User DTOs using TypeBox for runtime schema validation.
 * Each object defines the shape and constraints of user-related inputs/outputs.
 */

const UserCreateDto = Type.Object({
  name: Type.String({ minLength: 2, maxLength: 100 }),
  email: Type.String({ format: "email" }),
  password: Type.String({ minLength: 8, maxLength: 72 }),
  role: Type.Optional(
    Type.Union([Type.Literal("user"), Type.Literal("admin")]),
  ),
});

const UserUpdateDto = Type.Object({
  name: Type.Optional(Type.String({ minLength: 2, maxLength: 100 })),
  password: Type.Optional(Type.String({ minLength: 8, maxLength: 72 })),
  role: Type.Optional(
    Type.Union([Type.Literal("user"), Type.Literal("admin")]),
  ),
});

const UserResponseDto = Type.Object({
  id: Type.String({ format: "uuid" }),
  name: Type.String(),
  email: Type.String({ format: "email" }),
  role: Type.String(),
  createdAt: Type.String({ format: "date-time" }),
  updatedAt: Type.String({ format: "date-time" }),
});

const UserListQueryDto = Type.Object({
  page: Type.Optional(Type.Integer({ minimum: 1, default: 1 })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100, default: 20 })),
});

const UserParamDto = Type.Object({
  id: Type.String({ format: "uuid" }),
});

module.exports = {
  UserCreateDto,
  UserUpdateDto,
  UserResponseDto,
  UserListQueryDto,
  UserParamDto,
};
