#!/usr/bin/env bash

set -e

export SERVICE_USER=upmonitor

sudo mkdir -p /var/"$SERVICE_USER"

id -u "$SERVICE_USER" >/dev/null 2>&1 || sudo useradd --home "/var/$SERVICE_USER" --shell /bin/bash --user-group "$SERVICE_USER"

if [ ! -f /var/"$SERVICE_USER"/.env ]; then
    if [ ! -f ./.env ]; then
        echo "ERROR: No .env file." >&2
        exit 1
    fi

    sudo cp ./.env /var/"$SERVICE_USER"/.env
fi

if [ ! -f /var/"$SERVICE_USER"/list.txt ]; then
    sudo cp ./.env /var/"$SERVICE_USER"/list.txt
fi

sudo cp ./check.sh /var/"$SERVICE_USER"/check.sh

sudo chown "$SERVICE_USER":"$SERVICE_USER" /var/"$SERVICE_USER"
sudo chown -R "$SERVICE_USER":"$SERVICE_USER" /var/"$SERVICE_USER"/*
sudo chmod 400 /var/"$SERVICE_USER"/list.txt
sudo chmod 770 /var/"$SERVICE_USER"/check.sh

sudo cat ./"$SERVICE_USER".service | envsubst | sudo tee /etc/systemd/system/"$SERVICE_USER".service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_USER"
sudo systemctl start "$SERVICE_USER"

if [ -f ./.env ]; then
    rm ./.env
fi
