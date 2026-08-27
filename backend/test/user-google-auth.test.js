const test = require('node:test');
const assert = require('node:assert/strict');

const userController = require('../controllers/user');

test('verifyGoogleOAuthToken rejects missing credentials', async () => {
  await assert.rejects(
    () => userController.verifyGoogleOAuthToken('   '),
    /Google OAuth credential is required/i
  );
});
