const { google } = require('googleapis');
const { v4: uuidv4 } = require('uuid');

const oAuth2Client = new google.auth.OAuth2(
  process.env.GOOGLE_CLIENT_ID,        
  process.env.GOOGLE_CLIENT_SECRET,    
  process.env.GOOGLE_REDIRECT_URI      
);

oAuth2Client.setCredentials({
  refresh_token: process.env.REFRESH_TOKEN,
});

const gmail = google.gmail({ version: 'v1', auth: oAuth2Client });

async function sendMail(email) {
  const token = uuidv4();

  // FIX 1: Capitalized 'To:' with a colon
  const message = [
    `To: ${email}`,
    `Subject: to reset your password`,
    `Content-Type: text/plain; charset=utf-8`,
    `MIME-Version: 1.0`,
    ``, // The empty line separating headers from the body
    `Hi,
    We received a request to reset your password.
    Here is the secret token: ${token}
    expires in 30 minutes.
    If you didn't request this, you can safely ignore this email.`
  ].join('\n');

  const encodedMessage = Buffer.from(message)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, ''); // Clean up trailing padding characters

  await gmail.users.messages.send({
    userId: 'me', // FIX 2: Always use 'me' for the authenticated sender
    requestBody: {
      raw: encodedMessage,
    },
  });

  console.log("Email sent ✅");

  return token;
}

module.exports = {sendMail}