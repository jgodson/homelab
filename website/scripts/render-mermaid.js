const fs = require('fs-extra');
const path = require('path');
const { execSync } = require('child_process');

// Render all .mmd diagrams under src/diagrams to SVGs under src/assets/images/mermaid.
const rootDir = path.join(__dirname, '..');
const diagramsDir = path.join(rootDir, 'src', 'diagrams');
const outputDir = path.join(rootDir, 'src', 'assets', 'images', 'mermaid');

function findMermaidFiles(dir) {
  if (!fs.existsSync(dir)) return [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  return entries.flatMap((entry) => {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) return findMermaidFiles(fullPath);
    if (entry.isFile() && entry.name.toLowerCase().endsWith('.mmd')) return [fullPath];
    return [];
  });
}

function renderAll() {
  const files = findMermaidFiles(diagramsDir);
  if (files.length === 0) {
    console.log('No Mermaid files found. Skipping render.');
    return;
  }

  fs.ensureDirSync(outputDir);

  files.forEach((input) => {
    const basename = path.basename(input, path.extname(input));
    const output = path.join(outputDir, `${basename}.svg`);
    console.log(`Rendering ${input} -> ${output}`);
    execSync(
      `npx --yes @mermaid-js/mermaid-cli -i "${input}" -o "${output}" -t default`,
      { stdio: 'inherit', cwd: rootDir }
    );
  });
}

renderAll();
