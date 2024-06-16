from flask import Flask, Response
import requests

app = Flask(__name__)

# URL contenant les metrics BackupPC
url = 'http://127.0.0.1/?action=metrics'

# Informations d'authentification
username = 'backuppc'
password = ''

# Fonction pour recup depuis l'URL
def get_backuppc_metrics(url):
    try:
        response = requests.get(url, auth=(username, password))
        response.raise_for_status()
        data = response.json()

        metrics = []

        # Fonction pour clean et convertir les valeurs
        def clean_value(value):
            if value is None:
                return 0
            if isinstance(value, str):
                try:
                    return float(value)
                except ValueError:
                    return value
            return value

        # Fonction pour clean les labels
        def clean_label(value):
            if value is None:
                return ""
            return str(value).replace(' ', '_').replace('"', '')

        # Metrics pour chaque host
        for host, metrics_data in data['hosts'].items():
            host_clean = clean_label(host)
            for key, value in metrics_data.items():
                key_clean = clean_label(key)
                if isinstance(value, list):
                    for i, v in enumerate(value):
                        metrics.append(f'backuppc_hosts_{key_clean}{{host="{host_clean}", index="{i}"}} {clean_value(v)}')
                elif isinstance(value, dict):
                    pass
                elif isinstance(value, str):
                    try:
                        float(value)
                        metrics.append(f'backuppc_hosts_{key_clean}{{host="{host_clean}"}} {value}')
                    except ValueError:
                        label_clean = clean_label(value)
                        metrics.append(f'backuppc_hosts_{key_clean}{{host="{host_clean}", label="{label_clean}"}} 1')
                else:
                    metrics.append(f'backuppc_hosts_{key_clean}{{host="{host_clean}"}} {clean_value(value)}')

        # Metrics pour les queues
        for key, value in data['queues'].items():
            key_clean = clean_label(key)
            metrics.append(f'backuppc_queues_{key_clean} {clean_value(value)}')

        # Metrics du disk
        for key, value in data['disk'].items():
            key_clean = clean_label(key)
            metrics.append(f'backuppc_disk_{key_clean} {clean_value(value)}')

        # Metrics du cpool
        for key, value in data['cpool'].items():
            key_clean = clean_label(key)
            metrics.append(f'backuppc_cpool_{key_clean} {clean_value(value)}')

        return '\n'.join(metrics)
    except requests.exceptions.RequestException as e:
        print(f"Une erreur s'est produite lors de la récupération des métrics : {e}")
        return ""

@app.route('/metrics')
def metrics():
    backuppc_metrics = get_backuppc_metrics(url)
    return Response(backuppc_metrics, mimetype='text/plain')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9091)  # Execute l'application Flask sur le port 9091
