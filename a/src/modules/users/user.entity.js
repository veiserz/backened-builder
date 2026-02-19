'use strict';

const bcrypt = require('bcryptjs');

class User {
  /**
   * @param {{
   *   id: string,
   *   name: string,
   *   email: string,
   *   passwordHash: string,
   *   role?: string,
   *   createdAt?: Date,
   *   updatedAt?: Date,
   * }} props
   */
  constructor({ id, name, email, passwordHash, role, createdAt, updatedAt }) {
    this.id           = id;
    this.name         = name;
    this.email        = email.toLowerCase().trim();
    this.passwordHash = passwordHash;
    this.role         = role         || 'user';
    this.createdAt    = createdAt    || new Date();
    this.updatedAt    = updatedAt    || new Date();
  }

  // ── Domain behaviour ─────────────────────────────────────

  async verifyPassword(plainText) {
    return bcrypt.compare(plainText, this.passwordHash);
  }

  promoteToAdmin() {
    this.role      = 'admin';
    this.updatedAt = new Date();
  }

  updateProfile({ name }) {
    if (name) this.name = name.trim();
    this.updatedAt = new Date();
  }

  toObject() {
    return {
      id:           this.id,
      name:         this.name,
      email:        this.email,
      passwordHash: this.passwordHash,
      role:         this.role,
      createdAt:    this.createdAt,
      updatedAt:    this.updatedAt,
    };
  }
}

module.exports = { User };
