#!/bin/bash
# RUNBIRD 自動同期スクリプト (macOS)
# 呼び出し: ~/.runbird/sync.sh [pull|push|both]
# setup.sh からダウンロードされて配置される

WORKSPACE=~/Documents/runbird-knowledge
LOGFILE=~/Library/Logs/runbird-sync/$(date +%Y-%m-%d).log
MODE="${1:-both}"

[ -d "$WORKSPACE" ] || exit 0
mkdir -p "$(dirname "$LOGFILE")"

{
  echo ""
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') mode=$MODE ====="
} >> "$LOGFILE"

cd "$WORKSPACE" || exit 1

for repo in */; do
  [ -d "$repo/.git" ] || continue
  cd "$WORKSPACE/$repo" || continue
  repo_name="${repo%/}"
  echo "--- $repo_name ---" >> "$LOGFILE"

  if [ "$MODE" = "pull" ] || [ "$MODE" = "both" ]; then
    # rebase中断が残っていたら自動復旧（過去事故対策）
    if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ]; then
      git rebase --abort 2>/dev/null
      echo "  [rebase中断を検知 → abortして続行]" >> "$LOGFILE"
    fi
    # 設定の重複（Cannot rebase/merge multiple branches の原因）を正規化
    br=$(git rev-parse --abbrev-ref HEAD)
    if [ "$(git config --get-all "branch.$br.merge" 2>/dev/null | wc -l)" -gt 1 ]; then
      git config --unset-all "branch.$br.merge"
      git config "branch.$br.merge" "refs/heads/$br"
      echo "  [branch.$br.merge の重複を正規化]" >> "$LOGFILE"
    fi
    git -c pull.rebase=false -c merge.autoStash=true pull --no-edit origin "$br" 2>&1 | tail -3 >> "$LOGFILE"
  fi

  if [ "$MODE" = "push" ] || [ "$MODE" = "both" ]; then
    if [ -n "$(git status --porcelain)" ]; then
      git add -A
      git commit -m "auto-sync: $(date '+%Y-%m-%d %H:%M')" 2>&1 | tail -2 >> "$LOGFILE"
    fi
    push_out=$(git push 2>&1)
    if echo "$push_out" | grep -qE "403|Write access"; then
      echo "  [skip: push権限なし]" >> "$LOGFILE"
    elif echo "$push_out" | grep -qE "Could not connect|Failed to connect|timed out"; then
      echo "  [skip: ネットワーク失敗（次回リトライ）]" >> "$LOGFILE"
    else
      echo "$push_out" | tail -3 >> "$LOGFILE"
    fi
  fi

  cd "$WORKSPACE"
done
