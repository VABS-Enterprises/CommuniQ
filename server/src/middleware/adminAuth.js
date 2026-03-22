function adminAuth(req, res, next) {
  const secret = req.headers['x-admin-secret'];

  if (!process.env.ADMIN_SECRET) {
    console.error('ADMIN_SECRET is not set in .env');
    return res.status(500).json({ error: 'Admin routes are not configured' });
  }

  if (!secret || secret !== process.env.ADMIN_SECRET) {
    return res.status(403).json({ error: 'Invalid or missing admin secret' });
  }

  next();
}

module.exports = { adminAuth };
