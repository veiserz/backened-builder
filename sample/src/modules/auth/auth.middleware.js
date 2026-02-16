const AuthRepository = require("./auth.repository");
const CommonMiddleware = require("../../common/middlewares/common.middleware");

class AuthMiddleware extends CommonMiddleware {
  constructor() {
    super();
    this.repository = AuthRepository;
  }

  async checkAuthExists(req, res, next) {
    try {
      const id = req.params.id;
      const exists = await this.repository.exists({ _id: id });

      if (!exists) {
        return res.status(404).json({
          success: false,
          message: "Auth not found",
        });
      }

      next();
    } catch (error) {
      next(error);
    }
  }

  async checkOwnership(req, res, next) {
    try {
      const item = await this.repository.findById(req.params.id);
      next();
    } catch (error) {
      next(error);
    }
  }
}

module.exports = AuthMiddleware;
