#!/bin/sh
# One-time setup for local video analysis. Safe to re-run.
cd "$(dirname "$0")"

missing=""
for t in yt-dlp ffmpeg whisper-cli; do
  command -v "$t" >/dev/null 2>&1 || missing="$missing $t"
done
if [ -n "$missing" ]; then
  echo "Installing:$missing"
  brew install yt-dlp ffmpeg whisper-cpp || exit 1
fi

model="models/ggml-large-v3-turbo.bin"
if [ ! -f "$model" ]; then
  echo "Downloading the Whisper speech-to-text model (~1.6 GB)..."
  mkdir -p models
  curl -L --fail --progress-bar -o "$model.part" \
    https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin && mv "$model.part" "$model" || exit 1
fi

if command -v ollama >/dev/null 2>&1; then
  if ! curl -s http://127.0.0.1:11434/api/version >/dev/null; then
    echo "Ollama is installed but not running. Start it with: ollama serve  (or open the Ollama app)"
  elif ! ollama list | grep -q "^gemma3"; then
    echo "Pulling a local vision model (gemma3:12b, ~8 GB)..."
    ollama pull gemma3:12b
  fi
fi

echo "Setup done. Start the decoder with: npm run serve"
