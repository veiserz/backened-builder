// src/app/container/index.js
"use strict";

class ContainerError extends Error {
  constructor(message) {
    super(message);
    this.name = "ContainerError";
  }
}

/**
 * Lightweight synchronous/async DI container.
 *
 *   container.register(token, factory)   – transient (new instance per resolve)
 *   container.singleton(token, factory)  – lazy singleton
 *   container.instance(token, value)     – pre-built value
 *   container.resolve(token)             – sync resolve
 *   container.resolveAsync(token)        – async resolve (handles async factories)
 *   container.verify()                   – eagerly build all singletons (startup check)
 *   container.verifyAsync()              – same but awaits async factories
 *
 * Tokens may be strings or Symbols.
 * Duplicate registrations are rejected with a clear error.
 * Circular dependencies surface immediately with a full chain trace.
 */
class Container {
  constructor() {
    /** @type {Map<string|symbol, { factory: Function, scope: 'transient'|'singleton' }>} */
    this._bindings = new Map();
    /** @type {Map<string|symbol, any>} */
    this._singletons = new Map();
    /** Tracks tokens currently being resolved — catches sync circular deps. */
    this._resolving = new Set();
  }

  // ── Registration ──────────────────────────────────────────────────────────

  /** Transient: a fresh instance on every resolve(). */
  register(token, factory) {
    this._guardDuplicate(token);
    this._assertFactory(token, factory);
    this._bindings.set(token, { factory, scope: "transient" });
    return this;
  }

  /** Singleton: constructed once, then cached. */
  singleton(token, factory) {
    this._guardDuplicate(token);
    this._assertFactory(token, factory);
    this._bindings.set(token, { factory, scope: "singleton" });
    return this;
  }

  /** Pre-built value: treated as a singleton without a factory call. */
  instance(token, value) {
    this._guardDuplicate(token);
    this._singletons.set(token, value);
    this._bindings.set(token, { factory: () => value, scope: "singleton" });
    return this;
  }

  // ── Resolution ────────────────────────────────────────────────────────────

  /**
   * Synchronously resolve a token.
   * Throws a ContainerError if the factory returns a Promise — use resolveAsync().
   * @param {string|symbol} token
   * @returns {any}
   */
  resolve(token) {
    const value = this._resolveSync(token, []);
    if (value != null && typeof value.then === "function") {
      throw new ContainerError(
        `[Container] "${this._name(token)}" has an async factory — ` +
          `call resolveAsync() or verifyAsync() instead.`,
      );
    }
    return value;
  }

  /**
   * Asynchronously resolve a token.
   * Works for both sync and async factories.
   * @param {string|symbol} token
   * @returns {Promise<any>}
   */
  async resolveAsync(token) {
    return this._resolveAsync(token, []);
  }

  /**
   * Eagerly construct every registered singleton.
   * Call once after all bindings are registered to surface wiring errors at startup.
   */
  verify() {
    for (const [token, binding] of this._bindings) {
      if (binding.scope === "singleton") {
        this.resolve(token);
      }
    }
  }

  /** Same as verify() but awaits async factories. */
  async verifyAsync() {
    for (const [token, binding] of this._bindings) {
      if (binding.scope === "singleton") {
        await this._resolveAsync(token, []);
      }
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  _resolveSync(token, chain) {
    this._assertRegistered(token, chain);
    this._detectCycle(token, chain);

    const binding = this._bindings.get(token);

    if (binding.scope === "singleton" && this._singletons.has(token)) {
      return this._singletons.get(token);
    }

    this._resolving.add(token);
    try {
      const resolver = this._makeResolver(chain.concat(token));
      const value = binding.factory(resolver);
      if (binding.scope === "singleton") {
        this._singletons.set(token, value);
      }
      return value;
    } finally {
      this._resolving.delete(token);
    }
  }

  async _resolveAsync(token, chain) {
    this._assertRegistered(token, chain);
    this._detectCycle(token, chain);

    const binding = this._bindings.get(token);

    if (binding.scope === "singleton" && this._singletons.has(token)) {
      return this._singletons.get(token);
    }

    this._resolving.add(token);
    try {
      const resolver = this._makeResolver(chain.concat(token));
      const value = await Promise.resolve(binding.factory(resolver));
      if (binding.scope === "singleton") {
        this._singletons.set(token, value);
      }
      return value;
    } finally {
      this._resolving.delete(token);
    }
  }

  /**
   * The resolver object passed into every factory.
   * It carries the current dependency chain so errors include a full trace.
   */
  _makeResolver(chain) {
    return {
      resolve: (token) => this._resolveSync(token, chain),
      resolveAsync: (token) => this._resolveAsync(token, chain),
    };
  }

  _assertRegistered(token, chain) {
    if (!this._bindings.has(token)) {
      const trace =
        chain.length > 0
          ? ` (while resolving: ${chain.map(this._name).join(" → ")} → ${this._name(token)})`
          : "";
      throw new ContainerError(
        `[Container] No binding found for token: "${this._name(token)}"${trace}`,
      );
    }
  }

  _detectCycle(token, chain) {
    if (this._resolving.has(token)) {
      const cycle = [...chain.map(this._name), this._name(token)].join(" → ");
      throw new ContainerError(
        `[Container] Circular dependency detected: ${cycle}`,
      );
    }
  }

  _guardDuplicate(token) {
    if (this._bindings.has(token)) {
      throw new ContainerError(
        `[Container] Token "${this._name(token)}" is already registered. ` +
          `Remove the duplicate or use a distinct token.`,
      );
    }
  }

  _assertFactory(token, factory) {
    if (typeof factory !== "function") {
      throw new ContainerError(
        `[Container] Factory for "${this._name(token)}" must be a function, got ${typeof factory}.`,
      );
    }
  }

  /** Safe display name for strings and Symbols. */
  _name(token) {
    return typeof token === "symbol" ? token.toString() : String(token);
  }
}

module.exports = { Container, ContainerError };
