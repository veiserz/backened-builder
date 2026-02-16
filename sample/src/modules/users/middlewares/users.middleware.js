const usersRepository = require('../users.repository');

/**
 * Check if users exists
 */
const checkUsersExists = async (req, res, next) => {
  try {
    const id = req.params.id;
    const exists = await usersRepository.exists({ _id: id });

    if (!exists) {
      return res.status(404).json({
        success: false,
        message: 'Users not found'
      });
    }

    next();
  } catch (error) {
    next(error);
  }
};

/**
 * Check ownership (example)
 */
const checkOwnership = async (req, res, next) => {
  try {
    const item = await usersRepository.findById(req.params.id);

    // Example: check if user owns this resource
    // if (item.userId.toString() !== req.user.id) {
    //   return res.status(403).json({
    //     success: false,
    //     message: 'Access denied'
    //   });
    // }

    next();
  } catch (error) {
    next(error);
  }
};

module.exports = {
  checkUsersExists,
  checkOwnership
};
