import network
import time
import gc
from machine import Pin
from libs.WebSocketClient import WebSocketClient


class WSclient:
    def __init__(self, ssid, password, device_name, server_ip="192.168.10.146", server_port="8080"):
        self.WIFI_SSID = ssid
        self.WIFI_PASSWORD = password
        self.BASE_URL = server_ip + ":" + server_port + "/" +  device_name  # La base de l'URL (par exemple, "tornado_esp")
        self.led = Pin(19, Pin.OUT)
        self.wlan = None
        self.ws_clients = []  # Liste des clients WebSocket
        # Dictionary to map routes to their WebSocket clients
        self.route_ws_map = {}

    def connect_wifi(self):
        self.wlan = network.WLAN(network.STA_IF)
        self.wlan.active(True)
        print(f'Connecting to network {self.WIFI_SSID}...')

        if not self.wlan.isconnected():
            self.wlan.connect(self.WIFI_SSID, self.WIFI_PASSWORD)
            max_wait = 10
            while max_wait > 0:
                if self.wlan.isconnected():
                    break
                max_wait -= 1
                print('Waiting for connection...')
                time.sleep(1)

        if self.wlan.isconnected():
            print('WiFi connection successful!')
            print('IP Address:', self.wlan.ifconfig()[0])
            return True
        else:
            print('WiFi connection failed')
            return False

    def connect_websockets(self):
        # Génération automatique des 3 URLs à partir de la base URL
        websocket_urls = [
            f"ws://{self.BASE_URL}Connect",
            f"ws://{self.BASE_URL}Message",
            f"ws://{self.BASE_URL}Ping"
        ]

        # Création d'une instance WebSocketClient pour chaque URL
        for url in websocket_urls:
            ws = WebSocketClient(url)
            if ws.connect():
                print(f"Connected to WebSocket server: {url}")
                self.ws_clients.append(ws)

                # Déterminer la route à partir de l'URL et la mapper
                if "Connect" in url:
                    self.route_ws_map['connect'] = ws
                elif "Message" in url:
                    self.route_ws_map['message'] = ws
                elif "Ping" in url:
                    self.route_ws_map['ping'] = ws
            else:
                print(f"Failed to connect to WebSocket server: {url}")

    def process_message(self, ws, message):
        """Traiter les messages en fonction de leur route"""
        if ws == self.route_ws_map.get('message') and message.lower() == "allumer":
            print("================")
            print(f"Received message: {message} from {ws.url}")
            print("================")

        if ws == self.route_ws_map.get('connect'):
            print("================")
            print(f"Received message: {message} from {ws.url}")
            print("================")
            ws.send('hey')

        if ws == self.route_ws_map.get('ping') and message.lower() == "ping":
            print("================")
            print(f"Received ping from {ws.url}")
            print("================")
            ping_ws = self.route_ws_map.get('ping')
            if ping_ws:
                ws.send("pong")

    def main(self):
        gc.collect()

        if not self.connect_wifi():
            print("Cannot continue without WiFi connection")
            return

        self.connect_websockets()
        last_message_time = time.time()
        last_check_time = time.time()

        try:
            while True:
                # Lire les messages sur toutes les routes
                for ws in self.ws_clients:
                    try:
                        # Utilisation de `ws.socket.setblocking(False)` pour ne pas bloquer
                        ws.socket.setblocking(False)
                        data = ws.socket.recv(1)  # Récupérer jusqu'à 1024 octets
                        if data:
                            ws.socket.setblocking(True)
                            message = ws.receive(first_byte=data)
                            ws.socket.setblocking(False)
                            if message:
                                print(f"Message received from {ws.url}: {message}")
                                self.process_message(ws, message)
                    except OSError as e:
                        if e.args[0] != 11:  # Erreur EAGAIN
                            print(f"Error on WebSocket {ws.url}: {e}")
                            ws.close()
                            self.ws_clients.remove(ws)
                            continue

                # Délai pour limiter l'utilisation du CPU
                time.sleep(0.001)


        except KeyboardInterrupt:
            print("User requested stop")
        except Exception as e:
            print(f"Error: {e}")
        finally:
            for ws in self.ws_clients:
                ws.close()
                print(f"WebSocket connection to {ws.url} closed")



