const usersService = require('./users.service');
const ApiResponse = require('../../common/utils/response');

class UsersController {
  async getAll(req, res, next) {
    try {
      const filters = req.query.filters || {};
      const options = {
        page: parseInt(req.query.page) || 1,
        limit: parseInt(req.query.limit) || 10,
        sort: req.query.sort || '-createdAt'
      };

      const result = await usersService.getAll(filters, options);
      ApiResponse.success(res, result);
    } catch (error) {
      next(error);
    }
  }

  async getById(req, res, next) {
    try {
      const data = await usersService.getById(req.params.id);
      ApiResponse.success(res, data);
    } catch (error) {
      next(error);
    }
  }

  async create(req, res, next) {
    try {
      const data = await usersService.create(req.body);
      ApiResponse.created(res, data, 'Users created successfully');
    } catch (error) {
      next(error);
    }
  }

  async update(req, res, next) {
    try {
      const data = await usersService.update(req.params.id, req.body);
      ApiResponse.success(res, data, 'Users updated successfully');
    } catch (error) {
      next(error);
    }
  }

  async delete(req, res, next) {
    try {
      await usersService.delete(req.params.id);
      ApiResponse.success(res, null, 'Users deleted successfully');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new UsersController();
