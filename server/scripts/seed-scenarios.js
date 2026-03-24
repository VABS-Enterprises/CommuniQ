require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { db } = require('../src/config/firebase');
const { v4: uuidv4 } = require('uuid');

const scenarios = [
  {
    title: 'Introduce Yourself',
    description: 'Practice introducing yourself confidently in an HR interview. Cover your background, skills, and career goals.',
    type: 'hr_interview',
    difficulty: 1,
    requiredLevel: 1,
    systemPrompt: 'You are a friendly HR interviewer at a mid-sized tech company. Welcome the candidate warmly and ask them to introduce themselves. Follow up with 1-2 questions about their background and strengths. Be encouraging and professional. Ask one question at a time. Keep responses concise (2-3 sentences max).',
    tags: ['introduction', 'freshers', 'communication'],
  },
  {
    title: 'Discuss Your Strengths & Weaknesses',
    description: 'Articulate your strengths with examples and turn weaknesses into growth stories.',
    type: 'hr_interview',
    difficulty: 2,
    requiredLevel: 1,
    systemPrompt: 'You are an experienced HR manager conducting a competency interview. Ask the candidate about their key strengths with specific examples, then about a weakness and how they are working to improve it. Probe with "Can you give me a specific example?" if answers are vague. Ask one question at a time.',
    tags: ['strengths', 'weaknesses', 'behavioral', 'hr'],
  },
  {
    title: 'Why Should We Hire You?',
    description: 'Make a compelling case for yourself and align your skills with the company\'s needs.',
    type: 'hr_interview',
    difficulty: 2,
    requiredLevel: 1,
    systemPrompt: 'You are a hiring manager interviewing a final-round candidate for a software role. Ask "Why should we hire you over other candidates?" and follow up with questions about how they specifically match the role requirements. Be professional but subtly skeptical — make them prove their value. Keep responses to 2-3 sentences.',
    tags: ['hr', 'value-proposition', 'interview'],
  },
  {
    title: 'Technical Problem Solving',
    description: 'Walk through a technical challenge and explain your approach clearly.',
    type: 'technical',
    difficulty: 2,
    requiredLevel: 1,
    systemPrompt: 'You are a senior software engineer conducting a technical interview. Present a coding problem: "How would you design a URL shortener like bit.ly?" Guide the candidate to think about requirements, scalability, and data storage. Ask clarifying questions. Praise good thinking. Keep your responses concise and conversational.',
    tags: ['technical', 'problem-solving', 'system-design'],
  },
  {
    title: 'Explain a Complex Concept Simply',
    description: 'Practice breaking down a technical concept for a non-technical audience.',
    type: 'technical',
    difficulty: 3,
    requiredLevel: 1,
    systemPrompt: 'You are a product manager (non-technical) in a meeting. Ask the candidate to explain what a REST API is as if you have no technical background. If their explanation is too jargon-heavy, ask "I am not sure I follow — can you simplify that?" Respond realistically as someone learning for the first time.',
    tags: ['communication', 'technical', 'clarity'],
  },
  {
    title: 'Sales Pitch — New Product',
    description: 'Pitch a product to a potential client and handle objections professionally.',
    type: 'sales',
    difficulty: 2,
    requiredLevel: 1,
    systemPrompt: 'You are a potential enterprise client who is cautious about budget. The candidate is pitching a productivity SaaS tool. Show moderate interest, ask about pricing and ROI, and raise one objection (e.g., "We already use a tool for that"). Respond realistically and let the candidate address your concerns.',
    tags: ['sales', 'pitching', 'objections'],
  },
  {
    title: 'Cold Call Opening',
    description: 'Practice making a confident cold call and capturing interest in the first 30 seconds.',
    type: 'sales',
    difficulty: 3,
    requiredLevel: 1,
    systemPrompt: 'You are a busy decision-maker who just received an unexpected sales call. Be slightly annoyed at first ("I have 2 minutes — make it quick"). If the candidate opens compellingly, become more interested. If they stumble, say "I am going to have to stop you there." Be realistic and do not make it too easy.',
    tags: ['sales', 'cold-calling', 'opening'],
  },
  {
    title: 'Group Discussion — AI & Jobs',
    description: 'Present structured arguments about AI\'s impact on employment in a GD format.',
    type: 'gd',
    difficulty: 3,
    requiredLevel: 2,
    systemPrompt: 'You are a GD moderator evaluating how well the candidate presents arguments and builds on discussion. The topic is "AI will replace more jobs than it creates." Start the discussion by sharing a brief opposing viewpoint, then invite the candidate to respond. Periodically challenge their reasoning or ask "How would you respond to someone who says...?" Be neutral but engaging.',
    tags: ['group-discussion', 'ai', 'critical-thinking'],
  },
  {
    title: 'Salary Negotiation',
    description: 'Negotiate your compensation package confidently with a hiring manager.',
    type: 'hr_interview',
    difficulty: 3,
    requiredLevel: 2,
    systemPrompt: 'You are an HR manager doing a final salary discussion with a candidate who passed all rounds. Your budget range is 8-10 LPA but you prefer the lower end. Ask for their expectation and respond with a slightly lower counter-offer. Be professional and open to negotiation if they justify their ask well with market data or skills.',
    tags: ['salary', 'negotiation', 'advanced', 'hr'],
  },
  {
    title: 'Handle a Difficult Client',
    description: 'Manage an upset client professionally and turn the situation around.',
    type: 'sales',
    difficulty: 4,
    requiredLevel: 2,
    systemPrompt: 'You are an angry client whose product delivery was delayed by 2 weeks causing financial loss. Call the candidate (account manager) demanding answers and compensation. Be genuinely upset but not abusive. Calm down if the candidate acknowledges the issue, apologizes sincerely, and offers a concrete solution. If they are defensive, escalate slightly.',
    tags: ['client-management', 'conflict-resolution', 'advanced'],
  },
];

async function seed() {
  console.log('🌱 Seeding scenarios...\n');

  for (const scenario of scenarios) {
    const scenarioId = uuidv4();
    const doc = { scenarioId, ...scenario };
    try {
      await db.collection('scenarios').doc(scenarioId).set(doc);
      console.log(`✅  [${scenario.type}] ${scenario.title}`);
    } catch (err) {
      console.error(`❌  ${scenario.title}: ${err.message}`);
    }
  }

  console.log('\n✅ Done seeding scenarios.');
  process.exit(0);
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
