#!/bin/bash

# Configuration
SCRIPT_URL="https://github.com/rvdk/appimage-manager/raw/refs/heads/main/appimage.sh"
INSTALL_DIR="$HOME/.local/bin"
SCRIPT_NAME="appimage"

echo "Installing AppImage Manager..."

# Ensure install dir exists
mkdir -p "$INSTALL_DIR"

# Download the script
echo "Downloading script..."
curl -sSL "$SCRIPT_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"

# Check if download succeeded
if [ $? -ne 0 ]; then
    echo "Error: Failed to download the script. Please check your internet connection."
    exit 1
fi

# Make executable
echo "Setting permissions..."
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Ensure ~/.local/bin is in PATH
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo ""
    echo "Adding ~/.local/bin to your PATH..."

    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "$(which zsh)" ]; then
        SHELL_RC="$HOME/.zshrc"
    else
        SHELL_RC="$HOME/.bashrc"
    fi

    echo "" >> "$SHELL_RC"
    echo '# Added by appimage-manager installer' >> "$SHELL_RC"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"

    echo "Added to $SHELL_RC"
    echo "Run 'source $SHELL_RC' or open a new terminal to apply."
else
    echo "~/.local/bin is already in your PATH."
fi

echo ""
echo "Installation complete!"
echo "You can now run the tool anywhere by typing: $SCRIPT_NAME"
echo ""
echo "Try it:"
echo "  appimage --help"
echo "  appimage --install ~/Downloads/SomeApp.AppImage"
