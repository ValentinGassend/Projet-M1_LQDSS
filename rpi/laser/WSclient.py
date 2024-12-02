
import websocket
import subprocess
import os 
import time
import threading

class WSClient:
    def __init__(self, url, name):
        self.url = url
        self.name = name
        self.ws = None
        self.thread = None
        self.DetectedObject = False
        self.laser_running = False  # Indicateur pour le script laser


    def on_message(self, ws, message):
        print(f"[{self.name}] Message reçu : {message}")
        if message == "python3 laser.py":
            if not self.laser_running:
                self.laser_running = True
                print("DEBUG: Lancement du script laser.")
                threading.Thread(target=self.launch_laser, daemon=True).start()
        elif message == "stop":
            print("DEBUG: Arrêt demandé pour le script laser.")
            self.laser_running = False

    def on_error(self, ws, error):
        print(f"[{self.name}] Erreur : {error}")

    def on_close(self, ws, close_status_code, close_msg):
        print(f"[{self.name}] Connexion fermée")

    def on_open(self, ws):
        print(f"[{self.name}] Connexion ouverte")
        ws.send("Bonjour, serveur !")

    def launch_laser(self):
        """Lance et surveille l'exécution du script laser.py."""
        while self.laser_running:
            process = subprocess.Popen(
                "python3 laser.py",
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                while self.laser_running:
                    output = process.stdout.readline().strip()
                    if output:
                        print(f"Sortie de laser.py : {output}")

                        # Mise à jour de l'état
                        if output == "Laser aligné.":
                            if not self.DetectedObject:
                                self.DetectedObject = True
                                print("DEBUG: DetectedObject est maintenant True")
                                client_laser_message.send_data(repr(self.DetectedObject))
                        else:
                            if self.DetectedObject:
                                self.DetectedObject = False
                                print("DEBUG: DetectedObject est maintenant False")
                                client_laser_message.send_data(repr(self.DetectedObject))

                    if output == "" and process.poll() is not None:
                        break
            except Exception as e:
                print(f"Erreur dans launch_laser : {e}")
            finally:
                process.terminate()
                print("laser.py terminé.")
            time.sleep(1)  # Ajoute un délai pour éviter une boucle trop rapide


    def send_data(self, data):
        """Envoie des données via WebSocket."""
        try:
            self.ws.send(data)
            print(f"[{self.name}] Données envoyées : {data}")
        except Exception as e:
            print(f"[{self.name}] Erreur lors de l'envoi des données : {e}")

    def run(self):
        """Démarre la connexion WebSocket dans un thread séparé."""
        self.ws = websocket.WebSocketApp(
            self.url,
            on_open=self.on_open,
            on_message=self.on_message,
            on_error=self.on_error,
            on_close=self.on_close
        )
        self.thread = threading.Thread(target=self.ws.run_forever)
        self.thread.daemon = True
        self.thread.start()

# Initialisation des clients WebSocket
# client_connect = WSClient("ws://172.28.55.70:8080/rpiConnect", "rpiConnect")
client_laser_connect = WSClient("ws://172.28.55.70:8080/rpiLaserConnect", "rpiLaserConnect")
client_laser_message = WSClient("ws://172.28.55.70:8080/rpiLaserMessage", "rpiLaserMessage")

# Démarrage des connexions
# client_connect.run()
client_laser_connect.run()
client_laser_message.run()

# Boucle principale pour maintenir le programme actif
try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("Interruption par l'utilisateur.")
