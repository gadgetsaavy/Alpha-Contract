@echo off

git init
git remote add origin https://github.com/gadgetsaavy/Alpha-Contract.git
git add .


git commit -m "Initial commit - Creating Directory Structure."

git branch -M main
git push -u origin main

pause
