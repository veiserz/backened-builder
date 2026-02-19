project-root/
.gitignore
module.sh
package.json
README.md

src/
bootstrap/
app.js
server.js
router.js

    http/
      index.js
      middlewares/
        index.js
        auth.js
        rateLimit.js
        requestContext.js
      response/
        index.js
      errors/
        index.js
        httpError.js
        mapper.js

    app/
      index.js
      config/
        index.js
        features.js
        policies.js
      container/
        index.js
        providers.js
      dispatch/
        index.js
        handlers.js

    infrastructure/
      index.js
      env/
        index.js
        validateEnv.js
      logger/
        index.js

      database/
        postgresql/
          index.js
          connection.js
          db.js
          migrations/
          seeds/
      cache/
        redis/
          index.js
          connection.js
          client.js

      queue/
        index.js
        client.js
        producer.js
        consumer.js

      eventbus/
        index.js
        bus.js

    modules/
      users/
        index.js                 # public API of module
        routes/
          index.js
        controllers/
          users.controller.js
        services/
          users.service.js
        domain/
          entities/
            user.entity.js
          value-objects/
          rules/
        repositories/
          user.repository.js     # interface/port
        infrastructure/
          user.pg.repository.js  # adapter (postgres impl)
        dtos/
          user.create.dto.js
          user.response.dto.js
        middlewares/
          users.middleware.js
        mappers/
          user.mapper.js

      # other modules follow same template...

    shared/
      index.js
      errors/
        index.js
        domainError.js
      utils/
        index.js
        id.js
        time.js
      validation/
        index.js
        validate.js

tests/
unit/
integration/
e2e/
