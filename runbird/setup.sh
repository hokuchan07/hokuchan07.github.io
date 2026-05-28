#!/bin/bash
# RUNBIRD 自動同期 ワンコマンドセットアップ (macOS)
# 使い方: curl -sL https://hokuchan07.github.io/runbird/setup.sh | bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

printf "${GREEN}=== RUNBIRD 自動同期セットアップ (Mac) ===${NC}\n\n"

WORKSPACE=~/Documents/runbird-knowledge
SYNCDIR=~/.runbird
SYNCSCRIPT="$SYNCDIR/sync.sh"
LOGDIR=~/Library/Logs/runbird-sync

# 1. Workspace 確認（なければ自動構築）
if [ ! -d "$WORKSPACE" ]; then
  printf "${YELLOW}[INFO]${NC} workspace 未構築 → runbird-setup.sh を先に実行します\n\n"
  curl -sL https://hokuchan07.github.io/runbird/runbird-setup.sh | bash
  echo ""
  if [ ! -d "$WORKSPACE" ]; then
    printf "${RED}[ERROR]${NC} workspace 構築に失敗しました。GitHub Org 招待を承認しているか確認してください。\n"
    exit 1
  fi
fi

# 2. core.pager 設定（git log で less ハング回避）
git config --global core.pager ""
echo "[OK] core.pager を空に設定（git log のハング防止）"

# 3. git user.name / user.email 設定
NAME=$(git config --global user.name 2>/dev/null || true)
EMAIL=$(git config --global user.email 2>/dev/null || true)

if [ -z "$NAME" ] || [ -z "$EMAIL" ]; then
  # gh CLI で自動取得を試みる
  if command -v gh > /dev/null 2>&1 && gh auth status > /dev/null 2>&1; then
    GH_LOGIN=$(gh api user --jq '.login' 2>/dev/null)
    GH_ID=$(gh api user --jq '.id' 2>/dev/null)
    if [ -n "$GH_LOGIN" ] && [ -n "$GH_ID" ]; then
      git config --global user.name "$GH_LOGIN"
      git config --global user.email "${GH_ID}+${GH_LOGIN}@users.noreply.github.com"
      echo "[OK] gh CLI から自動設定: $GH_LOGIN <${GH_ID}+${GH_LOGIN}@users.noreply.github.com>"
    fi
  fi

  # まだ設定できていない場合は対話
  NAME=$(git config --global user.name 2>/dev/null || true)
  if [ -z "$NAME" ]; then
    if [ -e /dev/tty ]; then
      printf "${YELLOW}[要入力]${NC} GitHub username を入力してください: "
      read GH_LOGIN < /dev/tty
      git config --global user.name "$GH_LOGIN"
      git config --global user.email "${GH_LOGIN}@users.noreply.github.com"
      echo "[OK] 手動設定: $GH_LOGIN"
    else
      printf "${RED}[ERROR]${NC} git config 未設定。先に以下を手動実行してください:\n"
      printf "  git config --global user.name YOUR_GITHUB_USERNAME\n"
      printf "  git config --global user.email YOUR_EMAIL\n"
      exit 1
    fi
  fi
else
  echo "[既設定] user.name=$NAME / user.email=$EMAIL"
fi

# 4. sync ディレクトリと sync.sh ダウンロード
mkdir -p "$SYNCDIR" "$LOGDIR"
curl -sL https://hokuchan07.github.io/runbird/sync.sh -o "$SYNCSCRIPT"
chmod +x "$SYNCSCRIPT"
echo "[OK] sync.sh をダウンロード → $SYNCSCRIPT"

# 5. crontab 登録
TMP_CRON=$(mktemp)
crontab -l 2>/dev/null | grep -v ".runbird/sync.sh" > "$TMP_CRON" || true
echo "5 6 * * * $SYNCSCRIPT pull" >> "$TMP_CRON"
echo "0 20 * * * $SYNCSCRIPT push" >> "$TMP_CRON"
crontab "$TMP_CRON"
rm "$TMP_CRON"
echo "[OK] crontab 登録: 朝6:05 pull / 夜20:00 push"

# 6. 即実行テスト
printf "\n${GREEN}=== 動作テスト実行中... ===${NC}\n"
"$SYNCSCRIPT" both

# 7. 完了
printf "\n${GREEN}=== セットアップ完了 ===${NC}\n"
echo "ログ確認: tail -50 $LOGDIR/$(date +%Y-%m-%d).log"
