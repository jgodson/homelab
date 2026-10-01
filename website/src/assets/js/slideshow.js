document.addEventListener('DOMContentLoaded', () => {
  const slideshows = document.querySelectorAll('.slideshow-container');
  
  slideshows.forEach(slideshow => {
    // Initialize first slide as active
    const slides = slideshow.querySelectorAll('.mySlides');
    if (slides.length > 0) {
      slides[0].style.display = 'block';
    }
    
    updateFigureBar(slideshow);

    // Attach event listeners
    const prev = slideshow.querySelector('.prev');
    const next = slideshow.querySelector('.next');
    
    if (prev) {
      prev.addEventListener('click', () => changeSlide(slideshow, -1));
    }
    
    if (next) {
      next.addEventListener('click', () => changeSlide(slideshow, 1));
    }

    // Keyboard navigation
    slideshow.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowLeft') {
        changeSlide(slideshow, -1);
      } else if (e.key === 'ArrowRight') {
        changeSlide(slideshow, 1);
      }
    });
  });
});

function changeSlide(slideshow, n) {
  const slides = slideshow.querySelectorAll('.mySlides');
  let activeIndex = -1;
  
  // Find current active slide
  slides.forEach((slide, index) => {
    if (slide.style.display === 'block') {
      activeIndex = index;
    }
  });
  
  // Hide current slide
  if (activeIndex !== -1) {
    slides[activeIndex].style.display = 'none';
  }
  
  // Calculate new index
  let newIndex = activeIndex + n;
  if (newIndex >= slides.length) {
    newIndex = 0;
  }
  if (newIndex < 0) {
    newIndex = slides.length - 1;
  }
  
  // Show new slide
  slides[newIndex].style.display = 'block';
  updateFigureBar(slideshow);
}

// Show the active slide's caption and position in the figure's caption bar
function updateFigureBar(slideshow) {
  const figure = slideshow.closest('.comic-figure');
  if (!figure) return;

  const slides = Array.from(slideshow.querySelectorAll('.mySlides'));
  const index = slides.findIndex((slide) => slide.style.display === 'block');
  if (index === -1) return;

  const text = slides[index].querySelector('.text');
  const caption = figure.querySelector('.comic-figure-caption');
  const label = figure.querySelector('.comic-figure-label');
  if (caption) caption.textContent = text ? text.textContent : '';
  if (label) label.dataset.figLabel = `${index + 1}/${slides.length}`;
}
