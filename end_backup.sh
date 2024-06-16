#!/bin/bash

heure=$(date)
webhook="https://mattermost ..."

if [[ $2 != 1 ]];
then
    curl --location "$webhook" --header 'Content-Type: application/json' --data-raw '{"text":"Fin de la backup de : '"$1"', en erreur à '"$heure"' ; <@fpezier>"}'
else
    curl --location "$webhook" --header 'Content-Type: application/json' --data-raw '{"text":"Fin de la backup de : '"$1"' à '"$heure"'"}'
fi
