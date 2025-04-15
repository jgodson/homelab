module.exports = function(eleventyConfig) {
  const syntaxHighlight = require("@11ty/eleventy-plugin-syntaxhighlight");
  eleventyConfig.addPlugin(syntaxHighlight);

  // Copy assets directory to the output (_site) directory
  eleventyConfig.addPassthroughCopy("src/assets");

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
    
    // Format as YYYY-MM-DD
    const year = dateObj.getFullYear();
    const month = String(dateObj.getMonth() + 1).padStart(2, '0');
    const day = String(dateObj.getDate()).padStart(2, '0');
    
    return `${year}-${month}-${day}`;
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