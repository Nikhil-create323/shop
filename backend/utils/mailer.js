const { google } = require('googleapis');

const sendMail = async (userEmail, refreshToken, subject, body) => {
  const oAuth2Client = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI
  );

  oAuth2Client.setCredentials({ refresh_token: refreshToken });

  const gmail = google.gmail({ version: 'v1', auth: oAuth2Client });

  const rawMessage = [
    `To: ${userEmail}`,
    `Subject: ${subject}`,
    '',
    body,
  ].join('\n');

  const encodedMessage = Buffer.from(rawMessage)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  return await gmail.users.messages.send({
    userId: 'me',
    requestBody: { raw: encodedMessage },
  });
};

module.exports = sendMail;