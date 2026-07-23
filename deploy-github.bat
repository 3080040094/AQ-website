@echo off
chcp 65001 >nul 2>&1
title AQ Website GitHub Deploy

echo.
echo ==============================================
echo   AQ Website - GitHub Pages Deploy Tool
echo ==============================================
echo.

cd /d "d:\aq-website"

REM Step 1: Check images
echo [Step 1/4] Checking images...
if not exist "public\images" (
    echo [ERROR] public\images folder not found
    pause
    exit /b 1
)

if not exist "docs\images" mkdir "docs\images"
copy /Y "public\images\*.png" "docs\images\" >nul 2>&1
echo       Images copied: logo-bg.png, hero-bg.png, edit-bg.png

REM Step 2: Check Git
echo.
echo [Step 2/4] Checking Git...
where git >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git not found
    echo        Please install from: https://git-scm.com/download/win
    pause
    exit /b 1
)
echo       Git found

REM Step 3: Init repo
echo.
echo [Step 3/4] Initializing Git repository...
if not exist ".git" (
    git init
    echo       Repository initialized
) else (
    echo       Repository already exists
)

REM Step 4: Add files
echo.
echo [Step 4/4] Adding files to Git...
git add docs/ .gitignore 2>nul
git add public/images/*.png 2>nul
echo       Files added

echo.
echo ==============================================
echo   NEXT STEPS
echo ==============================================
echo.
echo   1. Create a GitHub repository at:
echo      https://github.com/new
echo      Name: aq-website (must be Public)
echo.
echo   2. Run these commands in this folder:
echo.
echo      git commit -m "init"
echo      git branch -M main
echo      git remote add origin https://github.com/YOUR_USERNAME/aq-website.git
echo      git push -u origin main
echo.
echo   3. Enable GitHub Pages:
echo      Settings ^> Pages ^> Source: Deploy from branch
echo      Branch: main /docs ^> Save
echo.
echo   4. Your site will be at:
echo      https://YOUR_USERNAME.github.io/aq-website
echo.
echo ==============================================
echo.
pause