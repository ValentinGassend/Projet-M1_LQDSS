import websocket
import subprocess

def on_message(ws, message):
    print("Message reçu:", message)

    if message.startswith("start"):
        # Extraire la vitesse
        try:
            speed = int(message.split()[1])
            if 0 <= speed <= 255:
                result = subprocess.run(['python3', 'turn-right.py', str(speed)], capture_output=True, text=True)
                if result.returncode == 0:
                    print(f"Script 'turn-right.py' exécuté avec succès : {result.stdout}")
                else:
                    print(f"Erreur lors de l'exécution de 'turn-right.py' : {result.stderr}")

            else:
                print("Erreur: La vitesse doit être entre 0 et 255.")
        except (ValueError, IndexError):
            print("Erreur: Commande invalide. Utilisez 'start <vitesse>'.")

    elif message == "stop":
        result = subprocess.run(['python3', 'stop.py'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"Script 'stop.py' exécuté avec succès : {result.stdout}")
        else:
            print(f"Erreur lors de l'exécution de 'stop.py' : {result.stderr}")


    else:
        print("Commande inconnue. Utilisez 'start <vitesse>' ou 'stop'.")


def on_error(ws, error):
    print("Erreur:", error)

def on_close(ws, close_status_code, close_msg):
    print("Connexion fermée")

def on_open(ws):
    print("Connexion ouverte")
    ws.send("Bonjour, serveur !")

# Remplacez 'wss://example.com/socket' par l'URL de votre WebSocket
ws = websocket.WebSocketApp("ws://192.168.1.144:8080/rpiConnect",
                            on_open=on_open,
                            on_message=on_message,
                            on_error=on_error,
                            on_close=on_close)

ws.run_forever()
