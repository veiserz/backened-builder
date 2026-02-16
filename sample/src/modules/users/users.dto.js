const Joi = require('joi');

const createUsersDto = Joi.object({
  title: Joi.string().required().min(3).max(100),
  description: Joi.string().optional().max(500),
  isActive: Joi.boolean().optional()
});

const updateUsersDto = Joi.object({
  title: Joi.string().optional().min(3).max(100),
  description: Joi.string().optional().max(500),
  isActive: Joi.boolean().optional()
});

module.exports = {
  createUsersDto,
  updateUsersDto
};
