#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "🧹 Cleaning and resolving dependencies..."
flutter clean
flutter pub get

echo "🚀 Compiling Flutter Web Build..."
# Compile for GitHub Pages, setting the base href to the repository name
flutter build web --base-href "/track-timer-web/" --release

echo "📦 Committing source code to main branch..."
git add .
git commit -m "Update app source and assets" || echo "No changes to commit"
git push -u origin main

echo "🌐 Deploying to GitHub Pages..."
cd build/web

# Initialize a temp repo to force-push ignored build files
git init
git add .
git commit -m "Production Build: $(date)"
git remote add origin https://github.com/srs7b/track-timer-web.git
git push -f origin HEAD:gh-pages

echo "✅ Deployment complete! Audio assets should now be live."
