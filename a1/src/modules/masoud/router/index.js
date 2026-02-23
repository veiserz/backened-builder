'use strict';

const { Router }         = require('express');
const ctrl               = require('../controller');
const { validate }       = require('../DTO/validate');
const { authMiddleware } = require('../../../http/middlewares');
const {
  CreateMasoudDto,
  UpdateMasoudDto,
  MasoudParamDto,
  MasoudListQueryDto,
} = require('../DTO');

const router = Router();

// ── Public ───────────────────────────────────────────────────
router.post('/',
  validate(CreateMasoudDto, 'body'),
  ctrl.create);

// ── Protected ────────────────────────────────────────────────
router.use(authMiddleware);

router.get('/',
  validate(MasoudListQueryDto, 'query'),
  ctrl.list);

router.get('/:id',
  validate(MasoudParamDto, 'params'),
  ctrl.getById);

router.patch('/:id',
  validate(MasoudParamDto, 'params'),
  validate(UpdateMasoudDto, 'body'),
  ctrl.update);

router.delete('/:id',
  validate(MasoudParamDto, 'params'),
  ctrl.remove);

module.exports = router;
