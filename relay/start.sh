#!/bin/zsh
# start.sh
# Krasip
# Starts the speech server (Thonburian 8-bit) and the correction relay together. Ctrl+C stops both.

set -euo pipefail
cd "$(dirname "$0")"
source ./models.sh

if [[ ! -x .venv/bin/python || ! -f $SPEECH_MODEL || ! -f $ADAPTER/adapters.safetensors
      || ! -x policy-runner/.build/release/policy-runner ]]; then
  print "Something is not set up yet. Run ./scripts/setup.sh first."
  exit 1
fi

if curl -s -o /dev/null "http://127.0.0.1:$RELAY_PORT/"; then
  print "The relay is already running on port $RELAY_PORT. Krasip can use it as it is."
  exit 0
fi
if lsof -nP -iTCP:$SPEECH_PORT -sTCP:LISTEN >/dev/null; then
  print "Another program uses port $SPEECH_PORT. Stop it, or pick a free port: SPEECH_PORT=8091 ./relay/start.sh"
  exit 1
fi

# The app sends 16 kHz WAV, which whisper-server reads as is, so there is no --convert and no ffmpeg.
whisper-server -m "$SPEECH_MODEL" -l th --port $SPEECH_PORT -nt -sns \
  --inference-path /v1/audio/transcriptions > speech.log 2>&1 &
SPEECH_PID=$!
trap "kill $SPEECH_PID 2>/dev/null" EXIT INT TERM

print "Loading the speech model (Thonburian 8-bit, port $SPEECH_PORT)..."
until curl -s -o /dev/null "http://127.0.0.1:$SPEECH_PORT/"; do
  if ! kill -0 $SPEECH_PID 2>/dev/null; then
    print "The speech server stopped. The end of relay/speech.log says:"
    tail -5 speech.log
    exit 1
  fi
  sleep 0.5
done

print "Loading the correction model..."
export ADAPTER RELAY_PORT BASE_MODEL BASE_REVISION
SPEECH_URL=http://127.0.0.1:$SPEECH_PORT/v1/audio/transcriptions .venv/bin/python relay.py
