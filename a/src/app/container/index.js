'use strict';

/**
 * Lightweight synchronous DI container.
 *
 *   container.register(token, factory)   – transient (new instance per resolve)
 *   container.singleton(token, factory)  – single shared instance
 *   container.instance(token, value)     – register a pre-built value
 *   container.resolve(token)             – retrieve / construct
 */
class Container {
  constructor() {
    this._bindings   = new Map();
    this._singletons = new Map();
  }

  register(token, factory) {
    this._bindings.set(token, { factory, scope: 'transient' });
    return this;
  }

  singleton(token, factory) {
    this._bindings.set(token, { factory, scope: 'singleton' });
    return this;
  }

  instance(token, value) {
    this._singletons.set(token, value);
    this._bindings.set(token, { factory: () => value, scope: 'singleton' });
    return this;
  }

  resolve(token) {
    if (!this._bindings.has(token)) {
      throw new Error(`[Container] No binding registered for token: "${token}"`);
    }

    const binding = this._bindings.get(token);

    if (binding.scope === 'singleton') {
      if (!this._singletons.has(token)) {
        this._singletons.set(token, binding.factory(this));
      }
      return this._singletons.get(token);
    }

    return binding.factory(this);
  }

  /** Verify all registered singletons can be constructed. */
  verify() {
    for (const [token, binding] of this._bindings) {
      if (binding.scope === 'singleton') {
        this.resolve(token);
      }
    }
  }
}

const container = new Container();

function bootContainer() {
  require('./providers').register(container);
  return container;
}

module.exports = { Container, container, bootContainer };
