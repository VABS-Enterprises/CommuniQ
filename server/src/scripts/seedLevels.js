require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { createScenario } = require('../services/firestoreService');

// The file is at the root of the project: D:\Bhumik\All Projects\CapStone(StartUp)\communiq\CommuniQ\communiq_levels.json
const LEVELS_PATH = path.join(__dirname, '..', '..', '..', 'communiq_levels.json');

async function seed() {
  console.log('🌱 Starting levels seed...');
  
  if (!fs.existsSync(LEVELS_PATH)) {
    console.error(`❌ Levels file not found at ${LEVELS_PATH}`);
    process.exit(1);
  }

  const rawData = fs.readFileSync(LEVELS_PATH, 'utf8');
  const data = JSON.parse(rawData);
  const levels = data.levels;
  
  console.log(`📊 Found ${levels.length} levels to seed.`);

  let seededCount = 0;

  for (const level of levels) {
    for (const stage of level.stages) {
      const scenarioId = `level_${level.id}_stage_${stage.stage}`;
      const difficultyMap = { 'Easy': 1, 'Medium': 3, 'Hard': 5 };
      
      const scenarioData = {
        scenarioId,
        title: `${level.title} (Stage ${stage.stage})`,
        description: stage.scenario,
        type: level.category.toLowerCase(),
        difficulty: difficultyMap[stage.difficulty] || 1,
        systemPrompt: stage.prompt,
        requiredLevel: Math.ceil(level.id / 10), // e.g. level 1-10 requires user level 1, 11-20 requires user level 2...
        tags: [level.category, `Stage ${stage.stage}`],
      };

      try {
        await createScenario(scenarioData);
        seededCount++;
        if (seededCount % 10 === 0) {
          console.log(`✅ Seeded ${seededCount} scenarios...`);
        }
      } catch (err) {
        console.error(`❌ Failed to seed level ${level.id} stage ${stage.stage}:`, err.message);
      }
    }
  }

  console.log(`✨ Seed complete! Total seeded: ${seededCount}`);
  process.exit(0);
}

seed();
