#!/usr/bin/env bash
# Инициализация репозитория ActeckSmart_MT5 и пуш на GitHub
# Использование: bash setup_git.sh

set -euo pipefail

REPO_DIR="/Users/admin/Desktop/ActeckSmart_MT5"
REMOTE_URL="https://github.com/Evgeniy-makdak/ActeckSmart_MT5.git"

cd "$REPO_DIR"

# 1) Инициализация (если ещё нет .git в этой папке)
if [ ! -d .git ]; then
  git init
  git branch -M main
fi

# 2) Добавление файлов (тяжёлые .ex5 и .DS_Store отсекает .gitignore)
git add .gitignore LICENSE README.md ActeckSmart.mq5 setup_git.sh
git add screenshots/
git add "Условия для формирования сигналов на открытие сделок/"

# 3) Первый коммит
git status
git commit -m "$(cat <<'EOF'
Initial release: ActeckSmart v1.0 indicator for MT5

M15-based correction zones, level-1/2 zigzags, continued movement
structures, session coloring, README and MIT license.
EOF
)"

# 4) Привязка remote и пуш
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE_URL"
else
  git remote add origin "$REMOTE_URL"
fi

git push -u origin main

echo "Готово: $REMOTE_URL"
