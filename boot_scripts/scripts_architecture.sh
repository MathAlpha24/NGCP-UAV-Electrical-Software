TEST BEFORE RUNNING
```
#!/bin/bash
#
# KrakenSDR UAV Boot Script for Arch Linux
# Initializes KrakenSDR hardware, positioning, and data streaming for UAV operations
#

set -e

# Configuration
LOG_FILE="/var/log/kraken_uav_boot.log"
KRAKEN_PATH="/opt/krakensdr"
DATA_PATH="/mnt/kraken_data"
GPS_DEVICE="/dev/ttyACM0"
WIFI_INTERFACE="wlan0"
GROUND_STATION_IP="192.168.1.100"
STREAM_PORT="8080"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== KrakenSDR UAV Boot Sequence Started ==="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log "ERROR: This script must be run as root"
   exit 1
fi

# Create necessary directories
log "Creating directory structure..."
mkdir -p "$DATA_PATH"
mkdir -p /var/run/kraken

# Set CPU governor to performance
log "Setting CPU governor to performance mode..."
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if [ -f "$cpu" ]; then
        echo performance > "$cpu"
    fi
done

# Disable unnecessary services to save power/resources
log "Disabling unnecessary services..."
systemctl stop bluetooth.service 2>/dev/null || true
systemctl stop cups.service 2>/dev/null || true

# Configure USB power management for stable SDR operation
log "Configuring USB power management..."
for usb in /sys/bus/usb/devices/*/power/control; do
    echo "on" > "$usb" 2>/dev/null || true
done

# Increase USB buffer size for KrakenSDR
log "Optimizing USB buffers..."
echo 128 > /sys/module/usbcore/parameters/usbfs_memory_mb || log "Warning: Could not set USB memory"

# Initialize GPS module
log "Initializing GPS module..."
if [ -e "$GPS_DEVICE" ]; then
    stty -F "$GPS_DEVICE" 9600 cs8 -cstopb -parenb
    log "GPS device configured at $GPS_DEVICE"
else
    log "WARNING: GPS device not found at $GPS_DEVICE"
fi

# Start gpsd for GPS positioning
log "Starting gpsd daemon..."
systemctl start gpsd.service 2>/dev/null || gpsd -n "$GPS_DEVICE" -F /var/run/gpsd.sock &

# Configure network interface for ground station communication
log "Configuring network interface..."
ip link set "$WIFI_INTERFACE" up 2>/dev/null || log "Warning: Could not bring up $WIFI_INTERFACE"

# Wait for network connectivity
log "Waiting for network connectivity..."
timeout=30
while ! ping -c 1 -W 1 "$GROUND_STATION_IP" &>/dev/null && [ $timeout -gt 0 ]; do
    sleep 1
    ((timeout--))
done

if [ $timeout -eq 0 ]; then
    log "WARNING: Could not reach ground station at $GROUND_STATION_IP"
else
    log "Network connectivity established to ground station"
fi

# Set system time from GPS (if available)
log "Synchronizing time from GPS..."
timeout 10 gpspipe -w -n 10 | grep -m 1 TPV && log "GPS time sync attempted" || log "GPS time sync unavailable"

# Initialize KrakenSDR hardware
log "Initializing KrakenSDR hardware..."

# Reset USB devices (KrakenSDR uses 5x RTL-SDR dongles)
for dev in /sys/bus/usb/devices/*/authorized; do
    echo 0 > "$dev" 2>/dev/null || true
    sleep 0.1
    echo 1 > "$dev" 2>/dev/null || true
done

sleep 2

# Check for RTL-SDR devices
RTL_COUNT=$(rtl_test 2>&1 | grep -c "Found" || echo 0)
log "Found $RTL_COUNT RTL-SDR devices"

if [ "$RTL_COUNT" -lt 5 ]; then
    log "ERROR: KrakenSDR requires 5 RTL-SDR devices, found $RTL_COUNT"
    log "Attempting to recover..."
    modprobe -r dvb_usb_rtl28xxu rtl2832 2>/dev/null || true
    sleep 1
    modprobe dvb_usb_rtl28xxu || true
    sleep 2
    RTL_COUNT=$(rtl_test 2>&1 | grep -c "Found" || echo 0)
    log "After recovery: Found $RTL_COUNT RTL-SDR devices"
fi

# Set up KrakenSDR environment
log "Setting up KrakenSDR environment..."
cd "$KRAKEN_PATH" || { log "ERROR: KrakenSDR path not found"; exit 1; }

# Export environment variables
export KRAKEN_DATA_PATH="$DATA_PATH"
export KRAKEN_GPS_DEVICE="$GPS_DEVICE"
export KRAKEN_STREAM_IP="$GROUND_STATION_IP"
export KRAKEN_STREAM_PORT="$STREAM_PORT"

# Start KrakenSDR processing daemon
log "Starting KrakenSDR DAQ..."
if [ -f "$KRAKEN_PATH/krakensdr_doa/heimdall_daq_fw/Firmware/_daq_core/daq_start_sm.sh" ]; then
    cd "$KRAKEN_PATH/krakensdr_doa/heimdall_daq_fw/Firmware/_daq_core"
    ./daq_start_sm.sh &
    DAQ_PID=$!
    echo $DAQ_PID > /var/run/kraken/daq.pid
    log "KrakenSDR DAQ started (PID: $DAQ_PID)"
else
    log "WARNING: KrakenSDR DAQ start script not found"
fi

sleep 5

# Start KrakenSDR DOA processing
log "Starting KrakenSDR DOA processing..."
if [ -f "$KRAKEN_PATH/krakensdr_doa/heimdall_daq_fw/Firmware/_signal_processor/kraken_doa_start.sh" ]; then
    cd "$KRAKEN_PATH/krakensdr_doa/heimdall_daq_fw/Firmware/_signal_processor"
    ./kraken_doa_start.sh &
    DOA_PID=$!
    echo $DOA_PID > /var/run/kraken/doa.pid
    log "KrakenSDR DOA processor started (PID: $DOA_PID)"
else
    log "WARNING: KrakenSDR DOA start script not found"
fi

# Start data streaming to ground station
log "Starting data stream to ground station..."
if command -v socat &> /dev/null; then
    socat TCP-LISTEN:$STREAM_PORT,fork,reuseaddr STDOUT < "$DATA_PATH/kraken_output.dat" &
    STREAM_PID=$!
    echo $STREAM_PID > /var/run/kraken/stream.pid
    log "Data stream started (PID: $STREAM_PID)"
fi

# Monitor system health
log "Starting system health monitor..."
cat << 'EOF' > /var/run/kraken/health_monitor.sh
#!/bin/bash
while true; do
    CPU_TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000}')
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    MEM_USAGE=$(free | grep Mem | awk '{print ($3/$2) * 100.0}')
    
    echo "[$(date '+%H:%M:%S')] CPU: ${CPU_USAGE}% Temp: ${CPU_TEMP}°C Mem: ${MEM_USAGE}%" >> /var/log/kraken_health.log
    
    # Check if processes are still running
    if [ -f /var/run/kraken/daq.pid ]; then
        if ! ps -p $(cat /var/run/kraken/daq.pid) > /dev/null; then
            echo "[$(date '+%H:%M:%S')] ERROR: DAQ process died" >> /var/log/kraken_health.log
        fi
    fi
    
    sleep 10
done
EOF

chmod +x /var/run/kraken/health_monitor.sh
/var/run/kraken/health_monitor.sh &
HEALTH_PID=$!
echo $HEALTH_PID > /var/run/kraken/health.pid

# Set LED indicators (if available)
if [ -d /sys/class/leds ]; then
    log "Setting status LEDs..."
    echo default-on > /sys/class/leds/*/trigger 2>/dev/null || true
fi

log "=== KrakenSDR UAV Boot Sequence Complete ==="
log "DAQ Status: $(systemctl is-active kraken-daq 2>/dev/null || echo 'running standalone')"
log "Ground Station: $GROUND_STATION_IP:$STREAM_PORT"
log "Data Path: $DATA_PATH"
log "GPS: $GPS_DEVICE"

# Create status file
cat << EOF > /var/run/kraken/status.txt
KrakenSDR UAV Status
====================
Boot Time: $(date)
RTL-SDR Devices: $RTL_COUNT
Ground Station: $GROUND_STATION_IP:$STREAM_PORT
GPS Device: $GPS_DEVICE
Data Path: $DATA_PATH
DAQ PID: $(cat /var/run/kraken/daq.pid 2>/dev/null || echo "N/A")
DOA PID: $(cat /var/run/kraken/doa.pid 2>/dev/null || echo "N/A")
EOF

log "Boot script completed successfully"
exit
```
