'use strict';

const { generateId } = require('../../../shared/utils/id');
const { now }        = require('../../../shared/utils/time');

class Masoud {
  constructor({ id, name, createdAt, updatedAt }) {
    this.id        = id        || generateId();
    this.name      = Masoud._normaliseName(name);
    this.createdAt = createdAt || now();
    this.updatedAt = updatedAt || now();
  }

  // ── Normalisation ──────────────────────────────────────────
  static _normaliseName(v) {
    return typeof v === 'string' ? v.trim().replace(/\s+/g, ' ') : v;
  }

  // ── Factories ─────────────────────────────────────────────

  /** Reconstruct entity from a PostgreSQL row (snake_case → camelCase). */
  static fromRecord(row) {
    return new Masoud({
      id:        row.id,
      name:      row.name,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    });
  }

  // ── Domain behaviour ──────────────────────────────────────

  /** Apply a validated update DTO onto this entity in-place. */
  applyUpdate(dto) {
    if (dto.name !== undefined) this.name = Masoud._normaliseName(dto.name);
    this.updatedAt = now();
  }

  // ── Serialisation ─────────────────────────────────────────

  /** Persist-ready record (camelCase → snake_case). */
  toRecord() {
    return {
      id:         this.id,
      name:       this.name,
      created_at: this.createdAt,
      updated_at: this.updatedAt,
    };
  }

  /** Safe public serialisation — no internal/sensitive fields. */
  toResponse() {
    return {
      id:        this.id,
      name:      this.name,
      createdAt: this.createdAt instanceof Date ? this.createdAt.toISOString() : this.createdAt,
      updatedAt: this.updatedAt instanceof Date ? this.updatedAt.toISOString() : this.updatedAt,
    };
  }
}

module.exports = { Masoud };
