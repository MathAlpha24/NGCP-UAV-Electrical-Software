#!/bin/bash

# 1. SET VARIABLES

# 1a. Set variable PROGRAM_PATH equal to the input argument.
PROGRAM_PATH="$1"

# 1b. Get the name of the program from the path.
PROGRAM_NAME=$(basename "$PROGRAM_PATH")

# --------------------------------------- 
# 2. ERROR HANDLING

# 2a. Check if set_program_boot.sh is being run in root.
if [[ $EUID -ne 0 ]]; then
# Check if Effective User ID - user running command (EUID)- does NOT (-ne) equal root user ID (always 0).
# If true, run error comment below and exit.
  echo "ERROR: Program not being run in root."
  echo "SOLUTION: Please run this script as root (use sudo)"
  exit 1
fi

# 2b. Check if program is in argument.
if [ -z "$1" ]; then 
# Check if the argument ($1) if passed as a string has zero characters (-z). 
# If true, run error comment below and exit.
    echo "ERROR: Program path not provided as arguement." 
    echo "SOLUTION: Please copy and paste path to program."
    exit 1
fi

# 2c. Check if program path is valid (aka does the program even exist?)
if [ ! -x "$PROGRAM_PATH" ]
# Check if the program "PROGRAM_PATH" is NOT (!) executable (-x).
# If true, run error comment below and exit.
    echo "ERROR: Program at the path is not executable."
    echo "SOLUTION: Please check program at path."
    exit 1
fi

# --------------------------------------- 
# 3. CREATE SYSTEMMD SERVICE FILE AND SET TO RUN AT BOOT

# 3a. Create systemmd service file
SERVICE_FILE="/etc/systemd/system/$PROGRAM_NAME.service"
echo "Creating systemd service at $SERVICE_FILE..."


# 3b. Write the systemd service unit file
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Run $PROGRAM_NAME at startup
After=network.target

[Service]
ExecStart=$PROGRAM_PATH
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF


# --------------------------------------- 
# 4. ENABLE & START SERVICE

# 4a. Reload systemd to recognize the new service
systemctl daemon-reexec
systemctl daemon-reload

# 4b.  Enable the service to run at boot
systemctl enable "$PROGRAM_NAME.service"
echo "'$PROGRAM_NAME' has been set to run at boot"


# --------------------------------------- 
#5. END SCRIPT
echo "Closing set_program_boot.sh"
exit 0

