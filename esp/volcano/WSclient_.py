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
                current_time = time.time()

                # Vérifier les messages pour chaque WebSocket client
                for ws in self.ws_clients:
                    try:
                        if current_time - last_check_time >= 0.1:
                            # Tentative de réception de message
                            data = ws.socket.recv(1)
                            if data:
                                ws.socket.setblocking(True)
                                message = ws.receive(first_byte=data)
                                ws.socket.setblocking(False)

                                if message:
                                    print(f"Message received from {ws.url}: {message}")

                                    # Vérifier quelle route a reçu le message
                                    if ws == self.route_ws_map.get('message') and message.lower() == "allumer":
                                        print("================")
                                        print(f"Received message: {message} from {ws.url}")
                                        print("================")
                                        self.led.value(1)
                                        time.sleep(5)
                                        self.led.value(0)

                                    # Si la route ping reçoit "ping", envoyer un message pong
                                    if ws == self.route_ws_map.get('ping') and message.lower() == "ping":
                                        print("================")
                                        print(f"Received ping from {ws.url}")
                                        print("================")
                                        # Envoyer un message ping à la route ping
                                        ping_ws = self.route_ws_map.get('ping')
                                        if ping_ws:
                                            ping_message = device_name
                                            if ping_ws.send(ping_message):
                                                print(f"Ping message sent to {ping_ws.url}: {ping_message}")
                                            else:
                                                print(f"Failed to send ping message to {ping_ws.url}")

                    except OSError as e:
                        if e.args[0] != 11:  # EAGAIN error
                            raise
                # Petit délai pour éviter une surcharge CPU
                time.sleep(0.001)

        except KeyboardInterrupt:
            print("User requested stop")
        except Exception as e:
            print(f"Error: {e}")
        finally:
            for ws in self.ws_clients:
                ws.close()
                print(f"WebSocket connection to {ws.url} closed")


# Utilisation
if __name__ == "__main__":
    # Définissez la base de l'URL comme "tornado_esp"
    # serveur_ip = "192.168.10.146"
    # serveur_port = "8080"
    device_name = "volcano_esp2"
    client = WSclient("Cudy-F810", "13022495", device_name)
    client.main()
