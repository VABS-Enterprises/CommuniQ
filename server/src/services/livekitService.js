/**
 * LiveKit service — token minting and room lifecycle management.
 *
 * Requires environment variables:
 *   LIVEKIT_URL        — WebSocket URL of the LiveKit server (e.g. ws://localhost:7880)
 *   LIVEKIT_API_KEY    — must match a key in livekit.yaml (e.g. devkey)
 *   LIVEKIT_API_SECRET — must match livekit.yaml (>= 32 chars for LiveKit 1.10+)
 *   PIPECAT_WORKER_URL — HTTP URL of the Pipecat worker (e.g. http://localhost:9000)
 *
 * When LIVEKIT_ENABLED=false (default for classic HTTP mode), all functions
 * are no-ops so existing sessions continue to work without any LiveKit infra.
 */

const { AccessToken, RoomServiceClient } = require('livekit-server-sdk');

const ENABLED = process.env.LIVEKIT_ENABLED === 'true';
const LIVEKIT_URL = process.env.LIVEKIT_URL || 'ws://localhost:7880';
const API_KEY = process.env.LIVEKIT_API_KEY || 'devkey';
// Must match livekit/livekit.yaml — LiveKit 1.10+ requires secret length >= 32.
const API_SECRET =
  process.env.LIVEKIT_API_SECRET ||
  'communiq-local-dev-livekit-secret-min-32ch';
const PIPECAT_WORKER_URL = process.env.PIPECAT_WORKER_URL || 'http://localhost:9000';

// HTTP URL for RoomServiceClient — convert ws:// → http:// if needed
const LIVEKIT_HTTP_URL = LIVEKIT_URL.replace(/^wss?:\/\//, (m) =>
  m.startsWith('wss') ? 'https://' : 'http://'
);

/**
 * Mint a LiveKit access token for a user joining a session room.
 *
 * @param {string} sessionId - Used as the LiveKit room name.
 * @param {string} userId    - Firebase UID; used as LiveKit participant identity.
 * @returns {{ token: string, livekitUrl: string }}
 */
async function createUserToken(sessionId, userId) {
  const token = new AccessToken(API_KEY, API_SECRET, {
    identity: `user-${userId}`,
    ttl: '2h',
  });
  token.addGrant({
    room: sessionId,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
  });
  return {
    token: await token.toJwt(),
    livekitUrl: LIVEKIT_URL,
  };
}

/**
 * Mint a LiveKit access token for the Pipecat agent joining a session room.
 * Agent can publish (AI audio) and subscribe (user mic).
 *
 * @param {string} sessionId
 * @returns {Promise<string>} JWT token
 */
async function createAgentToken(sessionId) {
  const token = new AccessToken(API_KEY, API_SECRET, {
    identity: `agent-${sessionId}`,
    ttl: '4h',
  });
  token.addGrant({
    room: sessionId,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
  });
  return await token.toJwt();
}

/**
 * Create a LiveKit room for the session.
 * Safe to call if the room already exists (LiveKit is idempotent on create).
 *
 * @param {string} sessionId
 */
async function createRoom(sessionId) {
  if (!ENABLED) return;
  try {
    const svc = new RoomServiceClient(LIVEKIT_HTTP_URL, API_KEY, API_SECRET);
    await svc.createRoom({ name: sessionId, emptyTimeout: 300, maxParticipants: 10 });
  } catch (err) {
    // Log but do not throw — room may already exist, which is fine.
    console.warn(`[livekit] createRoom(${sessionId}): ${err.message}`);
  }
}

/**
 * Delete the LiveKit room for a session.
 * Called after evaluation completes so orphaned rooms do not persist.
 *
 * @param {string} sessionId
 */
async function deleteRoom(sessionId) {
  if (!ENABLED) return;
  try {
    const svc = new RoomServiceClient(LIVEKIT_HTTP_URL, API_KEY, API_SECRET);
    await svc.deleteRoom(sessionId);
  } catch (err) {
    console.warn(`[livekit] deleteRoom(${sessionId}): ${err.message}`);
  }
}

/**
 * Dispatch the Pipecat agent worker for a session.
 * Sends POST /start-agent to the worker service; the worker mints its own
 * LiveKit token and joins the room as an agent participant.
 *
 * @param {string} sessionId
 * @param {string} systemPrompt - Full scenario system prompt (with modifiers applied)
 * @param {string} [openingText] - The opening AI line already spoken; seeded into
 *   the Pipecat LLM context as the first assistant message so the bot doesn't
 *   re-introduce itself on the first user turn.
 */
async function dispatchAgent(sessionId, systemPrompt, openingText = '') {
  if (!ENABLED) return;
  const agentToken = await createAgentToken(sessionId);
  try {
    const res = await fetch(`${PIPECAT_WORKER_URL}/start-agent`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        // Required since the worker now authenticates inbound /start-agent
        // calls with the same shared secret it uses for its own outbound
        // webhook calls back to this server.
        'X-Communiq-Worker-Secret': process.env.PIPECAT_WEBHOOK_SECRET || '',
      },
      body: JSON.stringify({
        session_id: sessionId,
        livekit_url: LIVEKIT_URL,
        agent_token: agentToken,
        system_prompt: systemPrompt,
        opening_text: openingText,
      }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) {
      const body = await res.text();
      console.error(`[livekit] dispatchAgent(${sessionId}) worker error ${res.status}: ${body}`);
    }
  } catch (err) {
    // Non-fatal — log but allow the opening response to still reach Flutter.
    // The worker can be started manually or retried.
    console.error(`[livekit] dispatchAgent(${sessionId}) failed: ${err.message}`);
  }
}

module.exports = {
  ENABLED,
  createUserToken,
  createAgentToken,
  createRoom,
  deleteRoom,
  dispatchAgent,
};
