#!/usr/bin/env bash
# Explicit, user-run convenience setup. Does not modify shell startup files.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-$HOME/.local/bin}"
mkdir -p "$DEST"
if [[ -e "$DEST/game-hub" || -L "$DEST/game-hub" ]]; then
  printf 'Refusing to overwrite %s/game-hub. Remove it first or choose another directory.\n' "$DEST" >&2
  exit 1
fi
# Wrapper preserves project root (a symlink alone changes BASH_SOURCE resolution).
printf '#!/usr/bin/env bash\nexec %q "$@"\n' "$ROOT/game-hub" > "$DEST/game-hub"
chmod +x "$DEST/game-hub"
printf 'Installed %s/game-hub\nEnsure %s is on your PATH, then type: game-hub\n' "$DEST" "$DEST"
