#!/bin/zsh
cd "${0:A:h}"
GODOT_LOCAL="$PWD/.tools/Godot.app/Contents/MacOS/Godot"
if [[ -x "$GODOT_LOCAL" ]]; then
  exec "$GODOT_LOCAL" --path "$PWD"
elif command -v godot >/dev/null 2>&1; then
  exec godot --path "$PWD"
else
  echo "请安装 Godot 4.7.2，然后在 Godot 中导入此目录的 project.godot。"
  read -r "?按回车退出"
fi
