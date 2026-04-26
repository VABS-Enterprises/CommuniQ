const axios = require('axios');
const FormData = require('form-data');

// When deployed on Render, FASTAPI_URL comes from a `fromService` reference
// which returns only the hostname (e.g. "communiq-ai-server.onrender.com")
// without a protocol. Ensure we always have a full URL.
const _rawFastApiUrl = process.env.FASTAPI_URL || 'http://localhost:8000';
const FASTAPI_URL = _rawFastApiUrl.startsWith('http')
  ? _rawFastApiUrl
  : `https://${_rawFastApiUrl}`;

// Internal API key sent on every request to ai-server so ai-server can reject
// calls that don't originate from this Node backend.
// Must match AI_SERVER_INTERNAL_KEY in ai-server/.env.
const AI_SERVER_KEY = process.env.AI_SERVER_INTERNAL_KEY || '';
if (!AI_SERVER_KEY) {
  console.warn(
    '[fastApiService] AI_SERVER_INTERNAL_KEY is not set. ' +
    'ai-server will accept requests from any caller. ' +
    'Set AI_SERVER_INTERNAL_KEY in server/.env and ai-server/.env for production.'
  );
}

function _aiHeaders(extra = {}) {
  const headers = { ...extra };
  if (AI_SERVER_KEY) headers['X-Ai-Server-Key'] = AI_SERVER_KEY;
  return headers;
}

// Bug5 fix: derive correct MIME type from the audio file's extension
const MIME_MAP = {
  wav: 'audio/wav',
  mp3: 'audio/mpeg',
  m4a: 'audio/mp4',
  aac: 'audio/aac',
  ogg: 'audio/ogg',
  webm: 'audio/webm',
};

function getAudioMimeType(filename) {
  const ext = (filename || '').split('.').pop().toLowerCase();
  return MIME_MAP[ext] || 'audio/wav';
}

// Robustness1: translate axios errors into meaningful typed errors so controllers
// can return the right HTTP status to the client instead of a generic 500.
function handleAxiosError(err, context) {
  if (err.response) {
    const status = err.response.status;
    const contentType = (err.response.headers?.['content-type'] || '').toLowerCase();
    const isJson = contentType.includes('application/json');

    // Non-JSON body means Render returned its own HTML error page (service not
    // found, gateway timeout, etc.) — the AI server itself is not reachable.
    if (!isJson) {
      const e = new Error('AI service is currently unavailable — please try again');
      e.statusCode = 503;
      throw e;
    }

    const message =
      err.response.data?.detail || err.response.data?.error || `AI ${context} failed`;
    const e = new Error(message);
    // 4xx from FastAPI = bad request from us → surface as 422 (unprocessable)
    // so Flutter shows a contextual message rather than a generic error.
    e.statusCode = status >= 400 && status < 500 ? status : 503;
    throw e;
  }
  // Network error or timeout
  const e = new Error('AI service is currently unavailable — please try again');
  e.statusCode = 503;
  throw e;
}

/**
 * Forwards a conversation turn to FastAPI.
 * @param {Buffer} audioBuffer - raw audio bytes
 * @param {string} audioOriginalName - original filename (e.g. turn.m4a, turn.wav)
 * @param {string} sessionId
 * @param {Array<{role:string, transcript:string}>} conversationHistory
 * @param {string} systemPrompt - from the scenario document
 * @returns {{ userTranscript, aiReply, aiAudioBase64 }}
 */
async function sendTurnToFastApi(
  audioBuffer,
  audioOriginalName,
  sessionId,
  conversationHistory,
  systemPrompt
) {
  const form = new FormData();
  form.append('audioFile', audioBuffer, {
    filename: audioOriginalName || 'audio.wav',
    contentType: getAudioMimeType(audioOriginalName),
  });
  form.append('sessionId', sessionId);
  form.append('conversationHistory', JSON.stringify(conversationHistory));
  form.append('systemPrompt', systemPrompt);

  try {
    const response = await axios.post(`${FASTAPI_URL}/session/turn`, form, {
      headers: { ...form.getHeaders(), ..._aiHeaders() },
      // 90 s covers a cold-start wake-up (~50 s on free tier) + STT+LLM+TTS (~20 s).
      timeout: 90000,
    });
    return response.data;
  } catch (err) {
    handleAxiosError(err, 'turn');
  }
}

