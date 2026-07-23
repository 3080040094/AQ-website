@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion
title 安装 AQ 官网服务器开机自启动

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "MONITOR_SCRIPT=%ROOT%\monitor.ps1"
set "TASK_NAME=AQ-Website-Server"

if not exist "%MONITOR_SCRIPT%" (
    echo [ERR] monitor.ps1 不存在于 %MONITOR_SCRIPT%
    pause
    exit /b 1
)

echo ==============================================
echo   AQ 官网服务器 - 开机自启动安装工具
echo ==============================================
echo.
echo   脚本路径 : %MONITOR_SCRIPT%
echo   任务名称 : %TASK_NAME%
echo.

echo [INFO] 检查是否已有同名计划任务...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if not errorlevel 1 (
    echo [WARN] 发现已存在同名计划任务，将先删除
    schtasks /delete /tn "%TASK_NAME%" /f
    if not errorlevel 1 (
        echo [OK] 已删除旧任务
    ) else (
        echo [ERR] 删除旧任务失败
        pause
        exit /b 1
    )
)

echo.
echo [INFO] 创建计划任务...

schtasks /create /tn "%TASK_NAME%" ^
    /tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""%MONITOR_SCRIPT%""" ^
    /sc onstart ^
    /ru SYSTEM ^
    /rl highest ^
    /f ^
    /delay 0000:30

if errorlevel 1 (
    echo [ERR] 创建计划任务失败，请以管理员身份运行此脚本
    pause
    exit /b 1
)

echo [OK] 计划任务创建成功

echo.
echo [INFO] 验证任务状态...
schtasks /query /tn "%TASK_NAME%" /v | findstr "任务名称 状态"

echo.
echo ==============================================
echo   安装完成！
echo ==============================================
echo.
echo   计划任务 : %TASK_NAME%
echo   触发条件 : 系统启动后延迟 30 秒
echo   运行身份 : SYSTEM (最高权限)
echo   脚本路径 : %MONITOR_SCRIPT%
echo.
echo   手动启动 : 双击 start.bat
echo   查看日志 : monitor.log
echo.
echo   卸载方法 : 运行 uninstall_schedule.bat
echo ==============================================
echo.
pause
endlocal