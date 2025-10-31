
#!/bin/bash
#Run the script with the program_path as an argument

# 1. SET VARIABLES

# 1a. Set variable PROGRAM_PATH equal to the input argument.
PROGRAM_PATH="$1"

# 1b. Get the name of the program from the path.
PROGRAM_NAME=$(basename "$PROGRAM_PATH")
AUTOSTART_DIR="$HOME/.config/autostart"
DESKTOP_FILE="$AUTOSTART_DIR/${PROGRAM_NAME}.desktop"

# --------------------------------------- 
# 2. ERROR HANDLING

# 2b. Check if program is in argument.
if [ -z "$1" ]; then 
# Check if the argument ($1) if passed as a string has zero characters (-z). 
# If true, run error comment below and exit.
    echo "ERROR: Program path not provided as argument." 
    echo "SOLUTION: Please copy and paste path to program."
    exit 1
fi

# 2c. Check if program path is valid (aka does the program even exist?)
if [ ! -x "$PROGRAM_PATH" ]; then
# Check if the program "PROGRAM_PATH" is NOT (!) executable (-x).
# If true, run error comment below and exit.
    echo "ERROR: Program at the path is not executable."
    echo "SOLUTION: Please check program at path."
    exit 1
fi

# --------------------------------------- 
# 3. STARUP FILE USER SERVICE FILE CREATOPM

mkdir -p "$AUTOSTART_DIR"

# 3c. Set the program to run at user-space startup
cat > "$DESKTOP_FILE" <<EOF

[Desktop Entry]
Type=Application
Exec=gnome-terminal -- bash -c "~/krakensdr_doa/kraken_doa_start.sh; exec bash"
Name=Kraken Autostart Script
X-GNOME-Autostart-enabled=true

EOF

chmod 755 "$DESKTOP_FILE"

# --------------------------------------- 
# 4. END SCRIPT

echo "$PROGRAM_NAME' has been set to run at boot"
echo "Closing set_program_boot.sh"
exit 0

  
