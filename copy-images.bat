@echo off
chcp 65001 >nul 2>&1
title Copy Images to docs

echo.
echo ==============================================
echo   Copying images to docs folder...
echo ==============================================
echo.

if not exist "d:\aq-website\public\images" (
    echo [ERROR] Source folder not found: public\images
    pause
    exit /b 1
)

if not exist "d:\aq-website\docs\images" mkdir "d:\aq-website\docs\images"

copy /Y "d:\aq-website\public\images\*.png" "d:\aq-website\docs\images\" >nul

echo [OK] Images copied to docs\images\
echo.

dir "d:\aq-website\docs\images" /b

echo.
echo ==============================================
echo   Done! Now you can push to GitHub.
echo ==============================================
echo.
pause