import { exec } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const pdf = path.join(root, 'Capstone SmartFlow.pdf');

exec(`start "" "${pdf}"`, (err) => {
  if (err) console.error(err);
  else console.log('Opened', pdf);
});
