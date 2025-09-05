#!/bin/bash

#Run the script with the program_path as an argument

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
if [ ! -x "$PROGRAM_PATH" ] then
# Check if the program "PROGRAM_PATH" is NOT (!) executable (-x).
# If true, run error comment below and exit.
    echo "ERROR: Program at the path is not executable."
    echo "SOLUTION: Please check program at path."
    exit 1
fi

# --------------------------------------- 
# 3. SYSTEMMD SERVICE FILE CREATOPM

# 3a. Create systemmd service file.
SERVICE_FILE="/etc/systemd/system/$PROGRAM_NAME.service"
echo "Creating systemd service at $SERVICE_FILE..."

# 3b. Check if the service file already exists
if [ -f "$SERVICE_FILE" ]; then 
# Check (-f) if name of the system service file ("$SERVICE FILE") already is there. 
# If true, then assume the system file is already is already set up and run bash script below.
    echo "WARNING: The service file '$SERVICE_FILE' already exists."

    while true; do #only way to exit the while loop is to type in a valid input due to lack of a while loop parameter.
        # Ask user whether to overwrite
        read -p "Do you want to overwrite it? (y/n): " answer
        #Wait for user to type in Y/y or N/n (to ensure its not caps sensetive.)
        case "$answer" in
            [Yy]* )
                echo "Overwriting existing service file..."
                break
                ;;
            [Nn]* )
                echo "Aborting setup. No changes made."
                exit 0
                ;;
            * )
                echo "Invalid input. Please enter y or n."
                ;;
        esac
    done
fi

# 3c. Write the systemd service unit file
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
#Systemctl is the commandline tool to manage systemd services.
#First replaces current systemd process with fresh systemd process 
systemctl daemon-reexec

#Reloads all unit files without restarting systemd
systemctl daemon-reload

# 4b.  Enable the service to run at boot
# This creates a symlink from your service to the appropriate boot target.
systemctl enable "$PROGRAM_NAME.service"
echo "'$PROGRAM_NAME' has been set to run at boot"


# --------------------------------------- 
#5. END SCRIPT
echo "Closing set_program_boot.sh"
exit 0

