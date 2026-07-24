# AQ录制官网服务器启动器 (PowerShell 版)
# 更稳健，不受 cmd 编码和 timeout 限制
# 用法: 右键 -> 使用 PowerShell 运行，或双击 start.bat 调用

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Root) { $Root = $PSScriptRoot }
if (-not $Root) { $Root = (Get-Location).Path }
Set-Location $Root

try { $Host.UI.RawUI.WindowTitle = "AQ录制官网服务器 v1.9.0" } catch {}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  AQ录制官网服务器启动器 v1.9.0" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# ===== 1. 检测 Node.js =====
$Node = $null
try { $Node = (Get-Command node -ErrorAction Stop).Source } catch {}
if (-not $Node -and (Test-Path "D:\kl\node.exe")) { $Node = "D:\kl\node.exe" }
if (-not $Node -and (Test-Path "$env:PROGRAMFILES\nodejs\node.exe")) { $Node = "$env:PROGRAMFILES\nodejs\node.exe" }
if (-not $Node -and (Test-Path "${env:PROGRAMFILES(x86)}\nodejs\node.exe")) { $Node = "${env:PROGRAMFILES(x86)}\nodejs\node.exe" }

if (-not $Node) {
    Write-Host "[错误] 未找到 Node.js" -ForegroundColor Red
    Write-Host "       请先安装: https://nodejs.org/zh-cn/download/"
    Read-Host "按回车退出"
    exit 1
}

$NodeVer = & $Node -v
Write-Host "[OK] Node.js: $Node" -ForegroundColor Green
Write-Host "     版本: $NodeVer"

# ===== 2. 检查依赖 =====
if (-not (Test-Path "$Root\node_modules\express")) {
    Write-Host ""
    Write-Host "[安装] 首次运行，正在安装依赖..." -ForegroundColor Yellow
    & npm install --registry=https://registry.npmmirror.com
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[错误] 依赖安装失败" -ForegroundColor Red
        Read-Host "按回车退出"
        exit 1
    }
    Write-Host "[OK] 依赖安装完成" -ForegroundColor Green
}

# ===== 3. 清理旧进程 =====
Write-Host ""
Write-Host "[清理] 停止旧服务..." -ForegroundColor Yellow
Get-Process -Name "node","bore" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

# ===== 4. 启动服务器 =====
Write-Host ""
Write-Host "[启动] 正在启动官网服务器..." -ForegroundColor Yellow
$env:PORT = "3000"
$serverProc = Start-Process -FilePath $Node -ArgumentList "server.js" -WorkingDirectory $Root -WindowStyle Minimized -PassThru
Write-Host "     等待服务器响应..."

$retry = 0
$maxRetry = 30
$serverOk = $false
while ($retry -lt $maxRetry) {
    Start-Sleep -Seconds 1
    $retry++
    try {
        $r = Invoke-WebRequest -Uri 'http://localhost:3000' -TimeoutSec 1 -UseBasicParsing
        if ($r.StatusCode -eq 200) { $serverOk = $true; break }
    } catch {}
}

if (-not $serverOk) {
    Write-Host "[错误] 服务器启动超时" -ForegroundColor Red
    Read-Host "按回车退出"
    exit 1
}
Write-Host "[OK] 服务器已启动 (耗时 $retry 秒)" -ForegroundColor Green

# ===== 5. 打开浏览器 =====
Write-Host ""
Write-Host "[浏览器] 正在打开浏览器..." -ForegroundColor Yellow
Start-Process "http://localhost:3000"

