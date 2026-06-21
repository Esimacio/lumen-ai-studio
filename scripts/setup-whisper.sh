#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$ROOT_DIR/app"
TOOLS_DIR="$APP_DIR/tools"
RELEASE="${WHISPER_RELEASE:-v1.9.1}"
PLATFORM="$(uname -s)"
ARCH="$(uname -m)"

download_and_extract() {
  local asset="$1"
  local dest="$2"
  local archive="$TOOLS_DIR/$asset"
  local url="https://github.com/ggml-org/whisper.cpp/releases/download/$RELEASE/$asset"

  if [[ -x "$dest/whisper-cli" ]]; then
    echo "   OK   whisper.cpp speech backend already ready: $dest"
    return 0
  fi

  mkdir -p "$TOOLS_DIR" "$dest"
  rm -f "$archive" "$archive.part"
  echo "   >>   Downloading $asset"
  curl -fSL --progress-bar "$url" -o "$archive.part"
  mv "$archive.part" "$archive"
  tar -xzf "$archive" -C "$dest" --strip-components=1
  rm -f "$archive"
  chmod +x "$dest"/whisper-* "$dest"/main "$dest"/server 2>/dev/null || true

  if [[ ! -x "$dest/whisper-cli" && -x "$dest/main" ]]; then
    cp "$dest/main" "$dest/whisper-cli"
    chmod +x "$dest/whisper-cli"
  fi
  if [[ ! -x "$dest/whisper-server" && -x "$dest/server" ]]; then
    cp "$dest/server" "$dest/whisper-server"
    chmod +x "$dest/whisper-server"
  fi

  if [[ ! -x "$dest/whisper-cli" ]]; then
    echo "   XX   whisper-cli was not found after extracting $asset" >&2
    return 1
  fi
}

if [[ "$PLATFORM" == "Linux" ]]; then
  if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    download_and_extract "whisper-bin-ubuntu-arm64.tar.gz" "$APP_DIR/speech-backend/linux"
  else
    download_and_extract "whisper-bin-ubuntu-x64.tar.gz" "$APP_DIR/speech-backend/linux"
  fi
elif [[ "$PLATFORM" == "Darwin" ]]; then
  mkdir -p "$APP_DIR/speech-backend/mac"
  if [[ -x "$APP_DIR/speech-backend/mac/whisper-cli" ]]; then
    echo "   OK   whisper.cpp macOS speech backend already ready."
  else
    echo "   !!   No official portable macOS whisper.cpp CLI archive is available for this setup script yet."
    echo "        Build whisper.cpp manually and copy whisper-cli to app/speech-backend/mac/whisper-cli."
  fi
else
  echo "Unsupported platform: $PLATFORM" >&2
  exit 1
fi
