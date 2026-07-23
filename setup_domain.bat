@echo off
chcp 65001 >nul 2>&1
title 设置 AQ录制 官方域名

echo ==============================================
echo   AQ录制 官方域名设置
echo ==============================================
echo.
echo 本脚本将设置 http://aq.luzhi.com 指向本地服务器
echo 需要管理员权限
echo.

pause

echo [INFO] 检查当前 hosts 设置...
findstr /i "aq.luzhi.com" "C:\Windows\System32\drivers\etc\hosts" >nul
if %errorlevel% equ 0 (
    echo [WARN] hosts 中已存在 aq.luzhi.com 设置
    echo [INFO] 跳过 hosts 修改
) else (
    echo [INFO] 添加 hosts 映射...
    echo. >> "C:\Windows\System32\drivers\etc\hosts"
    echo # AQ录制官网 >> "C:\Windows\System32\drivers\etc\hosts"
    echo 127.0.0.1 aq.luzhi.com >> "C:\Windows\System32\drivers\etc\hosts"
    echo 127.0.0.1 www.aq.luzhi.com >> "C:\Windows\System32\drivers\etc\hosts"
    if %errorlevel% equ 0 (
        echo [OK] hosts 设置成功
    ) else (
        echo [ERR] hosts 设置失败，请以管理员身份运行本脚本
        pause
        exit /b 1
    )
)

echo.
echo [INFO] 刷新 DNS 缓存...
ipconfig /flushdns >nul 2>&1
echo [OK] DNS 缓存已刷新

echo.
echo ==============================================
echo   设置完成！
echo ==============================================
echo.
echo   官方网站 : http://aq.luzhi.com
echo   本地地址 : http://localhost:8080
echo.
echo ==============================================

pause