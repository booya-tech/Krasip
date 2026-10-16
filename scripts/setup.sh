#!/bin/zsh
# setup.sh
# Krasip
# One command after cloning: installs the speech tools, downloads the models, and points the app at them.
# Safe to run again. Each step skips what is already done.

set -euo pipefail
cd "$(dirname "$0")/.."
source relay/models.sh

step() { print -P "\n%B$1%b" }
fail() { print -u2 "\n$1"; exit 1 }
sha() { shasum -a 256 "$1" | cut -d' ' -f1 }

step "1/7  Checking this Mac"
[[ $(uname -m) == arm64 ]] || fail "The correction model needs an Apple Silicon Mac (M1 or later)."
memory=$(( $(sysctl -n hw.memsize) / 1073741824 ))
(( memory >= 16 )) || print "This Mac has $memory GB of memory. 16 GB or more is recommended, or dictation gets slow."
xcodebuild -version >/dev/null 2>&1 || fail "Xcode is missing. Install it from the App Store, open it once, then run this again."
command -v brew >/dev/null || fail "Homebrew is missing. Install it from https://brew.sh, then run this again."
print "Apple Silicon, $memory GB, $(xcodebuild -version | head -1), Homebrew."

step "2/7  Speech server and Python"
command -v whisper-server >/dev/null || brew install whisper.cpp
python=$(command -v python3.13 || true)
if [[ -z $python ]]; then
  brew install python@3.13
  python=$(brew --prefix python@3.13)/bin/python3.13
fi
print "whisper-server: $(command -v whisper-server)"
print "Python: $python"

step "3/7  Python packages for the correction model"
[[ -x relay/.venv/bin/python ]] || $python -m venv relay/.venv
relay/.venv/bin/pip install --quiet --disable-pip-version-check -r relay/requirements.txt
print "Installed into relay/.venv."

step "4/7  Speech model and correction model (about 1.7 GB, once)"
missing=0
for asset dest in $MODEL_FILES; do [[ -f $dest ]] || missing=1; done
if ! sums=$(curl -fsSL "$MODELS_URL/SHA256SUMS"); then
  (( missing )) && fail "Could not download the model list from $MODELS_URL. Check the internet connection and run this again."
  print "Could not reach $MODELS_URL to check the models. Using the ones already on this Mac."
  sums=""
fi
for asset dest in $MODEL_FILES; do
  [[ -n $sums ]] || continue
  want=$(awk -v name="$asset" '$2 == name { print $1 }' <<< "$sums")
  [[ -n $want ]] || fail "The model list at $MODELS_URL has no entry for $asset."
  if [[ -f $dest && $(sha "$dest") == $want ]]; then
    print "Already here: $dest"
    continue
  fi
  print "Downloading $asset"
  mkdir -p "${dest:h}"
  code=0
  curl -fL --progress-bar -C - -o "$dest.part" "$MODELS_URL/$asset" || code=$?
  # Exit code 33: the server cannot continue this partial file, so the checksum below decides.
  (( code == 0 || code == 33 )) || fail "The download of $asset stopped. Run this again to continue it."
  if [[ $(sha "$dest.part") != $want ]]; then
    rm -f "$dest.part"
    fail "The download of $asset came out damaged and was deleted. Run this again."
  fi
  mv "$dest.part" "$dest"
done

step "5/7  Base language model for the correction (about 2.3 GB, once)"
relay/.venv/bin/python -c "from huggingface_hub import snapshot_download; print(snapshot_download('$BASE_MODEL', revision='$BASE_REVISION'))"

step "6/7  Text policy runner"
swift build -c release --package-path relay/policy-runner 2>&1 | tail -1

step "7/7  App settings"
./scripts/setup-local.sh || print "Signing is not set up, see above. Krasip still builds and runs."
bundle=$(sed -n 's/^PRODUCT_BUNDLE_IDENTIFIER = //p' Config/Base.xcconfig)
defaults write $bundle speechEngine -string openAI
defaults write $bundle openAIBaseURL -string "http://127.0.0.1:$RELAY_PORT/v1"
defaults write $bundle openAIModel -string thonburian-8bit
print "Krasip will send speech to the relay at http://127.0.0.1:$RELAY_PORT/v1."
pgrep -xq Krasip && print "Krasip is running. Quit it and open it again so it reads this setting."

step "Done. Next:"
print "  1. ./relay/start.sh        keep this Terminal window open while you dictate"
print "  2. open Krasip.xcodeproj   then press ⌘R"
