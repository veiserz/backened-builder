'use strict';

const { Store }   = require('../models');
const { QUERIES }     = require('./queries');
const { DomainError } = require('../../../shared/errors/domainError');
const { now }         = require('../../../shared/utils/time');

class StoreRepository {
  /** @param {{ query: Function }} db  pg pool wrapper */
  constructor(db) {
    this._db = db;
  }

  async findById(id) {
    const res = await this._db.query(QUERIES.FIND_BY_ID, [id]);
    if (!res.rows.length) throw DomainError.notFound('Store not found');
    return Store.fromRecord(res.rows[0]);
  }

  async findAll({ limit, offset }) {
    const res = await this._db.query(QUERIES.FIND_ALL, [limit, offset]);
    return res.rows.map((r) => Store.fromRecord(r));
  }

  async count() {
    const res = await this._db.query(QUERIES.COUNT);
    return res.rows[0].total;
  }

  async create(entity) {
    const r   = entity.toRecord();
    const res = await this._db.query(QUERIES.CREATE, [r.id, r.name, r.created_at, r.updated_at]);
    return Store.fromRecord(res.rows[0]);
  }

  async update(id, { name = null }) {
    const res = await this._db.query(QUERIES.UPDATE, [name, now(), id]);
    if (!res.rows.length) throw DomainError.notFound('Store not found');
    return Store.fromRecord(res.rows[0]);
  }

  async delete(id) {
    await this._db.query(QUERIES.DELETE, [id]);
  }
}

module.exports = { StoreRepository };
