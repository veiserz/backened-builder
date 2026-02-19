'use strict';

const { Router } = require('express');
const usersRouter = require('../modules/users/routes');

const router = Router();

router.use('/v1/users', usersRouter);

// Register additional module routers here:
// router.use('/v1/orders', require('../modules/orders/routes'));

module.exports = router;
