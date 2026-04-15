const axios = require('axios');
const FormData = require('form-data');

// When deployed on Render, FASTAPI_URL comes from a `fromService` reference
// which returns only the hostname (e.g. "communiq-ai-server.onrender.com")
// without a protocol. Ensure we always have a full URL.
const _rawFastApiUrl = process.env.FASTAPI_URL || 'http://localhost:8000';
const FASTAPI_URL = _rawFastApiUrl.startsWith('http')
  ? _rawFastApiUrl
  : `https://${_rawFastApiUrl}`;

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
      headers: form.getHeaders(),
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
async function evaluateSession(sessionId, fullTranscript, scenarioType) {
  try {
    const response = await axios.post(
      `${FASTAPI_URL}/session/evaluate`,
      { sessionId, fullTranscript, scenarioType },
      { timeout: 60000 }
    );
    return response.data;
  } catch (err) {
    handleAxiosError(err, 'evaluate');
  }
}

module.exports = { sendTurnToFastApi, evaluateSession };