/**
 * Sends the full transcript to FastAPI for structured evaluation.
 * @param {string} sessionId
 * @param {string} fullTranscript
 * @param {string} scenarioType
 * @returns {{ scores, fillerWordCount, fillerWords, strengths, improvements, recommendedNextType }}
 */
/**
 * Opening line: LLM + TTS only (no STT). Colab parity — same contract as turn audio fields.
 */
async function sendOpeningToFastApi(sessionId, systemPrompt) {
  try {
    const response = await axios.post(
      `${FASTAPI_URL}/session/opening`,
      { sessionId, systemPrompt },
      {
        headers: _aiHeaders({ 'Content-Type': 'application/json' }),
        timeout: 90000,
      }
    );
    return response.data;
  } catch (err) {
    handleAxiosError(err, 'opening');
  }
}

/**
 * Evaluate a completed roleplay session transcript.
 * Calls the canonical POST /evaluate/roleplay endpoint.
 * @param {string} sessionId
 * @param {string} fullTranscript
 * @param {string} scenarioType
 * @returns {{ scores, fillerWordCount, fillerWords, strengths, improvements, recommendedNextType }}
 */
async function evaluateSession(sessionId, fullTranscript, scenarioType) {
  try {
    const response = await axios.post(
      `${FASTAPI_URL}/evaluate/roleplay`,
      { sessionId, fullTranscript, scenarioType },
      { headers: _aiHeaders(), timeout: 60000 }
    );
    return response.data;
  } catch (err) {
    handleAxiosError(err, 'evaluate');
  }
}

/**
 * Evaluate a user's answer to a learning module question.
 * Calls POST /evaluate/learning on the ai-server.
 * @param {string} sessionId
 * @param {string} question
 * @param {string} userAnswer
 * @param {string} topic
 * @param {string} difficulty  — 'beginner' | 'intermediate' | 'advanced'
 * @param {string[]} [expectedKeyPoints]
 * @returns {{ scores, overallScore, strengths, improvements, feedback }}
 */
async function evaluateLearningAnswer(sessionId, question, userAnswer, topic, difficulty, expectedKeyPoints = []) {
  try {
    const response = await axios.post(
      `${FASTAPI_URL}/evaluate/learning`,
      { sessionId, question, userAnswer, topic, difficulty, expectedKeyPoints },
      { headers: _aiHeaders(), timeout: 50000 }
    );
    return response.data;
  } catch (err) {
    handleAxiosError(err, 'learning evaluate');
  }
}

/**
 * Evaluate a user's contribution in a contest (debate, GD, extempore, quiz).
 * Calls POST /evaluate/contest on the ai-server.
 * @param {string} sessionId
 * @param {string} userAnswer
 * @param {string} contestType  — 'debate' | 'gd' | 'extempore' | 'quiz'
 * @param {string} motion       — debate topic, GD topic, or quiz question
 * @param {string} [position]   — 'for' | 'against' | '' (not applicable for GD/extempore)
 * @returns {{ scores, overallScore, strengths, improvements, feedback }}
 */
async function evaluateContestAnswer(sessionId, userAnswer, contestType, motion, position = '') {
  try {
    const response = await axios.post(
      `${FASTAPI_URL}/evaluate/contest`,
      { sessionId, userAnswer, contestType, motion, position },
      { headers: _aiHeaders(), timeout: 50000 }
    );
    return response.data;
  } catch (err) {
    handleAxiosError(err, 'contest evaluate');
  }
}

module.exports = {
  sendTurnToFastApi,
  sendOpeningToFastApi,
  evaluateSession,
  evaluateLearningAnswer,
  evaluateContestAnswer,
};
