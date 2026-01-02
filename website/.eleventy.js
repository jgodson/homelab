const markdownIt = require("markdown-it");
const markdownItAnchor = require("markdown-it-anchor");
const markdownItLinkAttributes = require("markdown-it-link-attributes");

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
  
  let markdownLibrary = markdownIt(markdownOptions)
    .use(markdownItAnchor, {
      permalink: true,
      permalinkClass: "direct-link",
      permalinkSymbol: "",
      level: [1, 2, 3, 4, 5, 6]
    })
    .use(markdownItLinkAttributes, {
      matcher(href) {
        // Match external links (starts with http:// or https://)
        return href.match(/^https?:\/\//);
      },
      attrs: {
        target: "_blank",
        rel: "noopener noreferrer"
      }
    });
  
  eleventyConfig.setLibrary("md", markdownLibrary);

  // Copy assets directory to the output (_site) directory
  eleventyConfig.addPassthroughCopy("src/assets");
  // Copy robots.txt to the output (_site) directory
  eleventyConfig.addPassthroughCopy("src/robots.txt");

  const imageCacheDir = path.join(__dirname, ".cache", "eleventy-img");
  const imageConcurrency = 2;

  // Simplified image shortcode focusing on WebP optimization
  eleventyConfig.addShortcode("image", async function(src, alt, sizes = "100vw", maxWidth = null) {
    if (!src) {
      throw new Error(`Missing image source`);
    }
    
    if (!alt) {
      throw new Error(`Missing alt text for image: ${src}`);
    }
    
    const sourceMetadata = await Image(src, {
      widths: [null],
      formats: ["png"],
      dryRun: true,
      concurrency: imageConcurrency,
      cacheOptions: {
        duration: "1d",
        directory: imageCacheDir
      }
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
      concurrency: imageConcurrency,
      cacheOptions: {
        duration: "1d",
        directory: imageCacheDir
      },
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
    
    // Add style attribute for max-width and centering if maxWidth is provided
    if (maxWidth) {
      imageAttributes.style = `max-width: ${maxWidth}; display: block; margin: 0 auto;`;
    }
    
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

    const dateObj = date instanceof Date ? date : new Date(date);
    const utcDate = new Date(Date.UTC(
      dateObj.getUTCFullYear(),
      dateObj.getUTCMonth(),
      dateObj.getUTCDate()
    ));
    const options = { year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC' };
    return utcDate.toLocaleDateString('en-US', options);
  });

  eleventyConfig.addFilter("dateToISO", function(date) {
    if (!date) return '';

    const dateObj = date instanceof Date ? date : new Date(date);
    const utcDate = new Date(Date.UTC(
      dateObj.getUTCFullYear(),
      dateObj.getUTCMonth(),
      dateObj.getUTCDate()
    ));

    return utcDate.toISOString();
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
  
  // Add a filter specifically for feed content that simplifies HTML
  eleventyConfig.addFilter("prepareFeedContent", function(content, baseUrl) {
    if (!content) return "";
    if (!baseUrl) return content;
    
    // Normalize base URL
    baseUrl = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
    
    try {
      // Create a simple DOM parser
      const JSDOM = require("jsdom").JSDOM;
      const dom = new JSDOM(content);
      const document = dom.window.document;
      
      // Process all picture elements
      const pictures = document.querySelectorAll("picture");
      pictures.forEach(picture => {
        // Get the img element and its attributes
        const img = picture.querySelector("img");
        if (!img) return;
        
        const src = img.getAttribute("src") || "";
        const alt = img.getAttribute("alt") || "";
        const className = img.getAttribute("class") || "";
        
        // Create new img element with absolute URL
        const newImg = document.createElement("img");
        newImg.setAttribute("alt", alt);
        if (className) newImg.setAttribute("class", className);
        
        // Set absolute source
        if (src.startsWith("/")) {
          newImg.setAttribute("src", `${baseUrl}${src}`);
        } else {
          newImg.setAttribute("src", src);
        }
        
        // Replace the picture with the img
        picture.parentNode.replaceChild(newImg, picture);
      });
      
      // Fix all URLs in the document
      const fixUrl = (url) => {
        if (!url) return url;
        if (url.startsWith("/")) return `${baseUrl}${url}`;
        return url;
      };
      
      // Fix links
      document.querySelectorAll("a[href]").forEach(link => {
        const href = link.getAttribute("href");
        if (href && href.startsWith("/")) {
          link.setAttribute("href", fixUrl(href));
        }
      });
      
      // Fix images
      document.querySelectorAll("img[src]").forEach(img => {
        const src = img.getAttribute("src");
        if (src && src.startsWith("/")) {
          img.setAttribute("src", fixUrl(src));
        }
      });
      
      return document.body.innerHTML;
    } catch (e) {
      console.error("Error processing feed content:", e);
      
      // Fallback to basic regex replacement if JSDOM fails
      return content
        .replace(/<picture>[\s\S]*?<img[^>]*src="([^"]*)"[^>]*alt="([^"]*)"[^>]*>[\s\S]*?<\/picture>/g, (match, src, alt) => {
          const absoluteSrc = src.startsWith('/') ? `${baseUrl}${src}` : src;
          return `<img src="${absoluteSrc}" alt="${alt}" />`;
        })
        .replace(/href="\/([^"]*)"/g, `href="${baseUrl}/$1"`)
        .replace(/src="\/([^"]*)"/g, `src="${baseUrl}/$1"`);
    }
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
