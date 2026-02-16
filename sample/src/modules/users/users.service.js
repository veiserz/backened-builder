const usersRepository = require('./users.repository');

class UsersService {
  async getAll(filters = {}, options = {}) {
    return await usersRepository.findAll(filters, options);
  }

  async getById(id) {
    const item = await usersRepository.findById(id);
    if (!item) {
      const error = new Error('Users not found');
      error.statusCode = 404;
      throw error;
    }
    return item;
  }

  async create(data) {
    // Business logic here (e.g., check duplicates)
    const exists = await usersRepository.exists({ title: data.title });
    if (exists) {
      const error = new Error('Users with this title already exists');
      error.statusCode = 409;
      throw error;
    }

    return await usersRepository.create(data);
  }

  async update(id, data) {
    const item = await usersRepository.update(id, data);
    if (!item) {
      const error = new Error('Users not found');
      error.statusCode = 404;
      throw error;
    }
    return item;
  }

  async delete(id) {
    const item = await usersRepository.delete(id);
    if (!item) {
      const error = new Error('Users not found');
      error.statusCode = 404;
      throw error;
    }
    return item;
  }
}

module.exports = new UsersService();
