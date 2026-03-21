const router = require('express').Router();
const { verifyToken } = require('../middleware/auth');
const { updateProfile } = require('../controllers/userController');

router.patch('/profile', verifyToken, updateProfile);

module.exports = router;
