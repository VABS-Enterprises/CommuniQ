require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const { db } = require('./config/firebase');
const { version } = require('../package.json');

const authRoutes = require('./routes/auth');
const sessionRoutes = require('./routes/sessions');
const scenarioRoutes = require('./routes/scenarios');
const leaderboardRoutes = require('./routes/leaderboard');
const userRoutes = require('./routes/user');

const app = express();

// Request logging: compact in dev, Apache combined format in production
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// CORS — open in development, restrict to ALLOWED_ORIGINS in production
const rawOrigins = process.env.ALLOWED_ORIGINS;
const allowedOrigins = rawOrigins ? rawOrigins.split(',').map((o) => o.trim()) : null;

app.use(
  cors({
    origin: (origin, callback) => {
      // Allow server-to-server calls and dev tools (no origin header)
      if (!allowedOrigins || !origin) return callback(null, true);
      if (allowedOrigins.includes(origin)) return callback(null, true);
      callback(new Error(`CORS: origin ${origin} not allowed`));
    },
  })
);

app.use(express.json({ limit: '512kb' }));

// Health check — includes Firestore connectivity and version
app.get('/health', async (req, res) => {
  try {
    // Use a lightweight listCollections check instead of a document read
    // to avoid cold-start Firestore latency on the health endpoint.
    await db.listCollections();
    res.status(200).json({ status: 'ok', version, firebase: 'connected' });
  } catch {
    res.status(503).json({ status: 'degraded', version, firebase: 'unreachable' });
  }
});

// Routes
app.use('/auth', authRoutes);
app.use('/sessions', sessionRoutes);
app.use('/scenarios', scenarioRoutes);
app.use('/leaderboard', leaderboardRoutes);
app.use('/user', userRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () => {
  console.log(`CommuniQ backend running on port ${PORT}`);
});

// Graceful shutdown — finish in-flight requests before exiting
function shutdown(signal) {
  console.log(`${signal} received — shutting down gracefully`);
  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
  // Force exit if still open after 10s
  setTimeout(() => {
    console.error('Graceful shutdown timed out — forcing exit');
    process.exit(1);
  }, 10_000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

module.exports = app;