# ===== 6. 启动公网穿透 =====
$borePort = $null
$configPort = $null
if (Test-Path "$Root\bore.exe") {
    Write-Host ""
    Write-Host "[公网] 正在启动公网穿透..." -ForegroundColor Yellow

    # 读取配置文件获取固定端口
    if (Test-Path "$Root\config.json") {
        try {
            $config = Get-Content -Path "$Root\config.json" -Raw -Encoding utf8 | ConvertFrom-Json
            if ($config.borePort -and $config.borePort -gt 0) {
                $configPort = $config.borePort
                Write-Host "     配置固定端口: $configPort" -ForegroundColor Cyan
            }
        } catch {}
    }

    # 清空旧日志
    "" | Out-File -FilePath "$Root\bore.log" -Encoding utf8 -ErrorAction SilentlyContinue
    "" | Out-File -FilePath "$Root\bore_err.log" -Encoding utf8 -ErrorAction SilentlyContinue

    # 构建 bore 启动参数
    $boreArgs = @("local", "3000", "--to", "bore.pub")
    if ($configPort) {
        $boreArgs += "-p"
        $boreArgs += $configPort.ToString()
    }

    $boreProc = Start-Process -FilePath "$Root\bore.exe" -ArgumentList $boreArgs -RedirectStandardOutput "$Root\bore.log" -RedirectStandardError "$Root\bore_err.log" -WindowStyle Minimized -PassThru

    Write-Host "     等待获取公网端口..."
    for ($i = 1; $i -le 30; $i++) {
        Start-Sleep -Seconds 1
        $logContent = Get-Content -Path "$Root\bore.log" -Raw -ErrorAction SilentlyContinue
        if ($logContent) {
            $cleaned = $logContent -replace '\x1b\[[0-9;]*m', ''
            if ($cleaned -match 'listening at bore\.pub:(\d+)') {
                $borePort = $matches[1]
                if ($configPort -and $borePort -ne $configPort) {
                    Write-Host "[警告] 固定端口 $configPort 被占用，实际分配: $borePort" -ForegroundColor Yellow
                } else {
                    Write-Host "[OK] 公网端口获取成功 ($i 秒): $borePort" -ForegroundColor Green
                }
                break
            }
        }
    }
    if (-not $borePort) {
        Write-Host "[警告] 未能自动获取公网端口，请查看 bore.log" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "[跳过] 未找到 bore.exe，跳过公网穿透" -ForegroundColor Gray
}

# ===== 7. 显示最终结果 =====
Clear-Host
Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  AQ录制官网 v1.9.0  服务已就绪" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  官方QQ群 : 632984162"
Write-Host "  本地地址 : http://localhost:3000" -ForegroundColor White
if ($borePort) {
    Write-Host "  公网地址 : http://bore.pub:$borePort" -ForegroundColor Yellow
} elseif (Test-Path "$Root\bore.exe") {
    Write-Host "  公网地址 : 获取失败，请查看 bore.log" -ForegroundColor Red
} else {
    Write-Host "  公网地址 : 未配置公网穿透" -ForegroundColor Gray
}
Write-Host "  管理后台 : http://localhost:3000/login"
Write-Host "  管理员   : admin / admin123"
Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host " 关闭此窗口将停止所有服务" -ForegroundColor Yellow
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# ===== 8. 守护进程自动重启监控 =====
Write-Host "[守护] 进程守护已启用，崩溃自动重启" -ForegroundColor Cyan
Write-Host "        按 Ctrl+C 或关闭窗口停止服务" -ForegroundColor DarkGray
Write-Host ""

$restartCount = 0
while ($true) {
    # 每 5 秒检查 node 进程是否存活
    Start-Sleep -Seconds 5

    if ($serverProc.HasExited) {
        $restartCount++
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host ""
        Write-Host "[守护] $timestamp - 检测到服务器崩溃 (退出码: $($serverProc.ExitCode))" -ForegroundColor Red
        Write-Host "[守护] 第 $restartCount 次自动重启..." -ForegroundColor Yellow

        # 重启前先确保旧进程完全退出
        Get-Process -Name "node" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

        $env:PORT = "3000"
        $serverProc = Start-Process -FilePath $Node -ArgumentList "server.js" -WorkingDirectory $Root -WindowStyle Minimized -PassThru
        Write-Host "[守护] 服务器已重启 (PID: $($serverProc.Id))" -ForegroundColor Green

        # 验证重启成功
        $retry = 0
        $ok = $false
        while ($retry -lt 15) {
            Start-Sleep -Seconds 1
            $retry++
            try {
                $r = Invoke-WebRequest -Uri 'http://localhost:3000' -TimeoutSec 2 -UseBasicParsing
                if ($r.StatusCode -eq 200) { $ok = $true; break }
            } catch {}
        }
        if ($ok) {
            Write-Host "[守护] 服务恢复正常" -ForegroundColor Green
        } else {
            Write-Host "[守护] 重启后服务未响应，继续监控..." -ForegroundColor Yellow
        }
    }

    # 检查 bore 进程
    if ($boreProc -and $boreProc.HasExited) {
        Write-Host "[守护] 检测到 bore 隧道断开，正在重连..." -ForegroundColor Yellow
        $boreArgs = @("local", "3000", "--to", "bore.pub")
        if ($configPort) { $boreArgs += "-p"; $boreArgs += $configPort.ToString() }
        $boreProc = Start-Process -FilePath "$Root\bore.exe" -ArgumentList $boreArgs -RedirectStandardOutput "$Root\bore.log" -RedirectStandardError "$Root\bore_err.log" -WindowStyle Minimized -PassThru
    }
}

# ===== 9. 退出清理 =====

# ===== 9. 退出清理 =====
Write-Host ""
Write-Host "[清理] 正在停止所有服务..." -ForegroundColor Yellow
if ($serverProc -and -not $serverProc.HasExited) { Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue }
if ($boreProc -and -not $boreProc.HasExited) { Stop-Process -Id $boreProc.Id -Force -ErrorAction SilentlyContinue }
Get-Process -Name "node","bore" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "[完成] 所有服务已停止" -ForegroundColor Green
Start-Sleep -Seconds 2
