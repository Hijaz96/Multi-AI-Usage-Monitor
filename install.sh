#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.local/share/plasma/plasmoids/org.local.multiaiusage"
mkdir -p "$HOME/.local/share/plasma/plasmoids" "$HOME/.local/bin"
if [[ -e "$DEST" ]]; then
  BACKUP="$HOME/multi-ai-widget-backup-$(date +%Y%m%d-%H%M%S)"
  cp -a "$DEST" "$BACKUP"
  echo "Previous widget backup: $BACKUP"
fi
cp -a "$HERE/org.local.multiaiusage" "$DEST.tmp.$$"
python3 - "$DEST.tmp.$$/contents/ui/main.qml" "$HOME" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1])
s=p.read_text()
s=s.replace('/home/uitm/',sys.argv[2].rstrip('/')+'/')
p.write_text(s)
PY
rm -rf "$DEST"
mv "$DEST.tmp.$$" "$DEST"
install -m 755 "$HERE/helpers/codex-widget-account" "$HOME/.local/bin/codex-widget-account"
install -m 755 "$HERE/helpers/codex-reset-credit" "$HOME/.local/bin/codex-reset-credit"
chmod +x "$DEST/contents/scripts/"*.py
echo "Installed. Restart Plasma if required: kquitapp5 plasmashell; kstart5 plasmashell"
echo "Codex Desktop CLI expected at /usr/lib/chatgpt/resources/codex"
