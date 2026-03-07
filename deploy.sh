#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "🚀 Compiling Flutter Web Build..."
# Compile for GitHub Pages, setting the base href to the repository name
flutter build web --base-href "/track-timer-web/"

echo "📦 Committing source code to main branch..."
git add .
git commit -m "Update app source and web build" || echo "No changes to commit"
git push -u origin main

echo "🌐 Deploying to GitHub Pages (gh-pages branch)..."
# Push the compiled web folder to the gh-pages branch
git subtree push --prefix build/web origin gh-pages

echo "✅ Deployment complete! Allow 1-2 minutes for GitHub Actions to refresh the live site."
