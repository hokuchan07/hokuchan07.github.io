# RUNBIRD ナレッジAI 統合ワークスペース セットアップスクリプト (Windows版)
# 実行：PowerShellで以下を貼り付け
#   irm https://hokuchan07.github.io/runbird/runbird-setup.ps1 | iex
#
# やること：
# 1) C:\git\runbird-knowledge\ を作成（OneDrive配下を避ける）
# 2) アクセスできるrepoを自動clone（権限ないものはスキップ）
# 3) Cursor用の統合ワークスペースファイル(runbird.code-workspace)を生成
# 4) 1ウィンドウで自分の権限内ナレッジが全部見える状態にする

$ErrorActionPreference = "Continue"

$WorkspaceDir = "C:\git\runbird-knowledge"
Write-Host "=== RUNBIRD ナレッジAI 統合ワークスペース セットアップ (Windows) ===" -ForegroundColor Cyan
Write-Host "配置先: $WorkspaceDir"
Write-Host ""

# git の存在確認
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "エラー: git がインストールされていません。" -ForegroundColor Red
    Write-Host "https://git-scm.com/download/win からインストールしてください。" -ForegroundColor Red
    exit 1
}

# 作業ディレクトリ作成
if (-not (Test-Path $WorkspaceDir)) {
    New-Item -ItemType Directory -Force -Path $WorkspaceDir | Out-Null
}
Set-Location $WorkspaceDir

# 全リポジトリ候補
$RepoList = @(
    @{ Repo = "runbird-welfare-knowledge"; Name = "① 福祉ナレッジ" }
    @{ Repo = "runbird-it-knowledge";      Name = "② IT営業ナレッジ" }
    @{ Repo = "runbird-hr-knowledge";      Name = "③ 人事面談" }
    @{ Repo = "runbird-contracts";         Name = "④ 契約書" }
    @{ Repo = "runbird-shimada-clone";     Name = "⑤ 社長クローン" }
)

$IncludedRepos = @()
$IncludedNames = @()

foreach ($entry in $RepoList) {
    $repo = $entry.Repo
    $name = $entry.Name

    if (Test-Path $repo) {
        Write-Host "[更新] $repo (既存・git pull)" -ForegroundColor Yellow
        Push-Location $repo
        git pull --rebase --autostash 2>&1 | Select-Object -Last 2
        Pop-Location
        $IncludedRepos += $repo
        $IncludedNames += $name
    } else {
        Write-Host "[clone] $repo を取得中..." -ForegroundColor Green
        git clone "https://github.com/runbird-inc/$repo.git" 2>&1 | Select-Object -Last 2
        if (Test-Path $repo) {
            Write-Host "  → 成功 ($name)" -ForegroundColor Green
            $IncludedRepos += $repo
            $IncludedNames += $name
        } else {
            Write-Host "  → 権限なし or アクセス不可（スキップ）" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

if ($IncludedRepos.Count -eq 0) {
    Write-Host "エラー: アクセスできるリポジトリがありませんでした。" -ForegroundColor Red
    Write-Host "GitHub Org招待を承認しているか確認してください:" -ForegroundColor Red
    Write-Host "  https://github.com/runbird-inc" -ForegroundColor Red
    exit 1
}

# Cursor統合ワークスペースファイル生成
# 注意: irm | iex でPowerShell 5.1が日本語をCP932誤解釈してmojibakeになるため、
#       スクリプト内に日本語文字列を書かず、GitHub Pagesから正しいUTF-8 JSONを
#       バイナリダウンロードする方式に変更
$WorkspaceFile = Join-Path $WorkspaceDir "runbird.code-workspace"

try {
    Invoke-WebRequest -Uri "https://hokuchan07.github.io/runbird/runbird.code-workspace" -OutFile $WorkspaceFile -UseBasicParsing
} catch {
    Write-Host "警告: workspace JSONテンプレートのダウンロードに失敗しました。" -ForegroundColor Yellow
    Write-Host "手動で以下を実行してください:" -ForegroundColor Yellow
    Write-Host "  Invoke-WebRequest -Uri https://hokuchan07.github.io/runbird/runbird.code-workspace -OutFile $WorkspaceFile" -ForegroundColor Yellow
}

# 各repoにフォルダオープン時の自動pullタスクを設定
$tasksJsonContent = @'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "ナレッジを最新に更新（git pull）",
      "type": "shell",
      "command": "git pull --rebase --autostash",
      "presentation": { "reveal": "silent", "panel": "dedicated", "showReuseMessage": false, "clear": true, "close": true },
      "runOptions": { "runOn": "folderOpen" },
      "problemMatcher": []
    }
  ]
}
'@

