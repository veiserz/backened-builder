const express = require('express');
const router = express.Router();
const controller = require('./users.controller');
const { authenticate } = require('../../common/middlewares/auth');
const validate = require('../../common/middlewares/validate');
const { checkUsersExists } = require('./middlewares/users.middleware');
const { createUsersDto, updateUsersDto } = require('./users.dto');

// Routes
router.get('/', controller.getAll);
router.get('/:id', checkUsersExists, controller.getById);
router.post('/', validate(createUsersDto), controller.create);
router.put('/:id', checkUsersExists, validate(updateUsersDto), controller.update);
router.delete('/:id', checkUsersExists, controller.delete);

module.exports = router;
