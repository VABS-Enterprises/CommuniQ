/*
 * Firestore shape — scenarios/{scenarioId}
 * ──────────────────────────────────────────
 * scenarioId     string
 * title          string   e.g. "HR Interview — Freshers"
 * description    string
 * type           string   "hr_interview" | "gd" | "sales" | "technical"
 * difficulty     number   1–5
 * systemPrompt   string   LLM persona prompt — NEVER sent to Flutter
 * requiredLevel  number   user.level must be >= this to unlock
 * tags           string[]
 *
 * NOTE: Scenarios are seeded directly into Firestore (no factory needed).
 * Node only reads scenarios. The systemPrompt field must always be stripped
 * before returning scenario data to Flutter — use stripSystemPrompt() below.
 */

function stripSystemPrompt(scenario) {
  const { systemPrompt, ...safeScenario } = scenario;
  return safeScenario;
}

module.exports = { stripSystemPrompt };
