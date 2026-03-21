const axios = require('axios');
const FormData = require('form-data');

const FASTAPI_URL = process.env.FASTAPI_URL || 'http://localhost:8000';

/**
 * Forwards a conversation turn to FastAPI.
 * @param {Buffer} audioBuffer - raw audio bytes
 * @param {string} audioOriginalName - original filename (e.g. turn.wav)
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
    contentType: 'audio/wav',
  });
  form.append('sessionId', sessionId);
  form.append('conversationHistory', JSON.stringify(conversationHistory));
  form.append('systemPrompt', systemPrompt);

  const response = await axios.post(`${FASTAPI_URL}/session/turn`, form, {
    headers: form.getHeaders(),
    timeout: 30000,
  });

  return response.data;
}

/**
 * Sends the full transcript to FastAPI for structured evaluation.
 * @param {string} sessionId
 * @param {string} fullTranscript
 * @param {string} scenarioType
 * @returns {{ scores, fillerWordCount, fillerWords, strengths, improvements, recommendedNextScenarioId }}
 */
async function evaluateSession(sessionId, fullTranscript, scenarioType) {
  const response = await axios.post(
    `${FASTAPI_URL}/session/evaluate`,
    { sessionId, fullTranscript, scenarioType },
    { timeout: 60000 }
  );
  return response.data;
}

module.exports = { sendTurnToFastApi, evaluateSession };
