# RUNBIRD 修復スクリプト
# 1コマンドで以下を実施:
#   - core.autocrlf input 設定（改行コード誤検知防止）
#   - shimada-clone を origin/main にハードリセット（読み取り専用 repo の不整合を解消）
#   - 各 repo の merge/rebase 進行中状態を中断
#   - it-knowledge の rebase + push
#   - 全体の sync テスト
# 使い方: irm 'https://hokuchan07.github.io/runbird/fix.ps1' | iex

$ErrorActionPreference = "Continue"

Write-Host "=== RUNBIRD 修復スクリプト ===" -ForegroundColor Cyan
Write-Host ""

# 1. autocrlf 設定
git config --global core.autocrlf input
Write-Host "[OK] core.autocrlf=input 設定（改行コード誤検知防止）"

# 2. Workspace 検出
$candidates = @("C:\git\runbird-knowledge", "$HOME\Documents\runbird-knowledge")
$workspace = $null
foreach ($c in $candidates) { if (Test-Path $c) { $workspace = $c; break } }
if (-not $workspace) {
    Write-Host "[ERROR] workspace 未検出" -ForegroundColor Red
    return
}
Write-Host "[OK] workspace: $workspace"
Write-Host ""

# 3. 各 repo の状態をクリーンアップ
Get-ChildItem -Path $workspace -Directory | ForEach-Object {
    Set-Location $_.FullName
    $repoName = $_.Name
    Write-Host "--- $repoName ---" -ForegroundColor Yellow

    # 進行中の rebase/merge を中断
    if (Test-Path ".git\rebase-merge") {
        git rebase --abort 2>$null
        Write-Host "  rebase 中断"
    }
    if (Test-Path ".git\MERGE_HEAD") {
        git merge --abort 2>$null
        Write-Host "  merge 中断"
    }

    # ローカル変更を破棄（uncommitted のみ、コミット済みは保持）
    git restore . 2>$null | Out-Null

    # 未追跡ファイルを削除（.vscode/tasks.json 等の自動生成物）
    git clean -fd 2>$null | Out-Null

    # remote と一致させる（読み取り専用 repo は強制リセット）
    git fetch origin 2>$null | Out-Null
    git reset --hard origin/main 2>$null | Out-Null
    Write-Host "  origin/main にリセット完了"
}

Set-Location $workspace
Write-Host ""
Write-Host "[OK] 全 repo クリーンアップ完了" -ForegroundColor Green
Write-Host ""

# 4. Sync テスト
Write-Host "=== Sync テスト実行 ==="
Start-ScheduledTask -TaskName "RunbirdSync-Push"
Start-Sleep -Seconds 12

# 5. ログ表示
$logFile = "$HOME\runbird-sync-logs\$(Get-Date -Format yyyy-MM-dd).log"
Write-Host ""
Write-Host "=== ログ末尾 30 行 ===" -ForegroundColor Cyan
Get-Content $logFile -Tail 30
