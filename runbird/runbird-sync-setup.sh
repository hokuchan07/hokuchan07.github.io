#!/bin/bash
# RUNBIRD ナレッジAI 自動同期セットアップ (macOS)
# 実行: bash <(curl -sL https://hokuchan07.github.io/runbird/runbird-sync-setup.sh)
#
# やること:
# 1) git user.name / user.email が未設定なら対話で設定（GitHub と紐付くように）
# 2) ~/Documents/runbird-knowledge/ 配下の各 repo を
#    - 朝 6:05 → git pull
#    - 夜 20:00 → 変更があれば commit + push
# 3) ログは ~/Library/Logs/runbird-sync/ に日付別で記録

set -e

WORKSPACE=~/Documents/runbird-knowledge
LOGDIR=~/Library/Logs/runbird-sync
SYNCDIR=~/.runbird
SYNCSCRIPT="$SYNCDIR/sync.sh"

mkdir -p "$SYNCDIR" "$LOGDIR"

echo "=== RUNBIRD 自動同期セットアップ (macOS) ==="
echo "対象: $WORKSPACE"
echo ""

if [ ! -d "$WORKSPACE" ]; then
  echo "エラー: $WORKSPACE が存在しません。"
  echo "先に runbird-setup.sh を実行してください："
  echo "  bash <(curl -sL https://hokuchan07.github.io/runbird/runbird-setup.sh)"
  exit 1
fi

# --- Step 1: git config ---
NAME=$(git config --global user.name || true)
EMAIL=$(git config --global user.email || true)

if [ -z "$NAME" ] || [ -z "$EMAIL" ]; then
  echo "[必要] Git の user.name / user.email を設定します"
  echo ""
  read -p "GitHub のユーザー名を入力してください (例: hokuchan07): " GH_USER
  echo "GitHub に登録済みのメールアドレスを入力してください"
  echo "（公開していない場合は ${GH_USER}@users.noreply.github.com も使えます）"
  read -p "Email: " GH_EMAIL
  git config --global user.name "$GH_USER"
  git config --global user.email "$GH_EMAIL"
  echo "[設定完了] user.name = $GH_USER / user.email = $GH_EMAIL"
else
  echo "[既設定] user.name = $NAME / user.email = $EMAIL"
fi
echo ""

# --- Step 2: 同期スクリプト本体を生成 ---
cat > "$SYNCSCRIPT" << 'SYNC_EOF'
#!/bin/bash
# RUNBIRD 自動同期スクリプト（runbird-sync-setup.sh が生成）
WORKSPACE=~/Documents/runbird-knowledge
LOGFILE=~/Library/Logs/runbird-sync/$(date +%Y-%m-%d).log
MODE="${1:-both}"   # pull / push / both

[ -d "$WORKSPACE" ] || exit 0

{
  echo ""
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') mode=$MODE ====="
} >> "$LOGFILE"

cd "$WORKSPACE" || exit 1

for repo in */; do
  [ -d "$repo/.git" ] || continue
  cd "$WORKSPACE/$repo" || continue
  echo "--- $repo ---" >> "$LOGFILE"

  if [ "$MODE" = "pull" ] || [ "$MODE" = "both" ]; then
    git pull --rebase --autostash >> "$LOGFILE" 2>&1 || echo "[pull失敗] $repo" >> "$LOGFILE"
  fi

  if [ "$MODE" = "push" ] || [ "$MODE" = "both" ]; then
    if [ -n "$(git status --porcelain)" ]; then
      git add -A
      git commit -m "auto-sync: $(date '+%Y-%m-%d %H:%M')" >> "$LOGFILE" 2>&1 || true
    fi
    git push >> "$LOGFILE" 2>&1 || echo "[push失敗] $repo" >> "$LOGFILE"
  fi

  cd "$WORKSPACE"
done
SYNC_EOF
chmod +x "$SYNCSCRIPT"

echo "[作成] $SYNCSCRIPT"
echo ""

# --- Step 3: crontab 登録 ---
TMP_CRON=$(mktemp)
crontab -l 2>/dev/null | grep -v "runbird/sync.sh\|.runbird/sync.sh" > "$TMP_CRON" || true
echo "5 6 * * * $SYNCSCRIPT pull" >> "$TMP_CRON"
echo "0 20 * * * $SYNCSCRIPT push" >> "$TMP_CRON"
crontab "$TMP_CRON"
rm "$TMP_CRON"

echo "[登録] crontab:"
echo "  - 朝 6:05 → 全 repo を git pull"
echo "  - 夜 20:00 → 変更があれば commit + push"
echo ""
echo "[完了] ログは $LOGDIR/ に日付別で記録されます"
echo ""
echo "今すぐ動作確認したい場合:"
echo "  $SYNCSCRIPT both"
