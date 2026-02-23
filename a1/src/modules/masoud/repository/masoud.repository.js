'use strict';

const { Masoud }   = require('../models');
const { QUERIES }     = require('./queries');
const { DomainError } = require('../../../shared/errors/domainError');
const { now }         = require('../../../shared/utils/time');

class MasoudRepository {
  /** @param {{ query: Function }} db  pg pool wrapper */
  constructor(db) {
    this._db = db;
  }

  async findById(id) {
    const res = await this._db.query(QUERIES.FIND_BY_ID, [id]);
    if (!res.rows.length) throw DomainError.notFound('Masoud not found');
    return Masoud.fromRecord(res.rows[0]);
  }

  async findAll({ limit, offset }) {
    const res = await this._db.query(QUERIES.FIND_ALL, [limit, offset]);
    return res.rows.map((r) => Masoud.fromRecord(r));
  }

  async count() {
    const res = await this._db.query(QUERIES.COUNT);
    return res.rows[0].total;
  }

  async create(entity) {
    const r   = entity.toRecord();
    const res = await this._db.query(QUERIES.CREATE, [r.id, r.name, r.created_at, r.updated_at]);
    return Masoud.fromRecord(res.rows[0]);
  }

  async update(id, { name = null }) {
    const res = await this._db.query(QUERIES.UPDATE, [name, now(), id]);
    if (!res.rows.length) throw DomainError.notFound('Masoud not found');
    return Masoud.fromRecord(res.rows[0]);
  }

  async delete(id) {
    await this._db.query(QUERIES.DELETE, [id]);
  }
}

module.exports = { MasoudRepository };
