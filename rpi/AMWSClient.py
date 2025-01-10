import websocket
import threading
import time
from AmbianceController import LightController


class AMWSClient:
    def __init__(self, base_url):
        self.base_url = base_url
        self.connect_ws = None
        self.message_ws = None
        self.ping_ws = None
        self.connect_thread = None
        self.message_thread = None
        self.ping_thread = None
        self.light_controller = None
        self.is_running = True

    def on_connect_message(self, ws, message):
        print(f"[Connect] Message reçu : {message}")
        # Initialiser le contrôleur de lumière si nécessaire
        if message == "Hello from ambiance_managerConnect!":
            self.initialize_light_controller()

    def on_message_message(self, ws, message):
        print(f"[Message] Message reçu : {message}")
        if '#' in message:
            component, data = message.split('#')
            self.handle_light_command(component, data)

    def on_ping_message(self, ws, message):
        if message == "ping":
            ws.send("pong")

    def on_error(self, ws, error):
        print(f"Erreur : {error}")

    def on_close(self, ws, close_status_code, close_msg):
        print(f"Connexion fermée")
        if not self.is_running:
            return

        # Tentative de reconnexion après 5 secondes
        print("Tentative de reconnexion dans 5 secondes...")
        threading.Timer(5.0, self.reconnect).start()

    def on_open(self, ws):
        print(f"Connexion ouverte")
        ws.send("Bonjour, serveur !")

    def initialize_light_controller(self):
        """Initialise le contrôleur LED avec la configuration par défaut"""
        LED_CONFIG = {
            'LED_COUNT': 1520,
            'LED_PIN': 18,
            'LED_FREQ_HZ': 800000,
            'LED_DMA': 10,
            'LED_BRIGHTNESS': 255,
            'LED_INVERT': False,
        }

        self.light_controller = LightController(
            LED_CONFIG['LED_COUNT'],
            LED_CONFIG['LED_PIN'],
            LED_CONFIG['LED_FREQ_HZ'],
            LED_CONFIG['LED_DMA'],
            LED_CONFIG['LED_INVERT'],
            LED_CONFIG['LED_BRIGHTNESS']
        )

    def handle_light_command(self, component, data):
        """Gère les commandes reçues pour le contrôle des lumières"""
        if not self.light_controller:
            print("Light controller non initialisé")
            return

        try:
            if component == "animate":
                # Exemple de commande: animate_feu, animate_eau, etc.
                animation_method = getattr(self.light_controller, data, None)
                if animation_method:
                    animation_method()
            elif component == "set_color":
                # Format attendu: zone,color (ex: "FEU,255,69,0")
                zone_name, *color_values = data.split(',')
                if hasattr(self.light_controller, f"set_zone_color_{zone_name.lower()}"):
                    method = getattr(self.light_controller, f"set_zone_color_{zone_name.lower()}")
                    method(*map(int, color_values))
            elif component == "clear":
                self.light_controller.clear_strip()
        except Exception as e:
            print(f"Erreur lors du traitement de la commande: {e}")

    def connect(self):
        """Établit les trois connexions WebSocket"""
        # Connection WebSocket
        self.connect_ws = websocket.WebSocketApp(
            f"{self.base_url}/ambiance_managerConnect",
            on_open=self.on_open,
            on_message=self.on_connect_message,
            on_error=self.on_error,
            on_close=self.on_close
        )

        # Message WebSocket
        self.message_ws = websocket.WebSocketApp(
            f"{self.base_url}/ambiance_managerMessage",
            on_open=self.on_open,
            on_message=self.on_message_message,
            on_error=self.on_error,
            on_close=self.on_close
        )

        # Ping WebSocket
        self.ping_ws = websocket.WebSocketApp(
            f"{self.base_url}/ambiance_managerPing",
            on_open=self.on_open,
            on_message=self.on_ping_message,
            on_error=self.on_error,
            on_close=self.on_close
        )

    def start(self):
        """Démarre les connexions WebSocket dans des threads séparés"""
        self.connect()

        self.connect_thread = threading.Thread(target=self.connect_ws.run_forever)
        self.message_thread = threading.Thread(target=self.message_ws.run_forever)
        self.ping_thread = threading.Thread(target=self.ping_ws.run_forever)

        self.connect_thread.daemon = True
        self.message_thread.daemon = True
        self.ping_thread.daemon = True

        self.connect_thread.start()
        self.message_thread.start()
        self.ping_thread.start()

    def reconnect(self):
        """Tente de rétablir les connexions"""
        if self.is_running:
            print("Tentative de reconnexion...")
            self.connect()
            self.start()

    def stop(self):
        """Arrête proprement les connexions WebSocket"""
        self.is_running = False
        if self.connect_ws:
            self.connect_ws.close()
        if self.message_ws:
            self.message_ws.close()
        if self.ping_ws:
            self.ping_ws.close()


# Programme principal
def main():
    # URL du serveur WebSocket
    server_url = "ws://192.168.10.146:8080"

    # Création et démarrage du client
    client = AMWSClient(server_url)
    client.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Arrêt du programme")
        client.stop()


if __name__ == "__main__":
    main()