@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion
title 卸载 AQ 官网服务器开机自启动

set "TASK_NAME=AQ-Website-Server"

echo ==============================================
echo   AQ 官网服务器 - 开机自启动卸载工具
echo ==============================================
echo.

echo [INFO] 检查计划任务是否存在...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [WARN] 未找到计划任务 %TASK_NAME%
    pause
    exit /b 0
)

echo [INFO] 删除计划任务...
schtasks /delete /tn "%TASK_NAME%" /f

if errorlevel 1 (
    echo [ERR] 删除计划任务失败，请以管理员身份运行此脚本
    pause
    exit /b 1
)

echo [OK] 计划任务已删除

echo.
echo ==============================================
echo   卸载完成！
echo ==============================================
echo.
echo   计划任务 : %TASK_NAME%
echo   状态     : 已删除
echo.
echo   如需重新安装，请运行 install_schedule.bat
echo ==============================================
echo.
pause
endlocal