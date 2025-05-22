#!/bin/bash

# Adresse IP de la machine cible a pinger
ip_cible="192.168. ..."

# Adresse MAC de la machine a reveiller en cas d'echec de ping
wol_mac="..."

# Nombre de tentatives de pings
tentative_ping=10

# Nombre minimum de paquets a recevoir pour considerer le ping comme reussi
min_packets_recu=7

# Webhook pour les notifs allant vers le salon Mattermost de BackupPC
webhook="https://mattermost ..."

# Fonction de verification des pings
verif_ping() {
    local ip_cible=$1
    local tentative_ping=$2
    local packets_recu=0
    local ping_details=""
    local resultat=""

    for (( i=1; i<=$tentative_ping; i++ )); do
        resultat=$(ping -c 1 $ip_cible)

        if [[ $resultat == *"1 received"* ]];
        then
            ping_details+="Tentative de ping $i sur $tentative_ping ... Ping réussi \n"
            packets_recu=$((packets_recu + 1))
        else
            ping_details+="Tentative de ping $i sur $tentative_ping ... Ping échoué \n"
        fi
    done

    echo -e $ping_details
    echo "$packets_recu"
}

echo -e "\n############################################################################"
date
echo -e "Script de vérification de l'état de la machine de backup : \n"

# Partie 1 : Verification de l'etat d'execution du script
CHEMIN_ABSOLU=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
FICHIER_LOCK="${CHEMIN_ABSOLU}/WOL.LOCK"

# Fonction pour realiser la verification d'execution
function verif_execution() {
    	if [ -f $FICHIER_LOCK ]; then
        	echo "Le script est déjà en cours d'execution."
		echo -e "############################################################################ \n"
		exit 1
	fi
	touch "$FICHIER_LOCK"
}

verif_execution # Lancement de la fonction de verification
echo -e "Le script n'est pas déjà en cours d'exécution \nVérification réussie, lancement de la vérification d'état ... \n"

# Partie 1: Verification de l'etat de la machine avant reveil force�
packets_recu=$(verif_ping $ip_cible $tentative_ping)
if [ ${packets_recu: -2} -ge 7 ]; 
then
    echo "${packets_recu::-3}"
else
    echo "${packets_recu::-2}"
fi

# Partie 2: Verification du nombre de paquets recus et envoi du paquet Wake-on-LAN si necessaire
if [ ${packets_recu: -2} -ge $min_packets_recu ];
then
    echo "Nombre de paquets reçus: ${packets_recu: -2}. Machine deja allumée."
    curl --location "$webhook" --header 'Content-Type: application/json' --data-raw '{"text":"Machine déjà allumée ; pas besoin d envoyer un signal Wake-ON-LAN"}'
    rm -rf $FICHIER_LOCK
    echo -e "############################################################################ \n"
    exit 0
else
    echo -e "Moins de $min_packets_recu paquets ont ete reçus. Envoi du paquet Wake-on-LAN ... \n"
    wakeonlan $wol_mac
    echo -e "Envoi d'une notification pour indiquer qu'un signal Wake-on-LAN à été envoyé \n"
    curl --location "$webhook" --header 'Content-Type: application/json' --data-raw '{"text":"Signal Wake-on-Lan envoyé, si une prochaine notification arrive, ce signal aura échoué <@user>","username": "backuppc"}'
    heure_wol=$(date)
fi

# Partie 3 : Reverification de l'etat de la machine apres le reveil force
sleep 300
echo -e "Lancement de la nouvelle vérification après reveil forcé de la machine : \n"

packets_recu=$(verif_ping $ip_cible $tentative_ping)
if [ ${packets_recu: -2} -ge 7 ];
then
    echo "${packets_recu::-3}"
else
    echo "${packets_recu::-2}"
fi

if [ ${packets_recu: -2} -ge $min_packets_recu ];
then
    echo "Nombre de paquets reçus: ${packets_recu: -2}. Machine correctement allumée après le réveil."
    curl --location "$webhook" --header 'Content-Type: application/json' --data-raw '{"text":"Machine réveillée à '"$heure_wol"'"}'
else
    echo "Moins de $min_packets_recu paquets ont ete reçus ; la machine ne s'est pas correctement allumée."
    echo -e "Envoi d'une notification en conséquence ... \n"
    curl --location "$webhook" --header 'Content-Type: application/json' --data-raw '{"text":"La machine de backup est toujours éteinte ; voici les différents ping pouvant permettre à une étude plus approfondie : \n '"${packets_recu::-3}"' <@user>","username": "backuppc"}'
fi

rm -rf $FICHIER_LOCK # Suppresion du fichier pour signaler la fin de l'execution

echo "Fin du script."
echo -e "############################################################################ \n"

exit 0
