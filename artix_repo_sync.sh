#!/usr/bin/env bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' 

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find the database file (*.db.tar.xz)
DB_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -type f -name "*.db.tar.xz" | head -n 1)

if [[ -z "$DB_FILE" ]]; then
    echo -e "${RED}Error: No *.db.tar.xz file found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Array of packages to process
PACKAGES=("system/dbus" "system/p11-kit" "system/util-linux")

# Architecture
ARCH="x86_64"

for PKG in "${PACKAGES[@]}"; do
    echo "Processing package: $PKG"

    # Download the package (without installing)
    sudo pacman -Sw --noconfirm "$PKG"

    # Find the package files in pacman's cache
    mapfile -t PKG_FILES < <(find /var/cache/pacman/pkg -maxdepth 1 -type f -name "${PKG}-*-*-${ARCH}.pkg.tar.zst")

    if [[ ${#PKG_FILES[@]} -eq 0 ]]; then
        echo -e "  ${RED}Error: No cached package files found${NC}"
        continue
    fi

    NEW_FILES_FOUND=false

    for FILE in "${PKG_FILES[@]}"; do
        BASENAME=$(basename "$FILE")
        DEST_FILE="$SCRIPT_DIR/$BASENAME"

        # Skip if the file already exists in the script directory
        if [[ -f "$DEST_FILE" ]]; then
            continue
        fi

        NEW_FILES_FOUND=true
        cp "$FILE" "$SCRIPT_DIR/"

        # Copy the .sig file if it exists
        if [[ -f "$FILE.sig" ]]; then
            cp "$FILE.sig" "$SCRIPT_DIR/"
        fi

        # Add the package to the database
        echo -e "  ${GREEN}Adding $BASENAME to the database${NC}"
        repo-add "$DB_FILE" "$DEST_FILE"
    done

    if [[ "$NEW_FILES_FOUND" == false ]]; then
        echo -e "  ${YELLOW}No new package versions found${NC}"
    fi
done

rm "$SCRIPT_DIR/*.db" "$SCRIPT_DIR/*.files" 
