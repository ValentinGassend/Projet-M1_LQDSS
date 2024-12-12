import websocket
import subprocess
import os 
import time
import threading

DetectedObject = False
turn_right_process = None  # Global variable to track the turn-right process


def on_message(ws, message):
    global turn_right_process  # Access the global variable

    print("Message reçu:", message)

    if message.startswith("start"):
        # Extraire la vitesse
        try:
            speed = int(message.split()[1])
            if 0 <= speed <= 255:
                # Lancer le script 'turn-right.py' et enregistrer le processus
                if turn_right_process is not None:
                    print("Un processus 'turn-right.py' est déjà en cours. Arrêt en cours...")
                    turn_right_process.terminate()
                    turn_right_process = None
                
                turn_right_process = subprocess.Popen(
                    ['python3', 'turn-right.py', str(speed)],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
                print(f"'turn-right.py' lancé avec la vitesse {speed}.")
            else:
                print("Erreur: La vitesse doit être entre 0 et 255.")
        except (ValueError, IndexError):
            print("Erreur: Commande invalide. Utilisez 'start <vitesse>'.")

    elif message == "stop":
        # Arrêter le script 'turn-right.py' s'il est en cours
        if turn_right_process is not None:
            print("Arrêt du processus 'turn-right.py'.")
            turn_right_process.terminate()
            turn_right_process = None
        else:
            print("Aucun processus 'turn-right.py' n'est en cours.")

        # Lancer le script 'stop.py'
        threading.Thread(target=run_stop_script).start()

    else:
        print("Commande inconnue. Utilisez 'start <vitesse>' ou 'stop'.")


def run_stop_script():
    try:
        result = subprocess.run(['python3', 'stop.py'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"Script 'stop.py' exécuté avec succès : {result.stdout}")
        else:
            print(f"Erreur lors de l'exécution de 'stop.py' : {result.stderr}")
    except Exception as e:
        print(f"Erreur lors de l'exécution du script 'stop.py': {e}")


def on_error(ws, error):
    print("Erreur:", error)


def on_close(ws, close_status_code, close_msg):
    print("Connexion fermée")


def on_open(ws):
    print("Connexion ouverte")
    ws.send("Bonjour, serveur !")


def run_websocket(ws):
    """Exécute une instance WebSocket."""
    ws.run_forever()


# WebSocket pour la connexion principale
ws = websocket.WebSocketApp(
    "ws://192.168.10.146:8080/tornado_rpiConnect",
    on_open=on_open,
    on_message=on_message,
    on_error=on_error,
    on_close=on_close
)

# Créer un thread pour exécuter le WebSocket
thread_connect = threading.Thread(target=run_websocket, args=(ws,))
thread_connect.daemon = True
thread_connect.start()

try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("Interruption par l'utilisateur.")
    # Terminer le processus en cours si nécessaire
    if turn_right_process is not None:
        turn_right_process.terminate()
        print("Processus 'turn-right.py' arrêté.")
