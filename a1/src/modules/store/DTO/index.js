// src/modules/store/DTO/index.js
"use strict";

const { Type } = require("@sinclair/typebox");

// ── Create ────────────────────────────────────────────────────────────────────

const CreateStoreDto = Type.Object({
  name: Type.String({
    minLength: 1,
    maxLength: 255,
    description: "Store display name",
  }),
});

// ── Update ────────────────────────────────────────────────────────────────────

const UpdateStoreDto = Type.Object({
  name: Type.Optional(Type.String({ minLength: 1, maxLength: 255 })),
});

// ── URL Params ────────────────────────────────────────────────────────────────

const StoreParamDto = Type.Object({
  id: Type.String({ format: "uuid" }),
});

// ── List Query ────────────────────────────────────────────────────────────────

const StoreListQueryDto = Type.Object({
  page: Type.Optional(Type.Integer({ minimum: 1, default: 1 })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100, default: 20 })),
});

// ── Response (for JSDoc typing only — not used for validation) ────────────────

const StoreResponseDto = Type.Object({
  id: Type.String({ format: "uuid" }),
  name: Type.String(),
  createdAt: Type.String({ format: "date-time" }),
  updatedAt: Type.String({ format: "date-time" }),
});

// ── Exports ───────────────────────────────────────────────────────────────────

module.exports = {
  CreateStoreDto,
  UpdateStoreDto,
  StoreParamDto,
  StoreListQueryDto,
  StoreResponseDto,
};
