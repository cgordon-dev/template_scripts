#!/bin/bash

# Script: detect_and_push.sh
# Purpose: Detect new files in a specified directory and push changes to a GitHub repository.
# If the repository doesn't exist on GitHub, prompt the user to create one.
# Author: Carl A. Gordon

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 /path/to/directory"
    exit 1
fi

# Variables
WATCH_DIR=$1
GIT_USER=${GIT_USER:-""} # Use environment variable or default to empty
GIT_TOKEN=${GIT_TOKEN:-""} # Use environment variable or default to empty

# Ensure GitHub credentials are available
if [ -z "$GIT_USER" ] || [ -z "$GIT_TOKEN" ]; then
    echo "Error: GitHub username and/or personal access token are not set."
    echo "Please set the environment variables GIT_USER and GIT_TOKEN and try again."
    exit 1
fi

GIT_REPO_NAME=$(basename "$WATCH_DIR") # Default repository name as the directory name
GITHUB_API="https://api.github.com/user/repos"
GIT_REMOTE="https://$GIT_USER:$GIT_TOKEN@github.com/$GIT_USER/$GIT_REPO_NAME.git"

# Check if the specified directory exists
if [ ! -d "$WATCH_DIR" ]; then
    echo "Error: Directory $WATCH_DIR does not exist."
    exit 1
fi

# Detect new files in the directory
cd "$WATCH_DIR"
git init &>/dev/null  # Initialize git repository if not already initialized
git add . &>/dev/null
NEW_FILES=$(git status --porcelain | grep '^??' | awk '{print $2}')

if [ -z "$NEW_FILES" ]; then
    echo "No new files detected in $WATCH_DIR. No changes to push."
    exit 0
else
    echo "New files detected: $NEW_FILES"
    git add .
    git commit -m "Add new files: $NEW_FILES" &>/dev/null
fi

# Check if GitHub repository exists
REPO_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" -u "$GIT_USER:$GIT_TOKEN" "https://api.github.com/repos/$GIT_USER/$GIT_REPO_NAME")

if [ "$REPO_EXISTS" -ne 200 ]; then
    echo "GitHub repository does not exist."
    read -p "Would you like to create a new repository on GitHub? (yes/no): " CREATE_REPO
    if [ "$CREATE_REPO" != "yes" ]; then
        echo "No repository created. Exiting."
        exit 0
    fi
    echo "Creating a new GitHub repository..."
    curl -s -X POST -H "Authorization: token $GIT_TOKEN" -d "{\"name\": \"$GIT_REPO_NAME\"}" "$GITHUB_API" &>/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create GitHub repository."
        exit 1
    fi
    echo "Repository created successfully."
    git remote add origin "$GIT_REMOTE"
else
    echo "Pushing changes to the existing GitHub repository..."
    git remote add origin "$GIT_REMOTE" &>/dev/null || git remote set-url origin "$GIT_REMOTE"
fi

# Push changes to GitHub
git branch -M main
git push -u origin main &>/dev/null
if [ $? -eq 0 ]; then
    echo "Changes have been successfully pushed to GitHub."
else
    echo "Error: Failed to push changes to GitHub."
    exit 1
fi