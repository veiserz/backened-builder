const qry = require("./auth.repository");
const pg = require("../../common/database/pg");

class AuthService {
  constructor() {
    this.db = pg;
  }

  async getAll(filters = {}, options = {}) {
    const query = this.db.Transaction(qry.findAll, filters, options);
    return await this.db.execute(query);
  }

  async getById(id) {
    const query = this.db.Transaction(qry.findById, id);
    const result = await this.db.execute(query);

    if (!result || result.length === 0) {
      const error = new Error("Auth not found");
      error.statusCode = 404;
      throw error;
    }
    return result[0];
  }

  async create(data) {
    // Check duplicates
    const existsQuery = this.db.Transaction(qry.exists, data.title);
    const exists = await this.db.execute(existsQuery);

    if (exists && exists.length > 0) {
      const error = new Error("Auth with this title already exists");
      error.statusCode = 409;
      throw error;
    }

    const createQuery = this.db.Transaction(qry.create, data);
    const result = await this.db.execute(createQuery);
    return result[0];
  }

  async update(id, data) {
    const query = this.db.Transaction(qry.update, id, data);
    const result = await this.db.execute(query);

    if (!result || result.length === 0) {
      const error = new Error("Auth not found");
      error.statusCode = 404;
      throw error;
    }
    return result[0];
  }

  async delete(id) {
    const query = this.db.Transaction(qry.delete, id);
    const result = await this.db.execute(query);

    if (!result || result.length === 0) {
      const error = new Error("Auth not found");
      error.statusCode = 404;
      throw error;
    }
    return result[0];
  }
}

module.exports = new AuthService();
