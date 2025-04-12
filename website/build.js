const fs = require('fs-extra');
const path = require('path');
const crypto = require('crypto');

const distDir = path.join(__dirname, 'dist');

// Clean and create dist directory
fs.emptyDirSync(distDir);

// Copy all files from src
fs.copySync(path.join(__dirname, 'src'), distDir);

// Directories to check for assets
const cssDir = path.join(distDir, 'assets', 'css');
const jsDir = path.join(distDir, 'assets', 'js');
const imgDir = path.join(distDir, 'assets', 'images');

// Process all assets with content hashing
processAssets(cssDir, '.css');
processAssets(jsDir, '.js');
processAssets(imgDir, ['.jpg', '.jpeg', '.png', '.gif', '.svg', '.webp']);

function processAssets(directory, extensions) {
  if (!fs.existsSync(directory)) return;
  
  const extensionArray = Array.isArray(extensions) ? extensions : [extensions];
  
  fs.readdirSync(directory).forEach(file => {
    // Skip if the file doesn't match any of our extensions
    if (!extensionArray.some(ext => file.toLowerCase().endsWith(ext))) return;
    
    const filePath = path.join(directory, file);
    if (fs.statSync(filePath).isFile()) {
      // Calculate hash based on file content
      const fileContent = fs.readFileSync(filePath);
      const hash = crypto.createHash('md5').update(fileContent).digest('hex').substring(0, 8);
      
      // Create new filename with hash
      const extension = path.extname(file);
      const basename = path.basename(file, extension);
      const newFilename = `${basename}.${hash}${extension}`;
      
      // Rename the file
      fs.renameSync(filePath, path.join(directory, newFilename));
      
      // Update references in HTML and CSS files
      updateReferences(file, newFilename);
    }
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

console.log('Build complete with content-based hashing');