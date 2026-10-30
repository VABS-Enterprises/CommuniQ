const test = require('node:test');
const assert = require('node:assert');
const path = require('path');

const { publicError } = require(path.join(__dirname, '..', 'src/utils/publicError.js'));

const err = (message, statusCode, expose) => Object.assign(new Error(message), { statusCode, expose });

test('4xx messages are passed through', () => {
  assert.strictEqual(publicError(err('Audio too short', 422), 'fallback'), 'Audio too short');
});

test('5xx messages are replaced by the fallback', () => {
  assert.strictEqual(publicError(err('9 FAILED_PRECONDITION: index url...', 500), 'fallback'), 'fallback');
  assert.strictEqual(publicError(err('upstream detail', 503), 'fallback'), 'fallback');
});

test('messages marked expose are passed through regardless of status', () => {
  assert.strictEqual(
    publicError(err('AI service is currently unavailable — please try again', 503, true), 'fallback'),
    'AI service is currently unavailable — please try again'
  );
});

test('errors without a status get the fallback', () => {
  assert.strictEqual(publicError(new Error('boom'), 'fallback'), 'fallback');
  assert.strictEqual(publicError(undefined, 'fallback'), 'fallback');
});
