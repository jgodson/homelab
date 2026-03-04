document.addEventListener('DOMContentLoaded', () => {
  const lightbox = document.getElementById('lightbox');
  const lightboxImg = document.getElementById('lightbox-img');
  const closeBtn = document.querySelector('.lightbox-close');

  if (!lightbox || !lightboxImg || !closeBtn) return;

  // Add click event to all images in the blog content
  // Exclude icons or specific utility images if needed
  const images = document.querySelectorAll('.blog-content img:not(.no-lightbox), .mySlides picture img');

  images.forEach(img => {
    // Add a cursor pointer to indicate the image is clickable
    img.style.cursor = 'zoom-in';

    img.addEventListener('click', (e) => {
      // Prevent default action (if it's wrapped in an anchor)
      e.preventDefault();
      
      // Use currentSrc if available (browser's chosen responsive image), fallback to src
      let targetSrc = img.currentSrc || img.src;
      
      // If the image is inside a picture element, we can try to extract the largest image
      // from the srcset to ensure it looks good when expanded
      const picture = img.closest('picture');
      if (picture) {
        // Find all source elements and the img element
        const elementsWithSrcset = [...picture.querySelectorAll('source'), img];
        for (const el of elementsWithSrcset) {
          const srcset = el.getAttribute('srcset');
          if (srcset) {
            // Split srcset and find the largest image (e.g., "img-1200w.png 1200w, img-600w.png 600w")
            const sources = srcset.split(',').map(s => s.trim());
            let largestWidth = 0;
            for (const s of sources) {
              const parts = s.split(/\s+/);
              if (parts.length === 2) {
                const url = parts[0];
                const widthMatch = parts[1].match(/^(\d+)w$/);
                if (widthMatch) {
                  const width = parseInt(widthMatch[1], 10);
                  if (width > largestWidth) {
                    largestWidth = width;
                    targetSrc = url; // Update to the largest available version
                  }
                }
              }
            }
          }
        }
      }
      
      // Set the lightbox image source to the best image source
      lightboxImg.src = targetSrc;
      lightboxImg.alt = img.alt || '';
      
      // Display the lightbox
      lightbox.style.display = 'flex';
      
      // Prevent body scrolling
      document.body.style.overflow = 'hidden';
    });
  });

  // Close lightbox functions
  const closeLightbox = () => {
    lightbox.style.display = 'none';
    lightboxImg.src = ''; // Clear image source
    document.body.style.overflow = ''; // Restore scrolling
  };

  // Close when clicking the close button
  closeBtn.addEventListener('click', closeLightbox);

  // Close when clicking outside the image (on the background)
  lightbox.addEventListener('click', (e) => {
    if (e.target === lightbox) {
      closeLightbox();
    }
  });

  // Close when pressing the Escape key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && lightbox.style.display === 'flex') {
      closeLightbox();
    }
  });
});
