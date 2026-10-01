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
  const escapeHtml = (value = "") => String(value).replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;"
  }[character]));

  // Shared "taped-in figure" frame used by single images and slideshows.
  // Keep the markup on one line so Markdown does not inject paragraphs.
  const figureBar = (caption, label) =>
    `<figcaption class="comic-figure-bar"><span class="comic-figure-check" aria-hidden="true">&#10003;</span><span class="comic-figure-caption">${escapeHtml(caption)}</span><span class="comic-figure-label" data-fig-label="${escapeHtml(label)}"></span></figcaption>`;

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
    
    const figureStyle = maxWidth ? ` style="max-width: ${maxWidth};"` : "";
    const pageTitle = (this.page && this.ctx && this.ctx.title) || "";

    return `<figure class="comic-figure"${figureStyle}><div class="comic-figure-media">${Image.generateHTML(metadata, imageAttributes)}</div>${figureBar(alt, pageTitle)}</figure>`;
  });

  // Card cover image (optional `cover` front matter). Cropped to 16:9 by CSS.
  eleventyConfig.addShortcode("cover", async function(src, alt) {
    if (!src || !alt) {
      throw new Error(`cover shortcode needs a source and alt text`);
    }

    const metadata = await Image(src, {
      widths: [480, 720, 1000],
      formats: ["webp", "jpeg"],
      outputDir: "./src_site/assets/images/",
      urlPath: "/assets/images/",
      concurrency: imageConcurrency,
      cacheOptions: {
        duration: "1d",
        directory: imageCacheDir
      },
      filenameFormat: function(_, imageSrc, width, format) {
        const name = path.basename(imageSrc, path.extname(imageSrc));
        return `${name}-cover-${width}w.${format}`;
      }
    });

    return Image.generateHTML(metadata, {
      alt,
      sizes: "(min-width: 900px) 520px, 100vw",
      loading: "lazy",
      decoding: "async",
      class: "comic-lead-img"
    });
  });

  eleventyConfig.addPairedShortcode("slideshow", async function(content) {
    const lines = content.split('\n').filter(line => line.trim() !== '');
    let slidesHtml = '';
    
    // Generate unique ID
    const slideshowId = 'slideshow-' + Math.random().toString(36).substr(2, 9);
    
    for (const line of lines) {
      // Expected format: path/to/image.png, Caption Text
      // Split by first comma only
      const firstCommaIndex = line.indexOf(',');
      let src = '';
      let caption = '';
      
      if (firstCommaIndex === -1) {
        src = line.trim();
      } else {
        src = line.substring(0, firstCommaIndex).trim();
        caption = line.substring(firstCommaIndex + 1).trim();
      }
      
      if (!src) continue;
      
      try {
         let options = {
          widths: [600, 900, 1200],
          formats: ["webp", "png"],
          outputDir: "./src_site/assets/images/",
          urlPath: "/assets/images/",
          concurrency: imageConcurrency,
          cacheOptions: {
            duration: "1d",
            directory: imageCacheDir
          },
          filenameFormat: function(id, src, width, format) {
            const name = path.basename(src, path.extname(src));
            return `${name}-${width}w.${format}`;
          },
          jpegOptions: false,
          avifOptions: false
        };
        
        let metadata = await Image(src, options);
        
        let imageAttributes = {
          alt: caption || "Slideshow Image",
          sizes: "100vw",
          loading: "lazy",
          decoding: "async",
          class: "slide-image"
        };
        
        const imgHtml = Image.generateHTML(metadata, imageAttributes);
        const captionHtml = caption ? `<div class="text">${escapeHtml(caption)}</div>` : '';

        // Keep this compact so Markdown does not inject paragraphs and line breaks.
        slidesHtml += `<div class="mySlides fade">${imgHtml}${captionHtml}</div>`;
      } catch (e) {
        console.error(`Error processing slideshow image ${src}:`, e);
        // Fallback or skip
      }
    }
    
    const pageTitle = (this.page && this.ctx && this.ctx.title) || "";

    return `<figure class="comic-figure comic-figure--slideshow"><div class="comic-figure-media"><div class="slideshow-container" id="${slideshowId}" tabindex="0" aria-label="Image Slideshow">${slidesHtml}<a class="prev">&#10094;</a><a class="next">&#10095;</a></div></div>${figureBar("", pageTitle)}</figure>`;
  });

  eleventyConfig.addShortcode("youtubeEmbed", function(videoId, title = "YouTube video", caption = "") {
    if (!videoId) {
      return "";
    }

    const safeVideoId = String(videoId).trim().replace(/[^a-zA-Z0-9_-]/g, "");
    if (!safeVideoId) {
      return "";
    }

    const safeTitle = escapeHtml(title);
    const safeCaption = escapeHtml(caption);

    return `
      <figure class="youtube-embed">
        <div class="youtube-embed__frame">
          <iframe
            src="https://www.youtube-nocookie.com/embed/${safeVideoId}"
            title="${safeTitle}"
            loading="lazy"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
            allowfullscreen>
          </iframe>
        </div>
        ${safeCaption ? `<figcaption>${safeCaption}</figcaption>` : ""}
      </figure>
    `;
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

  // Group tags (with post counts) into the curated topic groups; leftovers go in "More"
  eleventyConfig.addFilter("groupTags", function(tags, posts, groups) {
    const countFor = (tag) => posts.filter((post) => post.data.tags && post.data.tags.includes(tag)).length;
    const available = new Set(tags);
    const placed = new Set();

    const build = (title, names) => ({
      title,
      tags: names
        .filter((name) => available.has(name))
        .map((name) => ({ name, count: countFor(name) }))
        .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name))
    });

    const grouped = groups.map((group) => {
      group.tags.forEach((name) => placed.add(name));
      return build(group.title, group.tags);
    });

    const leftovers = tags.filter((name) => !placed.has(name));
    if (leftovers.length) grouped.push(build("More", leftovers));

    return grouped.filter((group) => group.tags.length);
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

  eleventyConfig.addFilter("dateToNoteFormat", function(date) {
    if (!date) return '';

    const dateObj = date instanceof Date ? date : new Date(date);
    const utcDate = new Date(Date.UTC(
      dateObj.getUTCFullYear(),
      dateObj.getUTCMonth(),
      dateObj.getUTCDate()
    ));
    const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    const month = months[utcDate.getUTCMonth()];
    const day = utcDate.getUTCDate();
    const year = utcDate.getUTCFullYear();
    return `${month} ${day}, ${year}`;
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
