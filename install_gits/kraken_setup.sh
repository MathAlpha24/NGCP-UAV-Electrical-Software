#!/bin/bash

#Run on Raspberry Pi 5 to either install, update, or provide a clean install of kraken_sdr

ACTION ="$1"

# ---------------

if [[ "$ACTION" != "install" && "$ACTION" != "update" && "$ACTION" != "clean_install" ]]; then
    echo "ERROR: Invalid action '$ACTION'." 
    echo "SOLUTION: Use 'install', 'update', or 'clean_install'."
    exit 1
fi


#if clean install, give warning on 
if [[ $ACTION == "clean_install" ]]; then
    echo "WARNING: A clean install will delete the folder with all of the contents of the Kraken_SDR respository!"
    read -p "Clean Install? (y/n): " ans
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then
            echo "Aborting."
            exit 0
        fi
    
    #otherwise first delete everything related to the file.
    echo "[*] Stopping KrakenSDR processes..."
    pkill -f doa.sh
    pkill -f krakensdr

    echo "[*] Removing old directories..."
    rm -rf ~/krakensdr
    rm -f ~/krakensdr_aarch64_install_doa.sh
    rm -rf ~/miniforge3
    rm -f ~/Miniforge3-Linux-aarch64.sh

    #delete the x86 installer just in case someone else decided to install the wrong version.
    rm -f ~/krakensdr_x86_install_doa.sh
    rm -f ~/Miniforge3-Linux-x86.sh


fi

if [[ "$ACTION" == "clean_install" || "$ACTION" == "install" ]]; then

    wget https://raw.githubusercontent.com/krakenrf/krakensdr_docs/main/install_scripts/krakensdr_aarch64_install_doa.sh
    sudo chmod +x krakensdr_aarch64_install_doa.sh


fi

#regardless of action, run script:
./krakensdr_aarch64_install_doa.sh

