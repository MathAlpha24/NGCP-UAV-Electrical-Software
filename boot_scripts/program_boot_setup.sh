#!/bin/bash

# Usage:
#   Add a program to run at boot:
#     sudo ./service_manager.sh add /full/path/to/program
#
#   Remove a program from boot:
#     sudo ./service_manager.sh remove /full/path/to/program
#
#   Re-enable a previously disabled service:
#     sudo ./service_manager.sh reenable /full/path/to/program

set -e 
#set script to exit if any uncontrollable errors occur

ACTION="$1"
PROGRAM_PATH="$2"

if [[ "$ACTION" != "add" && "$ACTION" != "remove" && "$ACTION" != "reenable" ]]; then
    echo "ERROR: Invalid action '$ACTION'." 
    echo "SOLUTION: Use 'add', 'remove', or 'reenable'."
    exit 1
fi

if [[ -z "$PROGRAM_PATH" ]]; then
    echo "ERROR: Program path argument missing."
    exit 1
fi

PROGRAM_NAME=$(basename "$PROGRAM_PATH")
SERVICE_FILE="/etc/systemd/system/$PROGRAM_NAME.service"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Please run as root (use sudo)."
    exit 1
fi

case "$ACTION" in
    add)
        if [ ! -x "$PROGRAM_PATH" ]; then
            echo "ERROR: Program '$PROGRAM_PATH' is not executable or does not exist."
            exit 1
        fi

        if [ -f "$SERVICE_FILE" ]; then
            echo "WARNING: Service file already exists: $SERVICE_FILE"
            read -p "Overwrite? (y/n): " ans
            if [[ ! "$ans" =~ ^[Yy]$ ]]; then
                echo "Aborting."
                exit 0
            fi
        fi

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

        systemctl daemon-reload
        systemctl enable "$PROGRAM_NAME.service"
        systemctl start "$PROGRAM_NAME.service"
        echo "Service '$PROGRAM_NAME' added, enabled, and started."
        ;;
    
    remove)
        if [ ! -f "$SERVICE_FILE" ]; then
            echo "Service file does not exist: $SERVICE_FILE"
            exit 0
        fi

        systemctl stop "$PROGRAM_NAME.service" || true
        systemctl disable "$PROGRAM_NAME.service" || true
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
        echo "Service '$PROGRAM_NAME' stopped, disabled, and removed."
        ;;

    reenable)
        if [ ! -f "$SERVICE_FILE" ]; then
            echo "Service file does not exist: $SERVICE_FILE"
            echo "Cannot re-enable."
            exit 1
        fi

        systemctl enable "$PROGRAM_NAME.service"
        systemctl start "$PROGRAM_NAME.service"
        echo "Service '$PROGRAM_NAME' re-enabled and started."
        ;;
esac

exit 0
