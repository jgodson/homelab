# Repository hooks

Enable the versioned hooks in each clone:

```bash
git config core.hooksPath .githooks
```

The pre-commit hook normalizes EXIF orientation and removes EXIF, XMP, and IPTC
metadata from staged JPEGs under `website/src/assets/images/`. It refuses to
process a partially staged image so it cannot accidentally include unstaged
changes.

The hook requires `exiftool` and `jpegtran`. On macOS with Homebrew:

```bash
brew install exiftool jpeg-turbo
```
