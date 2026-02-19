'use strict';

const { validate }        = require('../../../shared/validation/validate');
const { DomainError }     = require('../../../shared/errors/domainError');
const { UserCreateSchema }= require('../dtos/user.create.dto');
const { dtoToEntity, entityToResponse } = require('../mappers/user.mapper');

class UsersService {
  /**
   * @param {import('../user.repository').UserRepository} userRepository
   * @param {import('../../../app/dispatch').Dispatcher} dispatcher
   */
  constructor(userRepository, dispatcher) {
    this._repo       = userRepository;
    this._dispatcher = dispatcher;
  }

  async createUser(rawDto) {
    const dto = validate(UserCreateSchema, rawDto);

    const existing = await this._repo.findByEmail(dto.email);
    if (existing) throw DomainError.conflict('Email is already registered');

    const user    = await dtoToEntity(dto);
    const created = await this._repo.create(user);

    await this._dispatcher.dispatch('user.created', entityToResponse(created));

    return entityToResponse(created);
  }

  async getUserById(id) {
    const user = await this._repo.findById(id);
    return entityToResponse(user);
  }

  async listUsers({ page = 1, limit = 20 } = {}) {
    const offset = (page - 1) * limit;
    const [users, total] = await Promise.all([
      this._repo.findAll({ limit, offset }),
      this._repo.count(),
    ]);
    return {
      items: users.map(entityToResponse),
      total,
      page,
      limit,
    };
  }

  async updateUser(id, rawData) {
    // Fetch to ensure it exists (throws NOT_FOUND otherwise)
    await this._repo.findById(id);
    const updated = await this._repo.update(id, rawData);
    return entityToResponse(updated);
  }

  async deleteUser(id) {
    await this._repo.delete(id);
    await this._dispatcher.dispatch('user.deleted', { id });
  }
}

module.exports = { UsersService };
