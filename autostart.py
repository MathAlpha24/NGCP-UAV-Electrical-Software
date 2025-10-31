```
#!/bin/bash

### BEGIN INIT INFO
# Provides:          mavsdk-service
# Required-Start:    $remote_fs $syslog $network
# Required-Stop:     $remote_fs $syslog $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: MAVSDK Python application
# Description:       Auto-start MAVSDK Python application on boot
### END INIT INFO

# Configuration
SCRIPT_NAME="mavsdk-service"
PYTHON_SCRIPT="/path/to/your/mavsdk_app.py"
PYTHON_BIN="/usr/bin/python3"
WORKING_DIR="/path/to/your/working/directory"
LOG_DIR="/var/log/mavsdk"
PID_FILE="/var/run/mavsdk.pid"
USER="your_username"  # Run as specific user

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"
chown "$USER":"$USER" "$LOG_DIR"

# Function to start the service
start() {
    echo "Starting $SCRIPT_NAME..."
    
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "$SCRIPT_NAME is already running"
        return 1
    fi
    
    # Start the Python script
    su - "$USER" -c "cd $WORKING_DIR && $PYTHON_BIN $PYTHON_SCRIPT >> $LOG_DIR/mavsdk.log 2>&1 &"
    echo $! > "$PID_FILE"
    
    echo "$SCRIPT_NAME started with PID $(cat $PID_FILE)"
}

# Function to stop the service
stop() {
    echo "Stopping $SCRIPT_NAME..."
    
    if [ ! -f "$PID_FILE" ]; then
        echo "$SCRIPT_NAME is not running"
        return 1
    fi
    
    PID=$(cat "$PID_FILE")
    kill "$PID" 2>/dev/null
    
    # Wait for process to stop
    for i in {1..10}; do
        if ! kill -0 "$PID" 2>/dev/null; then
            break
        fi
        sleep 1
    done
    
    # Force kill if still running
    if kill -0 "$PID" 2>/dev/null; then
        kill -9 "$PID" 2>/dev/null
    fi
    
    rm -f "$PID_FILE"
    echo "$SCRIPT_NAME stopped"
}

# Function to check status
status() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "$SCRIPT_NAME is running with PID $(cat $PID_FILE)"
    else
        echo "$SCRIPT_NAME is not running"
        return 1
    fi
}

# Function to restart
restart() {
    stop
    sleep 2
    start
}

# Main script logic
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
```
