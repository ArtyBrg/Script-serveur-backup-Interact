#!/bin/bash

heure=$(date)
webhook="https://mattermost ..."

curl --location "$webhook" --header 'Content-Type: application/json' --data-raw '{"text":"Démarrage de la backup de : '"$1"' à '"$heure"'"}'
