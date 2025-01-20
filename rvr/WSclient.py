# import websocket
# import subprocess
# import os 
# import time
# import threading

# DetectedObject = False
# turn_right_process = None  # Global variable to track the turn-right process


# def on_message(ws, message):
#     global turn_right_process  # Access the global variable

#     print("Message reçu:", message)

#     if message.startswith("start"):
#         # Extraire la vitesse
#         try:
#             speed = int(message.split()[1])
#             if 0 <= speed <= 255:
#                 # Lancer le script 'turn-right.py' et enregistrer le processus
#                 if turn_right_process is not None:
#                     print("Un processus 'turn-right.py' est déjà en cours. Arrêt en cours...")
#                     turn_right_process.terminate()
#                     turn_right_process = None
                
#                 turn_right_process = subprocess.Popen(
#                     ['python3', 'turn-right.py', str(speed)],
#                     stdout=subprocess.PIPE,
#                     stderr=subprocess.PIPE,
#                     text=True
#                 )
#                 print(f"'turn-right.py' lancé avec la vitesse {speed}.")
#             else:
#                 print("Erreur: La vitesse doit être entre 0 et 255.")
#         except (ValueError, IndexError):
#             print("Erreur: Commande invalide. Utilisez 'start <vitesse>'.")

#     elif message == "stop":
#         # Arrêter le script 'turn-right.py' s'il est en cours
#         if turn_right_process is not None:
#             print("Arrêt du processus 'turn-right.py'.")
#             turn_right_process.terminate()
#             turn_right_process = None
#         else:
#             print("Aucun processus 'turn-right.py' n'est en cours.")

#         # Lancer le script 'stop.py'
#         threading.Thread(target=run_stop_script).start()

#     else:
#         print("Commande inconnue. Utilisez 'start <vitesse>' ou 'stop'.")


# def run_stop_script():
#     try:
#         result = subprocess.run(['python3', 'stop.py'], capture_output=True, text=True)
#         if result.returncode == 0:
#             print(f"Script 'stop.py' exécuté avec succès : {result.stdout}")
#         else:
#             print(f"Erreur lors de l'exécution de 'stop.py' : {result.stderr}")
#     except Exception as e:
#         print(f"Erreur lors de l'exécution du script 'stop.py': {e}")


# def on_error(ws, error):
#     print("Erreur:", error)


# def on_close(ws, close_status_code, close_msg):
#     print("Connexion fermée")


# def on_open(ws):
#     print("Connexion ouverte")
#     ws.send("Bonjour, serveur !")


# def run_websocket(ws):
#     """Exécute une instance WebSocket."""
#     ws.run_forever()


# # WebSocket pour la connexion principale
# ws = websocket.WebSocketApp(
#     "ws://192.168.10.146:8080/tornado_rpiConnect",
#     on_open=on_open,
#     on_message=on_message,
#     on_error=on_error,
#     on_close=on_close
# )

# # Créer un thread pour exécuter le WebSocket
# thread_connect = threading.Thread(target=run_websocket, args=(ws,))
# thread_connect.daemon = True
# thread_connect.start()

# try:
#     while True:
#         time.sleep(1)
# except KeyboardInterrupt:
#     print("Interruption par l'utilisateur.")
#     # Terminer le processus en cours si nécessaire
#     if turn_right_process is not None:
#         turn_right_process.terminate()
#         print("Processus 'turn-right.py' arrêté.")

import os
import websocket
import threading
import time
import subprocess
import random


