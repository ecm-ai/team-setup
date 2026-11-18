#!/bin/bash
# ECM team setup. One time, on a staff Mac.
# Usage (Terminal):  curl -fsSL https://raw.githubusercontent.com/ecm-ai/team-setup/main/setup.sh | bash -s <name>
# No passwords or keys live in this file. Access to the team brain needs the person's own GitHub login.
set -e
NAME="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')"
ORG="ecm-ai"; REPO="team-brain"; BRAIN="$HOME/team-brain"
say(){ printf "\n\033[1;34m==> %s\033[0m\n" "$1"; }
ok(){  printf "\033[1;32m✔ %s\033[0m\n" "$1"; }
die(){ printf "\n\033[1;31m✘ %s\033[0m\n%s\n" "$1" "Take a screenshot of this window and WhatsApp it to Edmund." ; exit 1; }

case "$NAME" in charles|chelzi) ;; *) die "Name missing. The line must end with your name, e.g. ... bash -s chelzi" ;; esac
[ "$(uname)" = "Darwin" ] || die "This setup is for a Mac."

printf "\n\033[1mECM team setup for %s\033[0m\nThis takes about 10 minutes. Leave this window open.\n" "$NAME"

# 1. Homebrew (also installs Apple's command line tools). Asks for the Mac password once.
if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ] && [ ! -x /usr/local/bin/brew ]; then
  say "Step 1 of 5: installing Homebrew"
  printf "Type the password you use to unlock this Mac, then press Enter.\nNothing shows while you type. That is normal.\n"
  sudo -v -p "Mac password: " </dev/tty || die "Password not accepted. Paste line 2 again and retype it slowly."
  ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty || die "Homebrew install stopped."
fi
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)"; done
grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo "eval \"\$($(command -v brew) shellenv)\"" >> "$HOME/.zprofile"
grep -q '.local/bin' "$HOME/.zshrc" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"   # so typing claude works
ok "Homebrew ready"

# 2. Tools (only what is missing)
say "Step 2 of 5: installing GitHub and video tools"
NEED=""; command -v gh >/dev/null 2>&1 || NEED="$NEED gh"
if [ "$NAME" = "chelzi" ]; then
  command -v ffmpeg >/dev/null 2>&1 || NEED="$NEED ffmpeg"
  command -v whisper-cli >/dev/null 2>&1 || NEED="$NEED whisper-cpp"
fi
[ -z "$NEED" ] || brew install -q $NEED || die "Tool install stopped."
git --version >/dev/null 2>&1 || die "git is missing. Apple's developer tools did not install."
if [ "$NAME" = "chelzi" ]; then
  /usr/bin/python3 -c "import PIL, faster_whisper" 2>/dev/null || /usr/bin/python3 -m pip install --user -q pillow faster-whisper || die "Python video tools did not install."
  M="$HOME/.claude/workspace/models/ggml-small.bin"
  if [ ! -s "$M" ]; then
    echo "Downloading the speech-to-text model (about 470 MB)..."
    mkdir -p "$(dirname "$M")"
    curl -fL --progress-bar -o "$M.part" https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin && mv "$M.part" "$M" || die "Model download stopped. Check the Wi-Fi and paste line 2 again."
  fi
fi
ok "Tools ready"

# 3. GitHub login (browser, one-time code)
say "Step 3 of 5: connecting your GitHub"
if ! gh auth status -h github.com >/dev/null 2>&1; then
  gh auth login -h github.com -p https -w --skip-ssh-key </dev/tty || die "GitHub login did not finish."
fi
gh auth setup-git -h github.com
gh api -X PATCH "user/memberships/orgs/$ORG" -f state=active >/dev/null 2>&1 || true   # accepts Edmund's invite if one is waiting
ok "GitHub connected as $(gh api user -q .login)"

# 4. Team brain copy
say "Step 4 of 5: downloading the team brain"
if [ -d "$BRAIN/.git" ]; then git -C "$BRAIN" pull -q --rebase --autostash || true
else gh repo clone "$ORG/$REPO" "$BRAIN" -- -q || die "No access to the team brain yet. Ask Edmund to invite your GitHub username, then paste line 2 again."
fi
mkdir -p "$BRAIN/$NAME/daily-log"
ok "Team brain is in your home folder: team-brain"

# 5. Claude settings: handbook, skills, auto-pull, auto-save
say "Step 5 of 5: setting up Claude with the team rules"
mkdir -p "$HOME/.claude/skills"
echo "$NAME" > "$HOME/.claude/team-name"
[ -f "$HOME/.claude/CLAUDE.md" ] && [ ! -L "$HOME/.claude/CLAUDE.md" ] && mv "$HOME/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md.before-team-$(date +%s)"
ln -sfn "$BRAIN/setup/CLAUDE-$NAME.md" "$HOME/.claude/CLAUDE.md"
while read -r s; do [ -n "$s" ] && [ -d "$BRAIN/shared/skills/$s" ] && ln -sfn "$BRAIN/shared/skills/$s" "$HOME/.claude/skills/$s"; done < "$BRAIN/setup/skills-$NAME.txt"
/usr/bin/python3 "$BRAIN/setup/merge_settings.py" "$HOME/.claude/settings.json"
PL="$HOME/Library/LaunchAgents/com.ecm.team-save.plist"; mkdir -p "$(dirname "$PL")"
sed -e "s#__HOME__#$HOME#g" -e "s#__NAME__#$NAME#g" "$BRAIN/setup/com.ecm.team-save.plist" > "$PL"
launchctl bootout "gui/$(id -u)" "$PL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PL"
ok "Claude will save your notes at 12pm, 3pm and 6pm"

printf "\n\033[1;32m✔ Setup done.\033[0m\n\nNext: press Cmd + Q to quit Terminal. Open Terminal again. Type  claude  and press Enter.\n\n"
