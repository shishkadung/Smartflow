/**
 * Extract text from Capstone SmartFlow.pdf (if text layer exists).
 * Image-only PDFs: keeps docs/design/SmartFlow-Figma-Screens.md index unchanged.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pdf from 'pdf-parse';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '../..');
const pdfPath = path.join(root, 'Capstone SmartFlow.pdf');
const outFile = path.join(root, 'docs', 'design', 'SmartFlow-Figma-Screens.md');

if (!fs.existsSync(pdfPath)) {
  console.error('PDF not found:', pdfPath);
  process.exit(1);
}

const data = await pdf(fs.readFileSync(pdfPath));
const trimmed = data.text.trim();

if (trimmed.length < 100) {
  console.warn(
    `PDF is image-based (${data.numpages} pages, ${trimmed.length} text chars).`,
  );
  console.warn('Use vscode-pdf to view Capstone SmartFlow.pdf');
  console.warn('Use docs/design/SmartFlow-Figma-Screens.md for screen index.');
  process.exit(0);
}

const pages = data.text.split(/\f/).filter((p) => p.trim().length > 20);
const body =
  pages.length > 1
    ? pages.map((text, i) => `## Screen ${i + 1}\n\n${text.trim()}\n`).join('\n')
    : `${trimmed}\n`;

const header = `# SmartFlow Figma Screens (extracted from PDF)\n\n> ${new Date().toISOString().slice(0, 10)} · ${data.numpages} pages\n\n`;
fs.mkdirSync(path.dirname(outFile), { recursive: true });
fs.writeFileSync(outFile, header + body, 'utf8');
console.log('Wrote', outFile);
