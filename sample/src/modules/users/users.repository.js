const UsersModel = require('./users.model');

class UsersRepository {
  async findAll(filters = {}, options = {}) {
    const { page = 1, limit = 10, sort = '-createdAt' } = options;
    const skip = (page - 1) * limit;

    const items = await UsersModel
      .find(filters)
      .sort(sort)
      .skip(skip)
      .limit(limit);

    const total = await UsersModel.countDocuments(filters);

    return {
      items,
      pagination: {
        total,
        page,
        limit,
        pages: Math.ceil(total / limit)
      }
    };
  }

  async findById(id) {
    return await UsersModel.findById(id);
  }

  async findOne(conditions) {
    return await UsersModel.findOne(conditions);
  }

  async create(data) {
    const item = new UsersModel(data);
    return await item.save();
  }

  async update(id, data) {
    return await UsersModel.findByIdAndUpdate(
      id,
      { $set: data },
      { new: true, runValidators: true }
    );
  }

  async delete(id) {
    return await UsersModel.findByIdAndDelete(id);
  }

  async exists(conditions) {
    return await UsersModel.exists(conditions);
  }
}

module.exports = new UsersRepository();
