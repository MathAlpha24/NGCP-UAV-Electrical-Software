#!/bin/bash
# Run the script with the program_path as an argument

# 1. SET VARIABLES
PROGRAM_PATH="$1"
PROGRAM_NAME=$(basename "$PROGRAM_PATH")
AUTOSTART_DIR="$HOME/.config/autostart"
DESKTOP_FILE="$AUTOSTART_DIR/${PROGRAM_NAME}.desktop"

# 2. ERROR HANDLING
if [ -z "$PROGRAM_PATH" ]; then 
    echo "ERROR: Program path not provided as argument." 
    echo "SOLUTION: Please provide path to program."
    exit 1
fi

if [ ! -x "$PROGRAM_PATH" ]; then
    echo "ERROR: Program at the path is not executable."
    echo "SOLUTION: Please check program at path and run chmod +x if needed."
    exit 1
fi

# 3. CREATE AUTOSTART ILE IN GHOME TERMINAL
mkdir -p "$AUTOSTART_DIR"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Exec=gnome-terminal -- bash -c "\$PROGRAM_PATH\";  xdg-open http://0.0.0.0:8080; exec bash"
Name= Kraken Autostart Script
X-GNOME-Autostart-enabled=true
EOF

chmod 755 "$DESKTOP_FILE"

# 4. END SCRIPT
echo "$PROGRAM_NAME has been set to run at boot"
gnome-session-properties #visually confirm that the script "Kraken Autostart Script" is listed
echo "Finished running krakensdr_boot_setup.sh"     
exit 0
