#!/bin/bash

# Script to optimize images in the website project
# Usage: 
#   ./optimize-images.sh          - Optimizes images to src/assets/images/optimized/
#   ./optimize-images.sh --replace - Replaces original images with optimized versions

# Configuration
SOURCE_DIR="/Users/jasongodson/Documents/github/homelab/website/src/assets/images"
OPTIMIZED_DIR="${SOURCE_DIR}/optimized"
REPLACE_MODE=false

# Check for replace flag
if [[ "$1" == "--replace" ]]; then
  REPLACE_MODE=true
  echo "🔄 Replace mode enabled - original images will be replaced"
fi

# Check if pngquant is installed
check_pngquant() {
  if ! command -v pngquant &> /dev/null; then
    echo "🔍 pngquant not found. Installing with Homebrew..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
      echo "❌ Homebrew is not installed. Please install it first:"
      echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      exit 1
    fi
    
    brew install pngquant
  else
    echo "✅ pngquant is already installed"
  fi
}

# Create optimized directory if it doesn't exist and we're not in replace mode
setup_directories() {
  if [[ "$REPLACE_MODE" == false ]]; then
    if [[ ! -d "$OPTIMIZED_DIR" ]]; then
      echo "📁 Creating optimized directory: ${OPTIMIZED_DIR}"
      mkdir -p "$OPTIMIZED_DIR"
    else
      echo "📁 Optimized directory already exists: ${OPTIMIZED_DIR}"
    fi
  fi
}

# Function to optimize an image
optimize_image() {
  local input_file="$1"
  local filename=$(basename "$input_file")
  local extension="${filename##*.}"
  local basename="${filename%.*}"
  
  # Convert extension to lowercase using tr instead of bash-specific syntax
  extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
  
  # Skip directories
  if [[ -d "$input_file" ]]; then
    return
  fi
  
  # Skip already optimized images folder
  if [[ "$input_file" == *"optimized"* ]]; then
    return
  fi
  
  # Set output file path based on mode
  if [[ "$REPLACE_MODE" == true ]]; then
    local output_file="${input_file}"
    local temp_file="${input_file}.temp"
  else
    local output_file="${OPTIMIZED_DIR}/${filename}"
  fi
  
  # Optimize based on file extension
  echo "🔧 Optimizing: ${filename}"
  
  case "$extension" in
    png)
      if [[ "$REPLACE_MODE" == true ]]; then
        pngquant --quality=65-85 --strip --speed 1 --force --output "$temp_file" "$input_file"
        mv "$temp_file" "$input_file"
      else
        pngquant --quality=65-85 --strip --speed 1 --output "$output_file" "$input_file"
      fi
      ;;
    jpg|jpeg)
      if command -v jpegoptim &> /dev/null; then
        if [[ "$REPLACE_MODE" == true ]]; then
          jpegoptim --strip-all --max=85 "$input_file"
        else
          cp "$input_file" "$output_file"
          jpegoptim --strip-all --max=85 "$output_file"
        fi
      else
        echo "⚠️  jpegoptim not installed. Install with 'brew install jpegoptim' for JPEG optimization."
        echo "   Skipping ${filename}"
      fi
      ;;
    gif)
      if command -v gifsicle &> /dev/null; then
        if [[ "$REPLACE_MODE" == true ]]; then
          gifsicle -O3 "$input_file" -o "$temp_file"
          mv "$temp_file" "$input_file"
        else
          gifsicle -O3 "$input_file" -o "$output_file"
        fi
      else
        echo "⚠️  gifsicle not installed. Install with 'brew install gifsicle' for GIF optimization."
        echo "   Skipping ${filename}"
      fi
      ;;
    svg)
      if command -v svgo &> /dev/null; then
        if [[ "$REPLACE_MODE" == true ]]; then
          svgo --multipass -i "$input_file" -o "$input_file"
        else
          svgo --multipass -i "$input_file" -o "$output_file"
        fi
      else
        echo "⚠️  svgo not installed. Install with 'npm install -g svgo' for SVG optimization."
        echo "   Skipping ${filename}"
      fi
      ;;
    *)
      echo "⚠️  Unsupported file format: ${extension} for ${filename}"
      echo "   Skipping ${filename}"
      ;;
  esac
  
  # Compare file sizes if not in replace mode
  if [[ "$REPLACE_MODE" == false && -f "$output_file" ]]; then
    local original_size=$(stat -f %z "$input_file")
    local optimized_size=$(stat -f %z "$output_file")
    
    if [ "$original_size" -gt 0 ]; then
      local saved_bytes=$((original_size - optimized_size))
      local saved_percent=$((saved_bytes * 100 / original_size))
      
      # Format sizes in human-readable format
      local original_hr
      local optimized_hr
      
      # Function to format file size in human-readable format
      format_size() {
        local size=$1
        local units=("B" "KB" "MB" "GB")
        local unit_index=0
        
        while [ $size -ge 1024 ] && [ $unit_index -lt 3 ]; do
          size=$((size / 1024))
          unit_index=$((unit_index + 1))
        done
        
        echo "${size}${units[$unit_index]}"
      }
      
      original_hr=$(format_size $original_size)
      optimized_hr=$(format_size $optimized_size)
      
      echo "   Original: ${original_hr}"
      echo "   Optimized: ${optimized_hr} (${saved_percent}% smaller)"
    fi
  fi
}

# Process all images in the source directory
process_images() {
  echo "🖼️  Processing images in: ${SOURCE_DIR}"
  
  # Find all image files
  find "$SOURCE_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.svg" \) | while read file; do
    optimize_image "$file"
  done
}

# Display summary when done
display_summary() {
  if [[ "$REPLACE_MODE" == false ]]; then
    echo "✨ Optimization complete! Optimized images are in: ${OPTIMIZED_DIR}"
    echo "🔍 Review the optimized images and manually replace the originals as needed"
    echo "💡 To automatically replace all images, run: ./optimize-images.sh --replace"
  else
    echo "✨ Optimization complete! All original images have been replaced with optimized versions"
  fi
}

# Main execution
echo "🚀 Starting image optimization..."
check_pngquant
setup_directories
process_images
display_summary