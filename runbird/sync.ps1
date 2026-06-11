# RUNBIRD 自動同期スクリプト (Windows)
# 呼び出し: powershell -ExecutionPolicy Bypass -File $HOME\.runbird\sync.ps1 [pull|push|both]
# setup.ps1 からダウンロードされて配置される

param([string]$Mode = "both")

$candidates = @("C:\git\runbird-knowledge", "$HOME\Documents\runbird-knowledge")
$workspace = $null
foreach ($c in $candidates) { if (Test-Path $c) { $workspace = $c; break } }
if (-not $workspace) { exit }

$logFile = "$HOME\runbird-sync-logs\$(Get-Date -Format yyyy-MM-dd).log"
New-Item -ItemType Directory -Path (Split-Path $logFile) -Force | Out-Null

Add-Content $logFile ""
Add-Content $logFile "===== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') mode=$Mode ====="

Get-ChildItem -Path $workspace -Directory | ForEach-Object {
    $repoPath = $_.FullName
    $repoName = $_.Name
    if (-not (Test-Path "$repoPath\.git")) { return }

    Set-Location $repoPath
    Add-Content $logFile "--- $repoName ---"

    if ($Mode -eq "pull" -or $Mode -eq "both") {
        # rebase中断が残っていたら自動復旧（過去事故対策）
        if ((Test-Path ".git\rebase-merge") -or (Test-Path ".git\rebase-apply")) {
            git rebase --abort 2>$null
            Add-Content $logFile "  [rebase中断を検知 → abortして続行]"
        }
        # 設定の重複（Cannot rebase/merge multiple branches の原因）を正規化
        $br = (git rev-parse --abbrev-ref HEAD).Trim()
        $merges = @(git config --get-all "branch.$br.merge" 2>$null)
        if ($merges.Count -gt 1) {
            git config --unset-all "branch.$br.merge"
            git config "branch.$br.merge" "refs/heads/$br"
            Add-Content $logFile "  [branch.$br.merge の重複を正規化]"
        }
        $out = (git -c pull.rebase=false -c merge.autoStash=true pull --no-edit origin $br 2>&1 | Select-Object -Last 3 | Out-String).TrimEnd()
        Add-Content $logFile $out
    }

    if ($Mode -eq "push" -or $Mode -eq "both") {
        $status = git status --porcelain
        if ($status) {
            git add -A | Out-Null
            $msg = "auto-sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            $commitOut = (git commit -m $msg 2>&1 | Select-Object -Last 2 | Out-String).TrimEnd()
            Add-Content $logFile $commitOut
        }
        $pushOut = (git push 2>&1 | Out-String).TrimEnd()
        if ($pushOut -match "403|Write access") {
            Add-Content $logFile "  [skip: push権限なし]"
        } elseif ($pushOut -match "Could not connect|Failed to connect|timed out") {
            Add-Content $logFile "  [skip: ネットワーク失敗（次回リトライ）]"
        } else {
            Add-Content $logFile $pushOut
        }
    }
}
