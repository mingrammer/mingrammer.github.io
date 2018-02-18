#!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

msg="Rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi

# Commit changes to hugo branch
git commit -m "$msg"

# Build the project.
hugo # if using a theme, replace with `hugo -t <YOURTHEME>`

# Go To Public folder
cd public
# Add changes to git.
git add .

# Commit changes to master branch
git commit -m "$msg"

# Push source and build repos.
git push origin master

# Come Back up to the Project Root
cd ..
