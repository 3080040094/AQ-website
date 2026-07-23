@echo off
chcp 65001 >nul 2>&1
title AQ Website - Upload to GitHub

cd /d "d:\aq-website"

echo.
echo ==============================================
echo   AQ Website - Upload to GitHub
echo   Repository: https://github.com/3080040094/aq-website
echo ==============================================
echo.

REM Step 1: Copy images
echo [1/5] Copying images to docs...
if not exist "docs\images" mkdir "docs\images"
copy /Y "public\images\*.png" "docs\images\" >nul 2>&1
echo      Done

REM Step 2: Init Git
echo.
echo [2/5] Initializing Git repository...
if exist ".git" (
    echo      Repository exists
) else (
    git init
    echo      Repository created
)

REM Step 3: Add files
echo.
echo [3/5] Adding files...
git add docs/ .gitignore 2>nul
git add public/images/*.png 2>nul
echo      Files staged

REM Step 4: Commit
echo.
echo [4/5] Creating commit...
git commit -m "AQ录制官网 v1.7.18 - GitHub Pages" 2>nul
if errorlevel 1 (
    echo      Nothing to commit or commit exists
) else (
    echo      Committed
)

REM Step 5: Setup remote
echo.
echo [5/5] Setting up remote...
git remote remove origin 2>nul
git remote add origin https://github.com/3080040094/aq-website.git
git branch -M main
echo      Remote configured

echo.
echo ==============================================
echo   READY TO UPLOAD
echo ==============================================
echo.
echo   Run this command to upload:
echo.
echo   git push -u origin main
echo.
echo   If prompted for credentials:
echo   - Username: 3080040094
echo   - Password: Use Personal Access Token (NOT your password)
echo.
echo   Create token at: https://github.com/settings/tokens/new
echo   Select scopes: repo (all)
echo.
echo ==============================================
echo.
pause