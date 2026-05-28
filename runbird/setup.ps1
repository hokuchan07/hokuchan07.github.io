# RUNBIRD 自動同期 ワンコマンドセットアップ (Windows)
# 使い方: irm 'https://hokuchan07.github.io/runbird/setup.ps1' | iex

$ErrorActionPreference = "Stop"

Write-Host "=== RUNBIRD 自動同期セットアップ (Windows) ===" -ForegroundColor Cyan
Write-Host ""

# 1. Workspace 検出（なければ自動構築）
$workspace = $null
$candidates = @("C:\git\runbird-knowledge", "$HOME\Documents\runbird-knowledge")
foreach ($c in $candidates) {
    if (Test-Path $c) { $workspace = $c; break }
}
if (-not $workspace) {
    Write-Host "[INFO] workspace 未構築 → runbird-setup.ps1 を先に実行します" -ForegroundColor Yellow
    Write-Host ""
    Invoke-RestMethod -Uri 'https://hokuchan07.github.io/runbird/runbird-setup.ps1' | Invoke-Expression
    Write-Host ""
    foreach ($c in $candidates) {
        if (Test-Path $c) { $workspace = $c; break }
    }
    if (-not $workspace) {
        Write-Host "[ERROR] workspace 構築に失敗しました。GitHub Org 招待を承認しているか確認してください。" -ForegroundColor Red
        return
    }
}

# 2. core.pager 設定（git log で less ハング回避）
git config --global core.pager ""
Write-Host "[OK] core.pager を空に設定（git log のハング防止）"

# 3. git user.name / user.email 設定
$name  = git config --global user.name  2>$null
$email = git config --global user.email 2>$null

if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($email)) {
    $configured = $false

    # gh CLI で自動取得を試みる
    try {
        $ghLogin = gh api user --jq '.login' 2>$null
        $ghId    = gh api user --jq '.id' 2>$null
        if ($ghLogin -and $ghId) {
            git config --global user.name $ghLogin
            git config --global user.email "$ghId+$ghLogin@users.noreply.github.com"
            Write-Host "[OK] gh CLI から自動設定: $ghLogin <$ghId+$ghLogin@users.noreply.github.com>" -ForegroundColor Green
            $configured = $true
        }
    } catch { }

    if (-not $configured) {
        Write-Host "[要入力] GitHub username を入力してください:" -ForegroundColor Yellow
        $ghLogin = Read-Host "GitHub username"
        git config --global user.name $ghLogin
        git config --global user.email "$ghLogin@users.noreply.github.com"
        Write-Host "[OK] 手動設定: $ghLogin" -ForegroundColor Green
    }
} else {
    Write-Host "[既設定] user.name=$name / user.email=$email"
}

# 4. sync ディレクトリと sync.ps1 ダウンロード
$syncDir    = "$HOME\.runbird"
$logDir     = "$HOME\runbird-sync-logs"
$syncScript = "$syncDir\sync.ps1"

New-Item -ItemType Directory -Path $syncDir, $logDir -Force | Out-Null
Invoke-RestMethod -Uri 'https://hokuchan07.github.io/runbird/sync.ps1' -OutFile $syncScript
Write-Host "[OK] sync.ps1 をダウンロード → $syncScript"

# 5. Task Scheduler 登録（スリープ後の自動キャッチアップ対応）
Get-ScheduledTask -TaskName "RunbirdSync-Pull" -EA SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
Get-ScheduledTask -TaskName "RunbirdSync-Push" -EA SilentlyContinue | Unregister-ScheduledTask -Confirm:$false

$pwsh = (Get-Command powershell).Source
$a1 = New-ScheduledTaskAction  -Execute $pwsh -Argument "-ExecutionPolicy Bypass -File `"$syncScript`" pull"
$a2 = New-ScheduledTaskAction  -Execute $pwsh -Argument "-ExecutionPolicy Bypass -File `"$syncScript`" push"
$t1 = New-ScheduledTaskTrigger -Daily -At "06:05"
$t2 = New-ScheduledTaskTrigger -Daily -At "20:00"
# StartWhenAvailable: スリープ/シャットダウンで時刻を逃しても、次に PC が利用可能になった時点で走る
# AllowStartIfOnBatteries: バッテリー駆動時も走る
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
Register-ScheduledTask -TaskName "RunbirdSync-Pull" -Action $a1 -Trigger $t1 -Settings $settings -Force | Out-Null
Register-ScheduledTask -TaskName "RunbirdSync-Push" -Action $a2 -Trigger $t2 -Settings $settings -Force | Out-Null
Write-Host "[OK] Task Scheduler 登録: 朝6:05 pull / 夜20:00 push（スリープ中は次回起動時に自動キャッチアップ）"

# 6. 即実行テスト
Write-Host ""
Write-Host "=== 動作テスト実行中... ===" -ForegroundColor Cyan
& $pwsh -ExecutionPolicy Bypass -File $syncScript both
Write-Host ""

# 7. 完了
Write-Host "=== セットアップ完了 ===" -ForegroundColor Green
Write-Host "ログ確認: notepad $logDir\$(Get-Date -Format yyyy-MM-dd).log"
