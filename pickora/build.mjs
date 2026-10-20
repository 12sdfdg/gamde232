// Builds pickora.html (artifact body) and pickora.standalone.html (full document) from src/.
// Usage: node build.mjs
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
let ts;
try { ts = require('typescript'); } catch { ts = require('/opt/node-tools/node_modules/typescript'); }

const src = readFileSync(join(here, 'src/app.jsx'), 'utf8');
const out = ts.transpileModule(src, {
  fileName: 'app.tsx',
  reportDiagnostics: true,
  compilerOptions: { jsx: ts.JsxEmit.React, target: ts.ScriptTarget.ES2019, module: ts.ModuleKind.ESNext },
});
if (out.diagnostics && out.diagnostics.length) {
  for (const d of out.diagnostics) console.error(ts.flattenDiagnosticMessageText(d.messageText, '\n'));
  process.exit(1);
}
const css = readFileSync(join(here, 'src/styles.css'), 'utf8');
const js = out.outputText.replace(/<\/script/gi, '<\\/script');

const body = `<title>Pickora</title>
<meta name="claude:viewport-fit-sides" content="cover">
<meta name="description" content="Spin a wheel to pick a name, answer yes or no, draw numbers or split people into teams. Free, in your browser.">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@500&family=Onest:wght@400;500;600;700&family=Unbounded:wght@600;700;800&display=swap">
<style>
${css}
</style>
<div id="root"></div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/react/18.3.1/umd/react.production.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/react-dom/18.3.1/umd/react-dom.production.min.js"></script>
<script>
${js}
</script>
`;

mkdirSync(join(here, 'dist'), { recursive: true });
writeFileSync(join(here, 'dist/pickora.html'), body);
writeFileSync(
  join(here, 'dist/pickora.standalone.html'),
  `<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n</head>\n<body>\n${body}</body>\n</html>\n`,
);
console.log('built', (body.length / 1024).toFixed(1) + ' KB');
