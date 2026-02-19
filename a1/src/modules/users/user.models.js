"use strict";

const { generateId } = require("../../shared/utils/id");
const { now } = require("../../shared/utils/time");

/**
 * User domain entity.
 * Accepts validated DTO objects, normalises all fields,
 * and exposes a consistent internal representation.
 *
 * Flow:  HTTP body → TypeBox validation (user.dto.js)
 *               → User.fromCreateDto() normalise → entity
 *               → repository / service logic
 */
class User {
  constructor({
    id,
    name,
    email,
    passwordHash,
    role = "user",
    createdAt,
    updatedAt,
  }) {
    this.id = id || generateId();
    this.name = User._normaliseName(name);
    this.email = User._normaliseEmail(email);
    this.passwordHash = passwordHash;
    this.role = User._normaliseRole(role);
    this.createdAt = createdAt || now();
    this.updatedAt = updatedAt || now();
  }

  // ── Normalisation helpers (private, static) ──────────────

  static _normaliseName(name) {
    if (typeof name !== "string") return name;
    // Trim whitespace, collapse internal spaces, title-case each word
    return name
      .trim()
      .replace(/\s+/g, " ")
      .replace(/\b\w/g, (c) => c.toUpperCase());
  }

  static _normaliseEmail(email) {
    if (typeof email !== "string") return email;
    return email.trim().toLowerCase();
  }

  static _normaliseRole(role) {
    const allowed = ["user", "admin"];
    const normalised = (role || "user").toString().trim().toLowerCase();
    return allowed.includes(normalised) ? normalised : "user";
  }

  // ── Factories ────────────────────────────────────────────

  /**
   * Build a new User from a validated UserCreateDto.
   *
   * @param {import('./user.dto').UserCreateDto} dto   – TypeBox-validated object
   * @param {(plain: string) => Promise<string>} hashPassword
   * @returns {Promise<User>}
   */
  static async fromCreateDto(dto, hashPassword) {
    const passwordHash = await hashPassword(dto.password);
    return new User({
      name: dto.name,
      email: dto.email,
      passwordHash,
      role: dto.role,
    });
  }

  /**
   * Reconstruct from a PostgreSQL row (snake_case columns).
   *
   * @param {object} row
   * @returns {User}
   */
  static fromRecord(row) {
    return new User({
      id: row.id,
      name: row.name,
      email: row.email,
      passwordHash: row.password_hash,
      role: row.role,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    });
  }

  // ── Domain behaviour ─────────────────────────────────────

  /**
   * Apply a validated UserUpdateDto onto this entity.
   * Only provided (non-undefined) fields are changed.
   *
   * @param {import('./user.dto').UserUpdateDto} dto
   * @param {(plain: string) => Promise<string>} [hashPassword]
   */
  async applyUpdate(dto, hashPassword) {
    if (dto.name !== undefined) this.name = User._normaliseName(dto.name);
    if (dto.role !== undefined) this.role = User._normaliseRole(dto.role);
    if (dto.password !== undefined && hashPassword) {
      this.passwordHash = await hashPassword(dto.password);
    }
    this.updatedAt = now();
  }

  /**
   * Verify a plaintext password against the stored hash.
   *
   * @param {string}   plain
   * @param {Function} comparePassword  bcrypt.compare or equivalent
   */
  async verifyPassword(plain, comparePassword) {
    return comparePassword(plain, this.passwordHash);
  }

  // ── Serialisation ────────────────────────────────────────

  /**
   * Convert to snake_case record for persistence.
   */
  toRecord() {
    return {
      id: this.id,
      name: this.name,
      email: this.email,
      password_hash: this.passwordHash,
      role: this.role,
      created_at: this.createdAt,
      updated_at: this.updatedAt,
    };
  }

  /**
   * Safe public representation – no sensitive fields.
   * Matches the shape of UserResponseDto.
   */
  toResponse() {
    return {
      id: this.id,
      name: this.name,
      email: this.email,
      role: this.role,
      createdAt: this.createdAt.toISOString(),
      updatedAt: this.updatedAt.toISOString(),
    };
  }
}

module.exports = { User };
