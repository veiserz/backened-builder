'use strict';

const { Store } = require('../models');

class StoreService {
  /**
   * @param {import('../repository').StoreRepository} repository
   * @param {import('../../../app/dispatch').Dispatcher}  dispatcher
   */
  constructor(repository, dispatcher) {
    this._repo       = repository;
    this._dispatcher = dispatcher;
  }

  async create(dto) {
    const entity  = new Store(dto);
    const created = await this._repo.create(entity);
    await this._dispatcher.dispatch('store.created', created.toResponse());
    return created.toResponse();
  }

  async getById(id) {
    const entity = await this._repo.findById(id);
    return entity.toResponse();
  }

  async list({ page = 1, limit = 20 } = {}) {
    const offset = (page - 1) * limit;
    const [items, total] = await Promise.all([
      this._repo.findAll({ limit, offset }),
      this._repo.count(),
    ]);
    return { items: items.map((e) => e.toResponse()), total, page, limit };
  }

  async update(id, dto) {
    const entity  = await this._repo.findById(id);
    entity.applyUpdate(dto);
    const updated = await this._repo.update(id, { name: entity.name });
    return updated.toResponse();
  }

  async delete(id) {
    await this._repo.delete(id);
    await this._dispatcher.dispatch('store.deleted', { id });
  }
}

module.exports = { StoreService };
