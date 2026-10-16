# Correction relay

The local speech pipeline the founders use every day. Krasip sends audio here instead of to a cloud service, and gets back corrected text.

```text
Krasip --audio--> relay (port 8085) --audio--> whisper-server (port 8081, Thonburian Whisper 8-bit)
                    |
                    +-- text policy (policy-runner) --> correction model --> two safety checks --> Krasip
```

To Krasip the relay looks like any OpenAI-compatible `/audio/transcriptions` server, so the app needs no special code. `scripts/setup.sh` points the app at `http://127.0.0.1:8085/v1`.

## What the correction model may do

It fixes speech-to-text mistakes, mostly English work words that arrive in Thai letters: ดีพลอย becomes deploy. It never polishes, changes tone, adds, removes, reorders, or translates words. [`docs/CORRECTION_STYLE_RULES.md`](../docs/CORRECTION_STYLE_RULES.md) section 1 is the rule, and product rule 3 in the spec is why.

Two checks enforce it after every answer. `guard.py` throws the answer away when its length changed too much or it contains markup. `safety.py` compares the answer with what was heard, piece by piece, and undoes any piece that invents or drops content, changes a number, a name, or a Thai time. When a check undoes something, the relay prints "(safety check undid part or all of the change)".

Everything runs on the Mac. The text never leaves it.

## Files

| File | What it is |
| --- | --- |
| `start.sh` | Starts whisper-server and the relay. Ctrl+C stops both. |
| `models.sh` | Model paths, ports, and the download address. Read by `start.sh` and `scripts/setup.sh`. |
| `relay.py` | The HTTP server on port 8085. |
| `guard.py`, `safety.py` | The two checks above. |
| `data/work-words.tsv` | How each work word is written, and the Thai spellings it arrives as. `safety.py` reads it. |
| `policy-runner/` | A tiny Swift program that runs KrasipCore's text policy on each line. The model was trained on text that went through these rules, so the relay applies them first. |
| `requirements.txt` | Exact Python package versions. `setup.sh` installs them into `relay/.venv`. |

## Models

| Model | Size | Where it comes from | License |
| --- | --- | --- | --- |
| Thonburian Whisper large-v3, 8-bit | 1.7 GB | [biodatlab/whisper-th-large-v3](https://huggingface.co/biodatlab/whisper-th-large-v3) by Mahidol University, converted with whisper.cpp's `convert-h5-to-ggml.py` and quantized with `whisper-quantize ... q8_0` | Apache 2.0 |
| Qwen3 4B Instruct 2507, 4-bit MLX | 2.3 GB | [mlx-community/Qwen3-4B-Instruct-2507-4bit](https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit), pinned to the revision in `models.sh`. Downloaded into `~/.cache/huggingface`. | Apache 2.0 |
| Correction adapter run7 | 29 MB | Our LoRA adapter on top of Qwen3, trained for Krasip | Ours |

`setup.sh` downloads the speech model and the adapter from the `models-v1` release of this repo into `~/krasip-models`, and checks each file against the release's `SHA256SUMS`.

## Settings

Every value in `models.sh` can be overridden from the environment. The common ones:

```bash
SPEECH_PORT=8091 RELAY_PORT=8095 ./relay/start.sh     # other ports, for a second copy
ADAPTER=~/some/other/adapter ./relay/start.sh          # try another correction adapter
SPEECH_MODEL=~/whisper-models/other.bin ./relay/start.sh
```

Krasip only follows a new relay port after you change the endpoint in Settings → Languages.

The speech server's own log is `relay/speech.log`.

## Shipping a new correction adapter

Training lives outside this repo. To make a new adapter the default:

1. Upload it as a new release, for example `models-v2`, with all three files and a fresh `SHA256SUMS`:
   ```bash
   shasum -a 256 ggml-thonburian-large-v3-q8_0.bin run8-adapters.safetensors run8-adapter_config.json > SHA256SUMS
   gh release create models-v2 --title "Models v2" ggml-thonburian-large-v3-q8_0.bin run8-* SHA256SUMS
   ```
2. In `models.sh`, change `MODELS_URL`, `ADAPTER`, and the asset names in `MODEL_FILES`.
3. Run `./scripts/setup.sh` and send a test recording through the relay before you open the pull request.
