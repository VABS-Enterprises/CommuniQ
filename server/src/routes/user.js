const router = require('express').Router();
const { verifyToken } = require('../middleware/auth');
const { getProfile, updateProfile } = require('../controllers/userController');

router.get('/profile', verifyToken, getProfile);
router.patch('/profile', verifyToken, updateProfile);

module.exports = router;
