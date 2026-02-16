const express = require("express");
const AuthController = require("./auth.controller");
const AuthMiddleware = require("./middlewares/auth.middleware");
const dto = require("./auth.dto");

class Auth {
  constructor() {
    this.router = express.Router();
    this.controller = new AuthController();
    this.middleware = new AuthMiddleware(); // فقط یک middleware
    this.initializeRoutes();
  }

  initializeRoutes() {
    // Get all auths
    this.router.get("/", this.controller.getAll.bind(this.controller));

    // Get auth by id
    this.router.get(
      "/:id",
      this.middleware.checkAuthExists.bind(this.middleware), // متد module
      this.controller.getById.bind(this.controller),
    );

    // Create new auth
    this.router.post(
      "/",
      this.middleware.validate(dto.create).bind(this.middleware), // متد common
      this.controller.create.bind(this.controller),
    );

    // Update auth
    this.router.put(
      "/:id",
      this.middleware.checkAuthExists.bind(this.middleware), // متد module
      this.middleware.validate(dto.update).bind(this.middleware), // متد common
      this.controller.update.bind(this.controller),
    );

    // Delete auth
    this.router.delete(
      "/:id",
      this.middleware.checkAuthExists.bind(this.middleware), // متد module
      this.controller.delete.bind(this.controller),
    );
  }

  getRouter() {
    return this.router;
  }
}

module.exports = Auth;
