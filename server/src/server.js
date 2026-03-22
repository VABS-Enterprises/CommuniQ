require('dotenv').config();
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const sessionRoutes = require('./routes/sessions');
const scenarioRoutes = require('./routes/scenarios');
const leaderboardRoutes = require('./routes/leaderboard');
const userRoutes = require('./routes/user');

const app = express();

app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => res.status(200).json({ status: 'ok' }));

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
app.listen(PORT, () => {
  console.log(`CommuniQ backend running on port ${PORT}`);
});

module.exports = app;
