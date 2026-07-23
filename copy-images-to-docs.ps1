# 复制图片到 docs 目录（用于 GitHub Pages 部署）
$source = 'd:\aq-website\public\images'
$dest = 'd:\aq-website\docs\images'

if (-not (Test-Path $source)) {
    Write-Host "[错误] 源目录不存在: $source" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Write-Host "[创建] 目录: $dest" -ForegroundColor Green
}

Get-ChildItem $source -File | ForEach-Object {
    $target = Join-Path $dest $_.Name
    Copy-Item $_.FullName $target -Force
    Write-Host "[复制] $($_.Name) ($([math]::Round($_.Length/1KB,1)) KB)" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "[完成] 图片已复制到 docs/images/" -ForegroundColor Green
Write-Host "现在可以推送到 GitHub 并开启 Pages 了" -ForegroundColor Yellow