class WSClient:
    def __init__(self, device_name, server_ip="192.168.10.146", server_port="8080"):
        self.BASE_URL = f"ws://{server_ip}:{server_port}/{device_name}"
        self.ws_clients = []
        self.route_ws_map = {}
        self.mic_states = {
            "mic1": False,
            "mic2": False,
            "mic3": False,
            "mic4": False
        }
        self.speeds = [100, 150, 200, 250]
        self.current_speed = 0
        self.movement_process = None
        self.reconnect_attempts = {}  # Pour suivre les tentatives de reconnexion
        self.running = True  # Pour contrôler l'état global
        # Obtenir le chemin du dossier du script courant
        self.current_dir = os.path.dirname(os.path.abspath(__file__))
        
    def connect_websockets(self):
        websocket_urls = [
            f"{self.BASE_URL}Connect",
            f"{self.BASE_URL}Message",
            f"{self.BASE_URL}Ping"
        ]

        for url in websocket_urls:
            self.connect_single_websocket(url)

    def connect_single_websocket(self, url):
        ws = websocket.WebSocketApp(
            url,
            on_open=self.on_open,
            on_message=self.on_message,
            on_error=self.on_error,
            on_close=self.on_close
        )
        
        # Stocker le websocket seulement s'il n'existe pas déjà
        if ws not in self.ws_clients:
            self.ws_clients.append(ws)

        # Mettre à jour la map des routes
        if "Connect" in url:
            self.route_ws_map['connect'] = ws
        elif "Message" in url:
            self.route_ws_map['message'] = ws
        elif "Ping" in url:
            self.route_ws_map['ping'] = ws

        return ws

    def reconnect(self, ws):
        url = ws.url
        if url not in self.reconnect_attempts:
            self.reconnect_attempts[url] = 0

        # Temps d'attente exponentiel avec un peu de random pour éviter la synchronisation
        wait_time = min(300, (2 ** self.reconnect_attempts[url]) + (random.randint(0, 1000) / 1000))
        self.reconnect_attempts[url] += 1
        
        print(f"Tentative de reconnexion à {url} dans {wait_time:.2f} secondes...")
        time.sleep(wait_time)
        
        if self.running:  # Vérifier si le client est toujours en cours d'exécution
            new_ws = self.connect_single_websocket(url)
            # Démarrer un nouveau thread pour ce websocket
            thread = threading.Thread(target=self.run_websocket, args=(new_ws,))
            thread.daemon = True
            thread.start()

    def on_close(self, ws, close_status_code, close_msg):
        print(f"Connection closed: {close_status_code} - {close_msg}")
        if self.running:  # Seulement si le client est toujours en cours d'exécution
            print("Tentative de reconnexion...")
            reconnect_thread = threading.Thread(target=self.reconnect, args=(ws,))
            reconnect_thread.daemon = True
            reconnect_thread.start()

    def on_open(self, ws):
        print(f"Connection opened: {ws.url}")
        # Réinitialiser le compteur de tentatives lors d'une connexion réussie
        self.reconnect_attempts[ws.url] = 0
        if "Connect" in ws.url:
            ws.send("Hello from device!")

    # Les autres méthodes restent identiques
    def update_speed(self):
        """Met à jour la vitesse en fonction des états des microphones"""
        activated_mics = sum(self.mic_states.values())
        
        if activated_mics > self.current_speed:
            self.current_speed = activated_mics
            if self.current_speed > 0:
                self.start_movement(self.speeds[self.current_speed - 1])
        elif activated_mics < self.current_speed:
            self.current_speed = activated_mics
            if self.current_speed > 0:
                self.start_movement(self.speeds[self.current_speed - 1])
            else:
                self.stop_movement()

    def stop_movement(self):
        if self.movement_process is not None:
            self.movement_process.terminate()
            self.movement_process = None
            
        print("Stopping movement")
        try:
            subprocess.run(['python3', os.path.join(self.current_dir, 'stop.py')], capture_output=True, text=True)
        except Exception as e:
            print(f"Error stopping movement: {e}")

    def on_message(self, ws, message):
        if ws == self.route_ws_map.get('ping'):
            if message == "ping":
                ws.send("pong")
        elif ws == self.route_ws_map.get('connect'):
            print(f"Connect message: {message}")
            ws.send("Hello from device")
        elif ws == self.route_ws_map.get('message'):
            print(f"Message received: {message}")
            self.process_message(message)

    def process_message(self, message):
        try:
            if message == "all_mics_active#true":
                print("All mics active signal received - stopping movement")
                self.stop_movement()
                return
            if "#" in message:
                component, state = message.split("#")
                state = state.lower() == "true"
                
                if component in self.mic_states:
                    self.mic_states[component] = state
                    print(f"Updated {component} state to {state}")
                    print(f"Current mic states: {self.mic_states}")
                    self.update_speed()
        except Exception as e:
            print(f"Error processing message: {e}")

    def on_error(self, ws, error):
        print(f"Error: {error}")

    def run_websocket(self, ws):
        ws.run_forever()

    def start_movement(self, speed):
        if self.movement_process is not None:
            self.movement_process.terminate()
            
        print(f"Starting movement at speed: {speed}")
        self.movement_process = subprocess.Popen(
            ['python3', os.path.join(self.current_dir, 'turn-right.py'), str(speed)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

    def start(self):
        self.running = True
        self.connect_websockets()
        
        for ws in self.ws_clients:
            thread = threading.Thread(target=self.run_websocket, args=(ws,))
            thread.daemon = True
            thread.start()

        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("Arrêt demandé par l'utilisateur.")
            self.running = False  # Arrêter les tentatives de reconnexion
            for ws in self.ws_clients:
                ws.close()

if __name__ == "__main__":
    client = WSClient("tornado_rpi")
    client.start()