#!/usr/bin/env bash
# User-space setup for Antigravity cloud VMs (non-root, read-only /).
# Reads every tool version and SHA256 pin from tools/cloud-setup.sh so pins stay in one place.
# Installs checkov in a Python venv because its PyInstaller zip requires GLIBC_2.38 (VM is Debian 12).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLOUD_SETUP="$SCRIPT_DIR/cloud-setup.sh"

BIN="$HOME/.local/bin"
ZIZMOR_VENV="$HOME/.local/share/zizmor-venv"
CHECKOV_VENV="$HOME/.local/share/checkov-venv"
mkdir -p "$BIN" "$HOME/.terraform.d/plugin-cache"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Load GH and TOOLS=() from tools/cloud-setup.sh without executing it.
GH=https://github.com
eval "$(awk '/^TOOLS=\(/,/^\)/' "$CLOUD_SETUP")"

install_one() {
  local name ver url sha inner f
  IFS='|' read -r name ver url sha inner <<<"$1"
  if [ -x "$BIN/$name" ] && [ -f "$BIN/.$name.$ver" ]; then
    echo "= $name $ver"
    return
  fi
  mkdir -p "$WORK/$name" && f="$WORK/$name/${url##*/}"
  curl -fsSL --retry 3 -o "$f" "$url"
  echo "$sha  $f" | sha256sum -c --quiet -
  case "$f" in
    *.tar.gz) tar -xzf "$f" -C "$WORK/$name" "$inner"; f="$WORK/$name/$inner" ;;
    *.zip) unzip -q -o "$f" "$inner" -d "$WORK/$name"; f="$WORK/$name/$inner" ;;
  esac
  install -m 0755 "$f" "$BIN/$name"
  rm -f "$BIN/.$name."* && touch "$BIN/.$name.$ver"
  echo "+ $name $ver"
}

checkov_ver=""
pids=()
for t in "${TOOLS[@]}"; do
  name="${t%%|*}"
  if [ "$name" = "checkov" ]; then
    IFS='|' read -r _ checkov_ver _ <<<"$t"
    continue
  fi
  install_one "$t" & pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done

# checkov: install the same pinned version into a user-space venv (glibc 2.36 compatible).
if [ -n "$checkov_ver" ]; then
  if [ -x "$BIN/checkov" ] && [ -f "$BIN/.checkov.$checkov_ver" ]; then
    echo "= checkov $checkov_ver"
  else
    if command -v uv >/dev/null 2>&1; then
      uv venv -q "$CHECKOV_VENV"
      uv pip install -q --python "$CHECKOV_VENV/bin/python" "checkov==$checkov_ver"
    else
      python3 -m venv "$CHECKOV_VENV"
      "$CHECKOV_VENV/bin/python" -m pip install -q "checkov==$checkov_ver"
    fi
    ln -sfn "$CHECKOV_VENV/bin/checkov" "$BIN/checkov"
    rm -f "$BIN/.checkov."* && touch "$BIN/.checkov.$checkov_ver"
    echo "+ checkov $checkov_ver"
  fi
fi

# zizmor: single wheel with no dependencies, pinned by hash from tools/cloud-setup.sh.
zizmor_req=$(grep -E '^zizmor==[^ ]+ --hash=sha256:[0-9a-f]+' "$CLOUD_SETUP")
zizmor_ver=${zizmor_req#zizmor==}
zizmor_ver=${zizmor_ver%% *}
if [ -x "$BIN/zizmor" ] && [ -f "$BIN/.zizmor.$zizmor_ver" ]; then
  echo "= zizmor $zizmor_ver"
else
  printf '%s\n' "$zizmor_req" >"$WORK/zizmor.txt"
  python3 -m venv "$ZIZMOR_VENV"
  "$ZIZMOR_VENV/bin/python" -m pip install -q --no-deps --require-hashes --only-binary=:all: -r "$WORK/zizmor.txt"
  ln -sfn "$ZIZMOR_VENV/bin/zizmor" "$BIN/zizmor"
  rm -f "$BIN/.zizmor."* && touch "$BIN/.zizmor.$zizmor_ver"
  echo "+ zizmor $zizmor_ver"
fi

# Persist PATH and plugin cache in ~/.bashrc for non-interactive shells.
touch "$HOME/.bashrc"
sed -i '/case \$- in/,/esac/d' "$HOME/.bashrc" 2>/dev/null || true
grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
grep -qxF 'export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"' "$HOME/.bashrc" || echo 'export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"' >> "$HOME/.bashrc"

echo "antigravity-setup: done"
