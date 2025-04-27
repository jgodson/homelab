const fs = require('fs-extra');
const path = require('path');
const crypto = require('crypto');

const distDir = path.join(__dirname, 'dist');
const srcSiteDir = path.join(__dirname, 'src_site');


fs.emptyDirSync(distDir);
fs.copySync(srcSiteDir, distDir);

const assetDirectories = [
  {
    dir: path.join(distDir, 'assets', 'css'),
    extensions: ['.css']
  },
  {
    dir: path.join(distDir, 'assets', 'js'),
    extensions: ['.js']
  },
  {
    dir: path.join(distDir, 'assets', 'images'),
    extensions: ['.jpg', '.jpeg', '.png', '.gif', '.svg', '.webp'],
  }
];

function processAllAssets(assetDirs) {
  assetDirs.forEach(({ dir, extensions, skipPattern }) => {
    if (!fs.existsSync(dir)) return;
    
    fs.readdirSync(dir).forEach(file => {
      if (skipPattern && skipPattern.test(file)) return;
      if (!extensions.some(ext => file.toLowerCase().endsWith(ext))) return;
      
      const filePath = path.join(dir, file);
      if (fs.statSync(filePath).isFile()) {
        // Calculate hash based on file content
        const fileContent = fs.readFileSync(filePath);
        const hash = crypto.createHash('md5').update(fileContent).digest('hex').substring(0, 8);
        
        const extension = path.extname(file);
        const basename = path.basename(file, extension);
        const newFilename = `${basename}.${hash}${extension}`;
        
        fs.renameSync(filePath, path.join(dir, newFilename));
        
        // Update references in HTML and CSS files
        updateReferences(file, newFilename);
      }
    });
  });
}

function updateReferences(oldFile, newFile) {
  // Update references in HTML files
  const htmlFiles = getAllFiles(distDir, '.html');
  htmlFiles.forEach(htmlFile => {
    let content = fs.readFileSync(htmlFile, 'utf8');
    
    // Use a more flexible pattern to match the file in various contexts
    // This handles paths, quotes, and query parameters
    const pattern = new RegExp(`(["'(])(?:.*?)${escapeRegExp(oldFile)}([?#"')\\s]|$)`, 'g');
    content = content.replace(pattern, (match, prefix, suffix) => {
      const replacement = match.replace(oldFile, newFile);
      return replacement;
    });
    
    fs.writeFileSync(htmlFile, content);
  });
  
  // Update references in CSS files
  const cssFiles = getAllFiles(distDir, '.css');
  cssFiles.forEach(cssFile => {
    let content = fs.readFileSync(cssFile, 'utf8');
    
    // Handle url() references in CSS
    const pattern = new RegExp(`url\\(['"]?(?:.*?)${escapeRegExp(oldFile)}(['"]?\\))`, 'g');
    content = content.replace(pattern, (match) => {
      return match.replace(oldFile, newFile);
    });
    
    fs.writeFileSync(cssFile, content);
  });
}

function getAllFiles(dir, extensions) {
  const extensionArray = Array.isArray(extensions) ? extensions : [extensions];
  let results = [];
  
  if (!fs.existsSync(dir)) return results;
  
  const files = fs.readdirSync(dir);
  files.forEach(file => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    
    if (stat.isDirectory()) {
      results = results.concat(getAllFiles(filePath, extensions));
    } else if (extensionArray.some(ext => file.toLowerCase().endsWith(ext))) {
      results.push(filePath);
    }
  });
  
  return results;
}

function escapeRegExp(string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function printDirectoryTree(dir, indent = '') {
  if (!fs.existsSync(dir)) return;
  const items = fs.readdirSync(dir);
  items.forEach((item, index) => {
    const fullPath = path.join(dir, item);
    const stats = fs.statSync(fullPath);
    const isLast = index === items.length - 1;
    const prefix = isLast ? '└── ' : '├── ';
    const childIndent = indent + (isLast ? '    ' : '│   ');

    if (stats.isDirectory()) {
      console.log(`${indent}${prefix}${item}/`);
      printDirectoryTree(fullPath, childIndent);
    } else {
      console.log(`${indent}${prefix}${item} (${formatBytes(stats.size)})`);
    }
  });
}

function formatBytes(bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  if (bytes === 0) return '0 B';
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${units[i]}`;
}

// Process all asset directories
function run() {
  processAllAssets(assetDirectories);
  console.log('Build complete 🎉');
  console.log(`Location: ${distDir}`);
  console.log('/');
  printDirectoryTree(distDir);
}

run();