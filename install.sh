#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/theme"
THEME_NAME="SpaceTheme-for-Grub"

msg() { printf '%s\n' "$*"; }
ask() { read -r -p "$1 [y/N]: " r && case "$r" in [Yy]*) return 0;; *) return 1;; esac }
ask_yes_default() { read -r -p "$1 [Y/n]: " r && case "$r" in ""|[Yy]*) return 0;; *) return 1;; esac }

detect() { for d in /grub /grub2 /boot/grub /boot/grub2; do [ -d "$d" ] && { printf '%s' "$d"; return 0; }; done; return 1; }

main() {
  if [ ! -d "$SRC" ]; then msg "Source folder '$SRC' not found"; exit 2; fi
  if [ -z "$(ls -A "$SRC" 2>/dev/null || true)" ]; then msg "Source folder is empty"; exit 3; fi

  GRUB_DIR="$(detect || true)"
  [ -n "$GRUB_DIR" ] || { msg "No grub dir found"; exit 4; }

	DIR="$GRUB_DIR/themes/$THEME_NAME"
	msg "Installing to: $DIR"

  if [ -e "$DIR" ]; then
	if ask_yes_default "Destination exists. Overwrite?"; then
	  if [ "$(id -u)" -eq 0 ]; then rm -rf -- "$DIR"; else sudo rm -rf -- "$DIR"; fi
	else
	  msg "Aborted by user"; exit 0
	fi
  fi

  if [ "$(id -u)" -eq 0 ]; then mkdir -p -- "$DIR"; cp -a -- "$SRC/." "$DIR/"; else sudo mkdir -p -- "$DIR"; sudo cp -a -- "$SRC/." "$DIR/"; fi
  msg "Copied theme files."

	if ask_yes_default "Activate theme now?"; then
	THEME_TXT="$DIR/theme.txt"
	if [ ! -f "$THEME_TXT" ]; then msg "theme.txt not found in $DIR"; exit 5; fi

	GRUB_FILE="/etc/default/grub"
	BACKUP="/etc/default/grub.bak.$(date +%s)"
	if [ "$(id -u)" -eq 0 ]; then cp -a -- "$GRUB_FILE" "$BACKUP"; else sudo cp -a -- "$GRUB_FILE" "$BACKUP"; fi

	set_line="GRUB_THEME=\"$THEME_TXT\""
	if sudo grep -q '^GRUB_THEME=' "$GRUB_FILE" 2>/dev/null || grep -q '^GRUB_THEME=' "$GRUB_FILE" 2>/dev/null; then
	  if [ "$(id -u)" -eq 0 ]; then sed -i "s|^GRUB_THEME=.*|$set_line|" "$GRUB_FILE"; else sudo sed -i "s|^GRUB_THEME=.*|$set_line|" "$GRUB_FILE"; fi
	else
	  if [ "$(id -u)" -eq 0 ]; then printf '%s\n' "$set_line" >> "$GRUB_FILE"; else sudo sh -c "printf '%s\n' \"$set_line\" >> \"$GRUB_FILE\""; fi
	fi

	if command -v update-grub >/dev/null 2>&1; then sudo update-grub; elif command -v grub-mkconfig >/dev/null 2>&1; then sudo grub-mkconfig -o "$GRUB_DIR/grub.cfg"; else msg "No grub update command found"; fi
	msg "Theme activated."
    msg "You can now uninstall the source code from $SCRIPT_DIR"
  else
	msg "Theme installed but not activated."
  fi
}

main "$@"