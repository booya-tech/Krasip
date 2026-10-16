# models.sh
# Krasip
# Where the speech model and the correction model live. Read by scripts/setup.sh and relay/start.sh.

KRASIP_MODELS=${KRASIP_MODELS:-$HOME/krasip-models}
SPEECH_MODEL=${SPEECH_MODEL:-$KRASIP_MODELS/ggml-thonburian-large-v3-q8_0.bin}
ADAPTER=${ADAPTER:-$KRASIP_MODELS/run7}
MODELS_URL=${MODELS_URL:-https://github.com/booya-tech/Krasip/releases/download/models-v1}

# The adapter was trained on this exact base model revision.
BASE_MODEL=mlx-community/Qwen3-4B-Instruct-2507-4bit
BASE_REVISION=50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b

SPEECH_PORT=${SPEECH_PORT:-8081}
RELAY_PORT=${RELAY_PORT:-8085}

# Release asset name, then where it goes on this Mac.
MODEL_FILES=(
  ggml-thonburian-large-v3-q8_0.bin "$SPEECH_MODEL"
  run7-adapters.safetensors "$ADAPTER/adapters.safetensors"
  run7-adapter_config.json "$ADAPTER/adapter_config.json"
)
