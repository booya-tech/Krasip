#!/bin/zsh
# setup-local.sh
# Krasip
# Writes Config/Local.xcconfig with your Apple team ID, so every build signs the same way.
# Usage: setup-local.sh [TEAMID]. Without an argument it reads the team ID off this Mac.

set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=Config/Local.xcconfig

write_config() {
  cat > $CONFIG <<EOF
// Local.xcconfig
// Krasip
// Per-machine signing settings. Not checked in. Written by scripts/setup-local.sh.

DEVELOPMENT_TEAM = $1
EOF
  echo "Wrote $CONFIG with team $1."
  echo "Open Krasip.xcodeproj and press ⌘R."
}

if [[ -f $CONFIG ]]; then
  echo "$CONFIG already exists:"
  sed 's/^/  /' $CONFIG
  echo "Delete it and run this again to pick a different team."
  exit 0
fi

if (( $# > 0 )); then
  given=${1:u}
  if [[ ${#given} -ne 10 || -n ${given//[A-Z0-9]/} ]]; then
    echo "\"$1\" is not a team ID. A team ID is 10 letters and digits, like 45C3927649."
    exit 1
  fi
  write_config $given
  exit 0
fi

# The team ID is the OU field of an Apple Development certificate. The certificates come out
# as one PEM stream, so split it and read each one; `openssl x509` only ever reads the first.
found=()
cert=""
while IFS= read -r line; do
  cert+="$line"$'\n'
  [[ $line == *"END CERTIFICATE"* ]] || continue
  subject=$(print -r -- "$cert" | /usr/bin/openssl x509 -noout -subject 2>/dev/null)
  cert=""
  team=$(print -r -- "$subject" | sed -n 's|.*OU *= *\([A-Z0-9]\{10\}\).*|\1|p')
  owner=$(print -r -- "$subject" | sed -n 's|.*O *= *\([^/,]*\).*|\1|p')
  [[ -n $team ]] && found+=("$team ${owner:-unknown}")
done <<< "$(security find-certificate -c "Apple Development" -a -p 2>/dev/null)"

teams=(${(u)found})

if (( ${#teams} == 0 )); then
  cat <<'EOF'
No Apple Development certificate found on this Mac.

You can still build and run. Xcode signs the app to run locally and ⌘R works.
The catch is that macOS asks for the Accessibility permission again after every
build, because a locally signed build looks like a new app each time.

To get a certificate (a free Apple ID is enough):
  1. Open Xcode, then Settings → Accounts → + → Apple ID, and sign in.
  2. Run this script again.
EOF
  exit 0
fi

if (( ${#teams} > 1 )); then
  echo "More than one Apple team on this Mac:"
  printf '  %s\n' $teams
  echo
  echo "Run this again with the one you want, for example:"
  echo "  ./scripts/setup-local.sh ${teams[1]%% *}"
  exit 1
fi

write_config ${teams[1]%% *}
