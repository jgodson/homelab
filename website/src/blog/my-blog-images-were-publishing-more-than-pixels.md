---
title: My Blog Images Were Publishing More Than Pixels
description: Photos can quietly include precise location data. Here is how I check for it and strip it automatically before an image leaves my computer.
date: 2026-10-11
tags:
  - website
  - privacy
  - scripting
cover: ./src/assets/images/featured-note-image-metadata.jpg
coverAlt: An illustrated magnifying glass revealing location, direction, time, and camera symbols hidden beneath a landscape photo
layout: post.njk
---

A photo is easy to think of as just pixels. Depending on the camera and the software it has passed through, though, the file may also contain where it was taken, when it was taken, which direction the camera was pointing, and what device or software created it.

That is useful when the photo is sitting in my library. It is much less useful when I am putting the same file on a public website.

{% image "./src/assets/images/featured-note-image-metadata.jpg", "An illustrated magnifying glass revealing location, direction, time, and camera symbols hidden beneath a landscape photo", "(min-width: 768px) 900px, 100vw" %}

## More Than I Expected

I checked some of my images with [ExifTool](https://exiftool.org/) and found output like this. These are reconstructed sample values; the identifying details have been deliberately changed.

```text
GPS Date Stamp                  : 2030:01:02
GPS Time Stamp                  : 03:04:05
GPS Speed                       : 0
GPS Img Direction Ref           : True North
GPS Img Direction               : 246.813579
GPS Horizontal Positioning Error: 9.87654321 m
GPS Altitude                    : 321.0 m Above Sea Level
GPS Latitude                    : 12 deg 34' 56.78" N
GPS Longitude                   : 98 deg 45' 12.34" W
GPS Position                    : 12 deg 34' 56.78" N, 98 deg 45' 12.34" W
```

That is enough information to identify a location quite precisely. The timestamp and direction can add even more context, and other photos may include the camera model, editing software, or author information.

The check itself is simple:

```bash
exiftool -GPS:all -EXIF:all -XMP:all -IPTC:all photo.jpg
```

## Making the Safe Choice Automatic

Remembering to clean every image manually is not a system I trust, so I added a versioned pre-commit hook to this site's repository. For staged JPEGs in the site's image folder it:

- Reads and applies the EXIF orientation without re-encoding the image
- Removes EXIF, XMP, and IPTC metadata
- Verifies that the metadata is gone
- Re-stages the cleaned image
- Refuses partially staged images rather than guessing which copy I meant to commit

The hook uses `jpegtran` to preserve the visible orientation before ExifTool removes the orientation tag. Without that step, a portrait photo can suddenly appear sideways after its metadata is stripped.

The dependencies and repository hook are enabled with:

```bash
brew install exiftool jpeg-turbo
git config core.hooksPath .githooks
```

The [normalization script](https://github.com/jgodson/homelab/blob/main/scripts/normalize-image-metadata.sh) and [pre-commit hook](https://github.com/jgodson/homelab/blob/main/.githooks/pre-commit) are in the repository if you want the complete implementation.

This is still a guardrail, not magic. A local hook has to be enabled and can be bypassed. CI can stop an image from reaching the live site, but by the time CI runs, the file has already reached the Git remote. For a public repository, the important check happens before the push.

## Takeaway

If an image is going online, inspect the file rather than assuming an export or upload process cleaned it. Better yet, automate the check at the point where the image enters your publishing workflow.

The picture should be the only thing the file publishes.

Until next time, keep on building!
