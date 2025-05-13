const markdownIt = require("markdown-it");
const markdownItAnchor = require("markdown-it-anchor");

module.exports = function(eleventyConfig) {
  const syntaxHighlight = require("@11ty/eleventy-plugin-syntaxhighlight");
  const pluginRss = require("@11ty/eleventy-plugin-rss");
  const Image = require("@11ty/eleventy-img");
  const path = require("path");
  
  eleventyConfig.addPlugin(syntaxHighlight);
  eleventyConfig.addPlugin(pluginRss);

  // Configure Markdown with anchors
  let markdownOptions = {
    html: true,
    breaks: true,
    linkify: true
  };
  
  let markdownLibrary = markdownIt(markdownOptions).use(markdownItAnchor, {
    permalink: true,
    permalinkClass: "direct-link",
    permalinkSymbol: "",
    level: [1, 2, 3, 4, 5, 6]
  });
  
  eleventyConfig.setLibrary("md", markdownLibrary);

  // Copy assets directory to the output (_site) directory
  eleventyConfig.addPassthroughCopy("src/assets");
  // Copy robots.txt to the output (_site) directory
  eleventyConfig.addPassthroughCopy("src/robots.txt");

  // Simplified image shortcode focusing on WebP optimization
  eleventyConfig.addShortcode("image", async function(src, alt, sizes = "100vw") {
    if (!src) {
      throw new Error(`Missing image source`);
    }
    
    if (!alt) {
      throw new Error(`Missing alt text for image: ${src}`);
    }
    
    const sourceMetadata = await Image(src, {
      widths: [null],
      formats: ["png"],
      dryRun: true
    });
    
    // Get original width to avoid generating larger sizes
    const originalWidth = sourceMetadata.png[0].width;
    
    // Define responsive widths based on original size
    let widths = [300, 600];
    if (originalWidth > 600) widths.push(Math.min(900, originalWidth));
    if (originalWidth > 900) widths.push(Math.min(1200, originalWidth));
    
    let options = {
      widths: widths,
      formats: ["webp", "png"],
      outputDir: "./src_site/assets/images/",
      urlPath: "/assets/images/",
      filenameFormat: function(_, src, width, format) {
        const name = path.basename(src, path.extname(src));
        return `${name}-${width}w.${format}`;
      },
      jpegOptions: false,
      avifOptions: false
    };
    
    let metadata = await Image(src, options);
    
    let imageAttributes = {
      alt,
      sizes,
      loading: "lazy",
      decoding: "async",
      class: "responsive-image"
    };
    
    return Image.generateHTML(metadata, imageAttributes);
  });

  const tagSet = new Set();
  
  // Set up blog collection
  eleventyConfig.addCollection("blog", function(collection) {
    // Get all blog posts, collect tags, and sort by date in a single pass
    const sortedPosts = collection.getFilteredByGlob("src/blog/*.md")
      .map(post => {
        // While processing each post, collect its tags
        if (post.data.tags) {
          post.data.tags.forEach(tag => {
            if (tag !== "blog") {
              tagSet.add(tag);
            }
          });
        }
        return post;
      })
      .sort((a, b) => {
        // Sort blog posts by date in descending order
        return b.date - a.date;
      });
    
    return sortedPosts;
  });

  // Create collections for each tag
  eleventyConfig.addCollection("tagList", function() {
    return [...tagSet].sort();
  });

  // Add filter to get posts by tag
  eleventyConfig.addFilter("getPostsByTag", function(posts, tag) {
    return posts.filter((post) => {
      return post.data.tags && post.data.tags.includes(tag);
    });
  });

  eleventyConfig.addFilter("dateToFormat", function(date) {
    if (!date) return '';
    
    const dateObj = new Date(date);
    
    // Add one day to fix the timezone offset issue
    dateObj.setDate(dateObj.getDate() + 1);
    const options = { year: 'numeric', month: 'long', day: 'numeric' };
    return dateObj.toLocaleDateString('en-US', options);
  });
  
  eleventyConfig.addFilter("dateToISO", function(date) {
    if (!date) return '';
    
    const dateObj = new Date(date);
    
    // Add one day to fix the timezone offset issue
    dateObj.setDate(dateObj.getDate() + 1);
  
    return dateObj.toISOString();
  });
  
  // Add a filter to get the most recent post date for the Atom feed
  eleventyConfig.addFilter("getNewestCollectionItemDate", collection => {
    if (!collection || !collection.length) return new Date();
    return new Date(Math.max(...collection.map(item => item.date)));
  });
  
  // Add filter to get file modification date
  eleventyConfig.addFilter("getFileLastModified", inputPath => {
    try {
      const fs = require('fs');
      if (!inputPath) return new Date();
      
      const filePath = inputPath.toString();
      const fullPath = path.resolve(filePath);
      
      if (fs.existsSync(fullPath)) {
        const stats = fs.statSync(fullPath);
        return stats.mtime;
      } else {
        console.log(`File not found: ${fullPath}`);
      }
      return new Date();
    } catch (e) {
      console.log("Error getting last modified date:", e);
      return new Date();
    }
  });
  
  // Filters for absolute URLs in the feed
  eleventyConfig.addFilter("absoluteUrl", (url, base) => {
    if (!url) return base;
    if (url.startsWith("/")) return `${base}${url}`;
    return url;
  });
  
  eleventyConfig.addFilter("htmlToAbsoluteUrls", function(html, base) {
    if (!html) return "";
    if (!base) return html;
    
    // Normalize base URL to ensure it doesn't have a trailing slash
    const baseUrl = base.endsWith('/') ? base.slice(0, -1) : base;
    
    // Handle various attributes and patterns in HTML
    return html
      // Fix regular href attributes
      .replace(/href="\/([^"]*)"/g, `href="${baseUrl}/$1"`)
      // Fix regular src attributes
      .replace(/src="\/([^"]*)"/g, `src="${baseUrl}/$1"`)
      // Fix srcset attributes that use relative paths
      .replace(/srcset="(\/[^"]*\s+\d+[wx][^"]*)"/g, function(match, srcset) {
        return 'srcset="' + srcset.replace(/\/([^\s]+)\s+/g, `${baseUrl}/$1 `) + '"';
      })
      // Fix paths in picture/source elements
      .replace(/srcset="([^"]*)"([^>]*>)/g, function(match, srcset, rest) {
        if (srcset.includes('/assets/') || srcset.includes('/images/')) {
          // Process srcset with multiple image candidates
          const newSrcset = srcset
            .split(',')
            .map(src => {
              const parts = src.trim().split(' ');
              if (parts[0].startsWith('/')) {
                parts[0] = `${baseUrl}${parts[0]}`;
              }
              return parts.join(' ');
            })
            .join(', ');
          return `srcset="${newSrcset}"${rest}`;
        }
        return match;
      });
  });

  return {
    dir: {
      input: "src",      // Source directory
      output: "src_site", // Output directory (will be processed by build.js script)
      includes: "_includes", // Templates are stored here
      layouts: "_layouts"    // Layouts are stored here
    },
    // Process markdown, HTML and Nunjucks files
    templateFormats: ["md", "html", "njk"],
    // Use .html as output file extension
    htmlTemplateEngine: "njk",
    markdownTemplateEngine: "njk"
  };
};