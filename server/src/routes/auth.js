const router = require('express').Router();
const rateLimit = require('express-rate-limit');
const { register, login, me, deleteAccount } = require('../controllers/authController');
const { verifyToken } = require('../middleware/auth');

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20,
  message: { error: 'Too many auth requests, please try again later' },
});

router.post('/register', authLimiter, register);
router.post('/login', authLimiter, login);
router.get('/me', verifyToken, me);
router.delete('/account', verifyToken, deleteAccount);

module.exports = router;
