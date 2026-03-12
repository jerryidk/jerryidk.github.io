#!/bin/bash

# Check if a name was provided
if [ -z "$1" ]; then
    echo "Usage: ./new-article.sh <article-slug>"
    exit 1
fi

SLUG=$1
FILENAME="content/$SLUG.md"
DATE=$(date +%Y-%m-%d)
# Simple title case conversion: "my-post" -> "My Post"
TITLE=$(echo $SLUG | sed 's/-/ /g' | sed -e 's/\b\(.\)/\u\1/g')

# Don't overwrite existing work!
if [ -f "$FILENAME" ]; then
    echo "Error: $FILENAME already exists."
    exit 1
fi

# Generate the file with the summary tag
cat <<EOF > "$FILENAME"
+++
title = "$TITLE"
date = $DATE
draft = false 

[taxonomies]
tags = ["none"]
+++

description
<!-- more -->

Content 
EOF

echo "Successfully created: $FILENAME"
