# RUNBIRD ナレッジAI 自動同期セットアップ (Windows)
# 実行: iwr -useb https://hokuchan07.github.io/runbird/runbird-sync-setup.ps1 | iex
#
# やること:
# 1) git user.name / user.email が未設定なら対話で設定（GitHub と紐付くように）
# 2) runbird-knowledge 配下の各 repo を
#    - 朝 6:05 → git pull
#    - 夜 20:00 → 変更があれば commit + push
# 3) ログは ~\runbird-sync-logs\ に日付別で記録

$ErrorActionPreference = "Stop"

# Workspace 探索（C:\git\runbird-knowledge を優先、なければ ~\Documents\runbird-knowledge）
$candidates = @("C:\git\runbird-knowledge", "$HOME\Documents\runbird-knowledge")
$workspace = $null
foreach ($c in $candidates) {
    if (Test-Path $c) { $workspace = $c; break }
}

if (-not $workspace) {
    Write-Host "エラー: runbird-knowledge ディレクトリが見つかりません" -ForegroundColor Red
    Write-Host "先に runbird-setup.ps1 を実行してください："
    Write-Host "  iwr -useb https://hokuchan07.github.io/runbird/runbird-setup.ps1 | iex"
    exit 1
}

$syncDir    = "$HOME\.runbird"
$logDir     = "$HOME\runbird-sync-logs"
$syncScript = "$syncDir\sync.ps1"

New-Item -ItemType Directory -Path $syncDir -Force | Out-Null
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

Write-Host "=== RUNBIRD 自動同期セットアップ (Windows) ===" -ForegroundColor Cyan
Write-Host "対象: $workspace"
Write-Host ""

# --- Step 1: git config ---
$name  = $(git config --global user.name)  2>$null
$email = $(git config --global user.email) 2>$null

if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($email)) {
    Write-Host "[必要] Git の user.name / user.email を設定します" -ForegroundColor Yellow
    Write-Host ""
    $ghUser = Read-Host "GitHub のユーザー名を入力してください (例: RyuSaito00)"
    Write-Host "GitHub に登録済みのメールアドレスを入力してください"
    Write-Host "（公開していない場合は ${ghUser}@users.noreply.github.com も使えます）"
    $ghEmail = Read-Host "Email"
    git config --global user.name  $ghUser
    git config --global user.email $ghEmail
    Write-Host "[設定完了] user.name = $ghUser / user.email = $ghEmail" -ForegroundColor Green
} else {
    Write-Host "[既設定] user.name = $name / user.email = $email" -ForegroundColor Green
}
Write-Host ""

# --- Step 2: 同期スクリプト本体を生成 ---
$syncBody = @"
param([string]`$Mode = "both")

`$workspace = "$workspace"
`$logFile   = "`$HOME\runbird-sync-logs\`$(Get-Date -Format 'yyyy-MM-dd').log"

if (-not (Test-Path `$workspace)) { exit }

Add-Content `$logFile ""
Add-Content `$logFile "===== `$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') mode=`$Mode ====="

Get-ChildItem -Path `$workspace -Directory | ForEach-Object {
    `$repoPath = `$_.FullName
    if (-not (Test-Path "`$repoPath\.git")) { return }

    Set-Location `$repoPath
    Add-Content `$logFile "--- `$(`$_.Name) ---"

    if (`$Mode -eq "pull" -or `$Mode -eq "both") {
        `$out = git -c pull.rebase=false -c merge.autoStash=true pull --no-edit origin main 2>&1 | Out-String
        Add-Content `$logFile `$out
    }

    if (`$Mode -eq "push" -or `$Mode -eq "both") {
        `$status = git status --porcelain
        if (`$status) {
            git add -A | Out-Null
            `$msg = "auto-sync: `$(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            `$out = git commit -m `$msg 2>&1 | Out-String
            Add-Content `$logFile `$out
        }
        `$out = git push 2>&1 | Out-String
        Add-Content `$logFile `$out
    }
}
"@

Set-Content -Path $syncScript -Value $syncBody -Encoding UTF8
Write-Host "[作成] $syncScript"
Write-Host ""

# --- Step 3: Task Scheduler 登録 ---
$pwsh = (Get-Command powershell).Source

# 既存タスク削除
Get-ScheduledTask -TaskName "RunbirdSync-Pull" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
Get-ScheduledTask -TaskName "RunbirdSync-Push" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false

# Pull at 6:05
$pullAction  = New-ScheduledTaskAction  -Execute $pwsh -Argument "-ExecutionPolicy Bypass -File `"$syncScript`" pull"
$pullTrigger = New-ScheduledTaskTrigger -Daily -At 6:05am
Register-ScheduledTask -TaskName "RunbirdSync-Pull" -Action $pullAction -Trigger $pullTrigger -Force | Out-Null

# Push at 20:00
$pushAction  = New-ScheduledTaskAction  -Execute $pwsh -Argument "-ExecutionPolicy Bypass -File `"$syncScript`" push"
$pushTrigger = New-ScheduledTaskTrigger -Daily -At 8:00pm
Register-ScheduledTask -TaskName "RunbirdSync-Push" -Action $pushAction -Trigger $pushTrigger -Force | Out-Null

Write-Host "[登録] Task Scheduler:" -ForegroundColor Green
Write-Host "  - 朝 6:05 → 全 repo を git pull"
Write-Host "  - 夜 20:00 → 変更があれば commit + push"
Write-Host ""
Write-Host "[完了] ログは $logDir\ に日付別で記録されます"
Write-Host ""
Write-Host "今すぐ動作確認したい場合:"
Write-Host "  powershell -File `"$syncScript`" both"