foreach ($repo in $IncludedRepos) {
    $tasksPath = Join-Path $WorkspaceDir "$repo\.vscode\tasks.json"
    if (-not (Test-Path $tasksPath)) {
        $vscodeDir = Join-Path $WorkspaceDir "$repo\.vscode"
        New-Item -ItemType Directory -Force -Path $vscodeDir | Out-Null
        [System.IO.File]::WriteAllText($tasksPath, $tasksJsonContent, (New-Object System.Text.UTF8Encoding $false))
    }
}

# README作成
$readmeLines = @()
$readmeLines += "# RUNBIRD ナレッジAI 統合ワークスペース"
$readmeLines += ""
$readmeLines += "このフォルダはCursorで ``runbird.code-workspace`` を開いて使います。"
$readmeLines += ""
$readmeLines += "## 含まれるナレッジ"
$readmeLines += ""
for ($i = 0; $i -lt $IncludedRepos.Count; $i++) {
    $readmeLines += "- $($IncludedNames[$i]) ($($IncludedRepos[$i]))"
}
$readmeLines += ""
$readmeLines += "## 使い方"
$readmeLines += ""
$readmeLines += "1. Cursorを起動"
$readmeLines += "2. ``File > Open Workspace from File`` で ``runbird.code-workspace`` を選択"
$readmeLines += "3. 1ウィンドウで全ナレッジが折りたたみ表示されます"
$readmeLines += "4. Cursorのチャット(Ctrl+L)で質問"
$readmeLines += ""
$readmeLines += "## 最新化"
$readmeLines += ""
$readmeLines += "各ナレッジrepoはフォルダオープン時に自動 git pull が走ります。"
$readmeLines += "手動で更新したい場合: このスクリプトをもう一度実行してください。"

$readmePath = Join-Path $WorkspaceDir "README.md"
[System.IO.File]::WriteAllText($readmePath, ($readmeLines -join "`r`n"), (New-Object System.Text.UTF8Encoding $false))

Write-Host "=== セットアップ完了 ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "含まれるナレッジ:" -ForegroundColor White
for ($i = 0; $i -lt $IncludedRepos.Count; $i++) {
    Write-Host "  - $($IncludedNames[$i]) ($($IncludedRepos[$i]))"
}
Write-Host ""
Write-Host "次の操作:" -ForegroundColor Yellow
Write-Host "  1. Cursor を起動"
Write-Host "  2. File > Open Workspace from File"
Write-Host "  3. 以下のファイルを選択:"
Write-Host "     $WorkspaceFile"
Write-Host "  4. Cursorのチャット(Ctrl+L)で質問"
Write-Host ""
Write-Host "ショートカット作成しますか? (Y/N)" -ForegroundColor Yellow
$createShortcut = Read-Host
if ($createShortcut -eq "Y" -or $createShortcut -eq "y") {
    $WshShell = New-Object -ComObject WScript.Shell
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktopPath "RUNBIRDナレッジAI.lnk"
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $WorkspaceFile
    $shortcut.Save()
    Write-Host "デスクトップにショートカット作成: $shortcutPath" -ForegroundColor Green
}
