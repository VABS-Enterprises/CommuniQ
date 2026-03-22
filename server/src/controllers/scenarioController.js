const { getScenariosForLevel, getScenarioById, getUserById, createScenario } = require('../services/firestoreService');
const { stripSystemPrompt } = require('../models/scenarioModel');
const { v4: uuidv4 } = require('uuid');

const VALID_TYPES = ['hr_interview', 'gd', 'sales', 'technical'];

// GET /scenarios
async function listScenarios(req, res) {
  try {
    const user = await getUserById(req.uid);
    if (!user) return res.status(404).json({ error: 'User not found' });

    const scenarios = await getScenariosForLevel(user.level);
    return res.status(200).json({ scenarios });
  } catch (err) {
    console.error('listScenarios error:', err.message);
    return res.status(500).json({ error: 'Could not fetch scenarios' });
  }
}

// GET /scenarios/:scenarioId
async function getScenario(req, res) {
  const { scenarioId } = req.params;

  try {
    // Security2: fetch requesting user to enforce level gate on individual scenarios
    const [scenario, user] = await Promise.all([
      getScenarioById(scenarioId),
      getUserById(req.uid),
    ]);

    if (!scenario) return res.status(404).json({ error: 'Scenario not found' });
    if (!user) return res.status(404).json({ error: 'User not found' });

    if (user.level < scenario.requiredLevel) {
      return res.status(403).json({ error: `Scenario requires level ${scenario.requiredLevel}` });
    }

    return res.status(200).json({ scenario: stripSystemPrompt(scenario) });
  } catch (err) {
    console.error('getScenario error:', err.message);
    return res.status(500).json({ error: 'Could not fetch scenario' });
  }
}

// POST /scenarios  (admin only — protected by x-admin-secret header)
async function seedScenario(req, res) {
  const { title, description, type, difficulty, systemPrompt, requiredLevel, tags } = req.body;

  if (!title || !description || !type || !systemPrompt) {
    return res.status(400).json({ error: 'title, description, type, and systemPrompt are required' });
  }
  if (!VALID_TYPES.includes(type)) {
    return res.status(400).json({ error: `type must be one of: ${VALID_TYPES.join(', ')}` });
  }
  if (difficulty !== undefined && (difficulty < 1 || difficulty > 5)) {
    return res.status(400).json({ error: 'difficulty must be between 1 and 5' });
  }
  if (requiredLevel !== undefined && (requiredLevel < 1 || requiredLevel > 5)) {
    return res.status(400).json({ error: 'requiredLevel must be between 1 and 5' });
  }

  try {
    const scenarioId = uuidv4();
    const scenario = await createScenario({
      scenarioId,
      title,
      description,
      type,
      difficulty: difficulty ?? 1,
      systemPrompt,
      requiredLevel: requiredLevel ?? 1,
      tags: tags ?? [],
    });
    return res.status(201).json({ scenario });
  } catch (err) {
    console.error('seedScenario error:', err.message);
    return res.status(500).json({ error: 'Could not create scenario' });
  }
}

module.exports = { listScenarios, getScenario, seedScenario };
