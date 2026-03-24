const axios = require('axios');
const FormData = require('form-data');

const FASTAPI_URL = process.env.FASTAPI_URL || 'http://localhost:8000';

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
    const message =
      err.response.data?.detail || err.response.data?.error || `FastAPI ${context} error`;
    const e = new Error(message);
    // 4xx from FastAPI = bad request from us → surface as 400
    e.statusCode = status >= 400 && status < 500 ? 400 : 503;
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
      timeout: 60000, // Whisper STT + LLM + edge-tts can take 20-40s on first call
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
