// Independent Node crypto implementation to verify the Dart wire format.
const crypto = require('node:crypto');
const fs = require('node:fs');
const input = JSON.parse(fs.readFileSync(0, 'utf8'));
const server = crypto.createECDH('prime256v1');
server.setPrivateKey(Buffer.from('01'.padStart(64, '0'), 'hex'));
if (input.publicKeyOnly) {
  console.log(server.getPublicKey('base64'));
  process.exit(0);
}
const h = input.headers;
const shared = server.computeSecret(Buffer.from(h['X-Enc-Epk'], 'base64'));
const key = Buffer.from(crypto.hkdfSync('sha256', shared, Buffer.from(h['X-Enc-Nonce'], 'base64url'), Buffer.from(`JWALLET-E2E-v1|${h['X-Enc-Kid']}`), 32));
const bytes = Buffer.from(input.body.payload, 'base64');
const decipher = crypto.createDecipheriv('aes-256-gcm', key, bytes.subarray(0, 12));
decipher.setAAD(Buffer.from(`JWALLET-E2E-v1\nREQ\nPOST\n/api/v1/auth/login\n${h['X-Enc-Ts']}\n${h['X-Enc-Nonce']}`));
decipher.setAuthTag(bytes.subarray(-16));
const received = JSON.parse(Buffer.concat([decipher.update(bytes.subarray(12, -16)), decipher.final()]).toString());
const iv = crypto.randomBytes(12);
const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
cipher.setAAD(Buffer.from(`JWALLET-E2E-v1\nRES\n${h['X-Enc-Nonce']}\n200`));
const response = {meta: {statusCode: 200}, body: {received}};
const encrypted = Buffer.concat([cipher.update(JSON.stringify(response)), cipher.final()]);
console.log(JSON.stringify({payload: Buffer.concat([iv, encrypted, cipher.getAuthTag()]).toString('base64')}));
