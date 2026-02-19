'use strict';

const { Router }        = require('express');
const ctrl              = require('../controllers/users.controller');
const { validateUserId }= require('../middlewares/users.middleware');
const authMiddleware    = require('../../../http/middlewares/auth');

const router = Router();

// Public
router.post('/',    ctrl.createUser);

// Protected
router.use(authMiddleware);
router.get('/',              ctrl.listUsers);
router.get('/:id',  validateUserId, ctrl.getUser);
router.patch('/:id',validateUserId, ctrl.updateUser);
router.delete('/:id',validateUserId, ctrl.deleteUser);

module.exports = router;
