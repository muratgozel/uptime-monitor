#!/usr/bin/env bash

SERVICE_USER=upmonitor

if [ ! -f /var/"$SERVICE_USER"/.env ]; then
    echo "ERROR: No .env file." >&2
    exit 1
fi

sudo useradd --home /var/"$SERVICE_USER" --shell /bin/bash --user-group "$SERVICE_USER"

cp ./list.txt /var/"$SERVICE_USER"/list.txt
cp ./check.sh /var/"$SERVICE_USER"/check.sh

sudo chown -R "$SERVICE_USER":"$SERVICE_USER" /var/"$SERVICE_USER"/**/*
sudo chmod 400 /etc/"$SERVICE_USER"/list.txt
sudo chmod 770 /etc/"$SERVICE_USER"/check.sh

sudo cat ./etc/systemd/system/"$SERVICE_USER".service | envsubst | sudo tee /etc/systemd/system/"$SERVICE_USER".service > /dev/null
sudo systemctl daemon-reload
sudo service "$SERVICE_USER" enable
sudo service "$SERVICE_USER" start
