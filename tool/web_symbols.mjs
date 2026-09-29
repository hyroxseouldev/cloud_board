import {createCipheriv, createDecipheriv, randomBytes} from 'node:crypto';
import {readFileSync, writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

const header = Buffer.from('CB-SYMBOLS-1\n');
function keyBytes(hex) {
  if (typeof hex !== 'string' || !/^[0-9a-f]{64}$/i.test(hex)) {
    throw new Error('WEB_SYMBOLS_ENCRYPTION_KEY must be a 32-byte hex key');
  }
  return Buffer.from(hex, 'hex');
}

export function seal(data, hexKey) {
  const nonce = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', keyBytes(hexKey), nonce);
  cipher.setAAD(header);
  const encrypted = Buffer.concat([cipher.update(data), cipher.final()]);
  return Buffer.concat([header, nonce, cipher.getAuthTag(), encrypted]);
}

export function open(data, hexKey) {
  if (data.length < header.length + 28 || !data.subarray(0, header.length).equals(header)) {
    throw new Error('Invalid encrypted web symbols');
  }
  const offset = header.length;
  const decipher = createDecipheriv('aes-256-gcm', keyBytes(hexKey), data.subarray(offset, offset + 12));
  decipher.setAAD(header);
  decipher.setAuthTag(data.subarray(offset + 12, offset + 28));
  return Buffer.concat([decipher.update(data.subarray(offset + 28)), decipher.final()]);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [mode, input, output] = process.argv.slice(2);
  if (!['seal', 'open'].includes(mode) || !input || !output) {
    throw new Error('Usage: node tool/web_symbols.mjs seal|open INPUT OUTPUT');
  }
  const result = (mode === 'seal' ? seal : open)(readFileSync(input), process.env.WEB_SYMBOLS_ENCRYPTION_KEY);
  // Never overwrite an existing archive or write plaintext before tag validation.
  writeFileSync(output, result, {mode: 0o600, flag: 'wx'});
}
