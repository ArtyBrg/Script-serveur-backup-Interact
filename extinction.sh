#!/bin/bash

####################################################################################################
#
#  Description : Script permettant de shutdown le serveur de backup sans interrompre celles en cours
#
#  Auteur : Arthur BERGBAUER
#
#  Date : 16/05/2024
#
####################################################################################################

echo -e "\n##########################################################"
date
echo -e "Lancement du script d'éteinte de la machine : \n"

# Partie 1 : Vérification de l'exécution du script en root
if [[ $(id -u) != 0 ]];
then
        echo "Le script n'est pas exécute en root"
        exit 1
else
        echo "Le script est exécute en root"
        echo -e "Lancement de la vérification 'running' ... \n"
fi

# Partie 2 : Vérification de l'état d'exécution du script
CHEMIN_ABSOLU=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
FICHIER_LOCK="${CHEMIN_ABSOLU}/SHUTDOWN_BACKUPPC.LOCK"

# Fonction pour réaliser la vérification d'exécution
function verif_execution() {
        if [ -f $FICHIER_LOCK ]; then
                echo "Le script est déjà en cours d'execution."
                echo -e "########################################################## \n"
                exit 1
        fi
        touch "$FICHIER_LOCK"
}

verif_execution # Lancement de la fonction de vérification
echo -e "Le script n'est pas déjà en cours d'exécution \nVérification réussie, lancement de la vérification de l'état des backups ... \n"

# Partie 3 : Vérification de rsync
if [[ $(ps aux | grep -v grep | grep -c /usr/libexec/backuppc-rsync/rsync_bpc) -gt 0 ]];
then
        echo "Commande(s) rsync en cours détectée(s) :"
        RSYNC_DETECT=true

        RSYNC_MSG=$(ps aux | grep -v grep | grep /usr/libexec/backuppc-rsync/rsync_bpc | cut -d'/' -f2-)
        echo -e "$RSYNC_MSG \n"
else
        echo -e "Aucune instance de commandes rsync détectées en cours \n"
        RSYNC_DETECT=false
fi

# Partie 4 : Vérification de perl ; Peut être à ne pas mettre ?
if [[ $(ps aux | grep -v grep | grep -v Ss | grep -c /usr/share/backuppc/bin/BackupPC) -gt 0 ]];
then
        echo "Commande(s) perl en cours détectée(s) :"
        PERL_DETECT=true

        PERL_MSG=$(ps aux | grep -v grep | grep -v Ss | grep /usr/share/backuppc/bin/BackupPC | cut -d'/' -f2-)
        echo -e "$PERL_MSG \n"

else
        echo -e "Aucune instance de commandes perl détectées en cours \n"
        PERL_DETECT=false
fi

echo -e "Vérification des backups terminées, envoi des mails et des notifications nécessaires ... \n"

# Partie 5 : Extinction si le processus de backup est terminé
webhook="https://mattermost ..."
heure_extinction=$(date)

if [[ $RSYNC_DETECT == true || $PERL_DETECT == true ]];
then
	if [[ $RSYNC_DETECT == true ]];
	then
		echo -e "Envoi d'un message pour rsync ... \n"
                curl --location "$webhook" --header 'Content-Type: application/json' --data-raw '{"text":"Informations sur les commandes rsync en cours :\n/'"$RSYNC_MSG"' \n<@fpezier>"}'
	fi

	if [[ $PERL_DETECT == true ]];
	then
		echo -e "\nEnvoi d'un message pour perl ... \n"
		curl --location "$webhook" --header 'Content-Type: application/json' --data-raw '{"text":"Informations sur les commandes perl en cours :\n/'"$PERL_MSG"' \n<@fpezier>"}'
	fi

        rm -rf $FICHIER_LOCK # Suppresion du fichier pour signaler la fin de l'exécution

        echo -e "\nBackup en cours ; machine toujours allumée ; fin du script."
        echo -e "########################################################## \n"
        exit 1
else
        echo -e "Aucune backup en cours ; lancement de la phase d'extinction ... \n"

        if [[ $(sudo ethtool enp0s31f6 | grep Wake-on | grep -v Supports | awk '{print $2}') != "g" ]];
        then
                echo -e "Wake-On-LAN non activé ; activation manuel \n"
                sudo ethtool --change enp0s31f6 wol g
        fi

        curl --location "$webhook" --header 'Content-Type: application/json' --data-raw '{"text":"Machine éteinte via le script d extinction à '"$heure_extinction"'"}'

	rm -rf $FICHIER_LOCK # Suppresion du fichier pour signaler la fin de l'exécution

        echo "Extinction de la machine."
        echo -e "########################################################## \n"
        sudo poweroff
        exit 0
fi
