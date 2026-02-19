'use strict';

const { UsersService }    = require('../../src/modules/users/users.service');
const { DomainError }     = require('../../src/shared/errors/domainError');

const makeRepo = (overrides = {}) => ({
  findByEmail: jest.fn().mockResolvedValue(null),
  create:      jest.fn().mockImplementation(async (u) => u),
  findById:    jest.fn(),
  findAll:     jest.fn().mockResolvedValue([]),
  count:       jest.fn().mockResolvedValue(0),
  update:      jest.fn(),
  delete:      jest.fn(),
  ...overrides,
});

const makeDispatcher = () => ({
  dispatch: jest.fn().mockResolvedValue(undefined),
});

describe('UsersService', () => {
  describe('createUser()', () => {
    it('creates a user with valid data', async () => {
      const svc = new UsersService(makeRepo(), makeDispatcher());
      const res = await svc.createUser({ name: 'Alice', email: 'alice@example.com', password: 'Passw0rd!' });
      expect(res).toHaveProperty('email', 'alice@example.com');
      expect(res).not.toHaveProperty('passwordHash');
    });

    it('throws CONFLICT when email already taken', async () => {
      const repo = makeRepo({ findByEmail: jest.fn().mockResolvedValue({ id: 'x' }) });
      const svc  = new UsersService(repo, makeDispatcher());
      await expect(
        svc.createUser({ name: 'Bob', email: 'taken@example.com', password: 'Passw0rd!' })
      ).rejects.toMatchObject({ code: 'CONFLICT' });
    });

    it('throws VALIDATION with invalid email', async () => {
      const svc = new UsersService(makeRepo(), makeDispatcher());
      await expect(
        svc.createUser({ name: 'Eve', email: 'not-an-email', password: 'Passw0rd!' })
      ).rejects.toMatchObject({ code: 'VALIDATION' });
    });
  });
});
