const authService = require('./auth.service');
const ApiResponse = require('../../common/utils/response');

class AuthController {
  async getAll(req, res, next) {
    try {
      const filters = req.query.filters || {};
      const options = {
        page: parseInt(req.query.page) || 1,
        limit: parseInt(req.query.limit) || 10,
        sort: req.query.sort || '-createdAt'
      };

      const result = await authService.getAll(filters, options);
      ApiResponse.success(res, result);
    } catch (error) {
      next(error);
    }
  }

  async getById(req, res, next) {
    try {
      const data = await authService.getById(req.params.id);
      ApiResponse.success(res, data);
    } catch (error) {
      next(error);
    }
  }

  async create(req, res, next) {
    try {
      const data = await authService.create(req.body);
      ApiResponse.created(res, data, 'Auth created successfully');
    } catch (error) {
      next(error);
    }
  }

  async update(req, res, next) {
    try {
      const data = await authService.update(req.params.id, req.body);
      ApiResponse.success(res, data, 'Auth updated successfully');
    } catch (error) {
      next(error);
    }
  }

  async delete(req, res, next) {
    try {
      await authService.delete(req.params.id);
      ApiResponse.success(res, null, 'Auth deleted successfully');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AuthController();
