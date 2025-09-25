#!/usr/bin/env bash
# Beautify Ubuntu 25 (GNOME) - No Browser
# Makes desktop stylish: themes, icons, fonts, GNOME extensions, pretty apps, defaults

set -euo pipefail

echo "==> Updating system..."
sudo apt update
sudo apt -y upgrade

echo "==> Installing essentials (Tweaks, extensions tools, flatpak, git, jq, curl, unzip)..."
sudo apt install -y gnome-tweaks gnome-shell-extensions flatpak git jq curl unzip \
  gtk2-engines-murrine sassc gnome-themes-extra \
  papirus-icon-theme

# Ensure Flathub is present
if ! flatpak remote-list | grep -q flathub; then
  echo "==> Adding Flathub..."
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

echo "==> Installing Extension Manager (for manual tweaks if needed)..."
flatpak install -y flathub com.mattjakeman.ExtensionManager

echo "==> Installing pretty apps via Flatpak..."
flatpak install -y flathub io.bassi.Amberol            # Music
flatpak install -y flathub com.github.rafostar.Clapper  # Video
flatpak install -y flathub md.obsidian.Obsidian         # Notes
flatpak install -y flathub dev.lapce.lapce              # Code editor

echo "==> Installing Nemo file manager..."
sudo apt install -y nemo

# Make Nemo default for folders
echo "==> Setting Nemo as default file manager..."
xdg-mime default nemo.desktop inode/directory application/x-gnome-saved-search || true
# Optional: let Nemo draw desktop icons (disable other desktop icon extensions manually if you had them)
gsettings set org.nemo.desktop show-desktop-icons true || true

# ---------- THEMES ----------
echo "==> Installing Orchis GTK/GNOME Shell theme..."
WORKDIR="$(mktemp -d)"
pushd "$WORKDIR" >/dev/null

if [ -d Orchis-theme ]; then rm -rf Orchis-theme; fi
git clone --depth=1 https://github.com/vinceliuice/Orchis-theme.git
cd Orchis-theme
# Compact + dock tweaks, and link libadwaita to style GTK4 apps consistently
./install.sh -c dark --tweaks compact dock -l
cd ..

popd >/dev/null
rm -rf "$WORKDIR"

echo "==> Applying theme & icons via gsettings..."
gsettings set org.gnome.desktop.interface gtk-theme 'Orchis-Dark' || true
gsettings set org.gnome.desktop.interface icon-theme 'Papirus' || true

# ---------- FONTS ----------
echo "==> Installing nice fonts (Inter + Vazirmatn for Persian)..."
sudo apt install -y fonts-inter fonts-inter-variable fonts-vazirmatn || true
# Optional: set UI font
gsettings set org.gnome.desktop.interface font-name 'Inter 10' || true

# ---------- GNOME EXTENSIONS (auto-install from extensions.gnome.org) ----------
echo "==> Installing GNOME Shell extensions (Dash to Dock, Blur my Shell, ArcMenu, User Themes)..."
# Helper: install GNOME extension by UUID (and known numeric ID) for current shell version
install_gnome_extension () {
  local UUID="$1"
  local ID="$2"
  local SHELL_VER_SHORT
  SHELL_VER_SHORT="$(gnome-shell --version | grep -oE '[0-9]+' | head -n1)"

  # Query extension info JSON for this shell version
  local INFO_URL="https://extensions.gnome.org/extension-info/?uuid=${UUID}&shell_version=${SHELL_VER_SHORT}"
  local DL_PATH
  DL_PATH="$(curl -sS "$INFO_URL" | jq -r '.download_url // empty')"

  if [ -z "$DL_PATH" ] || [ "$DL_PATH" = "null" ]; then
    # Try without explicit shell_version (fallback)
    INFO_URL="https://extensions.gnome.org/extension-info/?pk=${ID}"
    DL_PATH="$(curl -sS "$INFO_URL" | jq -r '.download_url // empty')"
  fi

  if [ -z "$DL_PATH" ] || [ "$DL_PATH" = "null" ]; then
    echo "    !! Could not find download for ${UUID} (id ${ID}); skipping."
    return 0
  fi

  local ZIP_URL="https://extensions.gnome.org${DL_PATH}"
  local TMPZIP
  TMPZIP="$(mktemp --suffix=.zip)"
  curl -fsSL "$ZIP_URL" -o "$TMPZIP"

  # Install/upgrade extension
  gnome-extensions install --force "$TMPZIP" || true
  rm -f "$TMPZIP"

  # Enable extension
  if gnome-extensions list | grep -q "$UUID"; then
    gsettings reset-recursively "org.gnome.shell.extensions.${UUID%%@*}" 2>/dev/null || true
    gnome-extensions enable "$UUID" || true
    echo "    -> Enabled: $UUID"
  else
    echo "    !! Not found after install: $UUID"
  fi
}

# Known UUIDs & IDs
# Dash to Dock
install_gnome_extension "dash-to-dock@micxgx.gmail.com" 307
# Blur my Shell
install_gnome_extension "blur-my-shell@aunetx" 3193
# ArcMenu
install_gnome_extension "arcmenu@arcmenu.com" 3628
# User Themes (often comes with gnome-shell-extensions; still try to enable)
if gnome-extensions list | grep -q "user-theme@gnome-shell-extensions.gcampax.github.com"; then
  gnome-extensions enable "user-theme@gnome-shell-extensions.gcampax.github.com" || true
fi

# ---------- EXTENSIONS TWEAKS ----------
echo "==> Tweaking Dash to Dock & Blur my Shell styles..."
# Dash to Dock preferences
# (These keys may vary by version; failures are safe.)
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed true || true
gsettings set org.gnome.shell.extensions.dash-to-dock extend-height true || true
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 44 || true
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'DYNAMIC' || true
gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.4 || true

# Blur my Shell - enable blur on panel, overview, and applications
gsettings set org.gnome.shell.extensions.blur-my-shell panel blur true || true
gsettings set org.gnome.shell.extensions.blur-my-shell overview blur true || true
gsettings set org.gnome.shell.extensions.blur-my-shell applications blur true || true

# ---------- DEFAULT APPS ----------
echo "==> Setting default apps (Clapper for video, Amberol for audio, Nemo for folders)..."
# Video defaults (extend or adjust as needed)
xdg-mime default com.github.rafostar.Clapper.desktop video/mp4 video/x-matroska video/webm || true
# Audio defaults
xdg-mime default io.bassi.Amberol.desktop audio/mpeg audio/flac audio/ogg audio/x-wav || true
# File manager defaults already set above

# ---------- FLATPAK THEME BRIDGE (optional, helps GTK4 apps pick theme) ----------
echo "==> Bridging Flatpak theme directories (optional; safe to ignore errors)..."
sudo flatpak override --filesystem=xdg-config/gtk-3.0 || true
sudo flatpak override --filesystem=xdg-config/gtk-4.0 || true

echo
echo "✅ Done! Please Log out / Log in once to fully apply GNOME Shell theme & extensions."
echo "   If something didn't apply, open 'GNOME Tweaks' and 'Extension Manager' to review."
