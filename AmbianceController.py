# led_controller.py
from rpi_ws281x import PixelStrip, Color
import time


class LightController:
    def __init__(self, led_count, pin, freq_hz=800000, dma=10, invert=False, brightness=255, channel=0):
        self.strip = PixelStrip(led_count, pin, freq_hz, dma, invert, brightness, channel=channel)
        self.strip.begin()

    def clear_strip(self):
        """Reset all LEDs to complete off state."""
        for i in range(self.strip.numPixels()):
            self.strip.setPixelColor(i, Color(0, 0, 0))
        self.strip.show()
        self.strip.begin()
        self.strip.show()

    def set_zone_color(self, zone, color):
        """Définit une couleur pour une zone spécifique."""
        for i in zone:
            self.strip.setPixelColor(i, color)
        self.strip.show()

    def fill_path_start(self, zone, color, duration=2):
        """Remplit une zone avec une couleur de gauche à droite."""
        steps = len(zone)
        delay = duration / steps

        for i in zone:
            self.strip.setPixelColor(i, color)
            self.strip.show()
            time.sleep(delay)

    def fill_path_end(self, zone, color, duration=2.0):
        """Remplit une zone avec une couleur de droite à gauche."""
        steps = len(zone)
        delay = duration / steps

        for i in reversed(zone):
            self.strip.setPixelColor(i, color)
            self.strip.show()
            time.sleep(delay)

    def blink(self, zone, color, blink_times=3, delay=0.5):
        """Fait clignoter une zone plusieurs fois."""
        for _ in range(blink_times):
            self.set_zone_color(zone, color)
            time.sleep(delay)
            self.set_zone_color(zone, Color(0, 0, 0))
            time.sleep(delay)

    def pulse(self, zone, base_color, pulse_color, duration=2.0):
        """Fait pulser une zone entre deux couleurs."""
        steps = 20
        delay = duration / steps

        for _ in range(steps):
            for i in zone:
                self.strip.setPixelColor(i, pulse_color)
            self.strip.show()
            time.sleep(delay)

            for i in zone:
                self.strip.setPixelColor(i, base_color)
            self.strip.show()
            time.sleep(delay)

    def animate_heartbeat(self, zone, base_color, pulse_color, duration=1.0):
        """Animation de battement de cœur."""
        self.pulse(zone, base_color, pulse_color, duration)

    def animate_flow(self, zone, start_color, end_color, duration=2.0):
        """Animation de flux lumineux."""
        steps = len(zone)
        delay = duration / steps

        for i in zone:
            self.strip.setPixelColor(i, start_color)
            self.strip.show()
            time.sleep(delay)

        for i in zone:
            self.strip.setPixelColor(i, end_color)
            self.strip.show()
            time.sleep(delay)


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
# websocket_handler.py
import websocket
import threading
from typing import Dict, Callable


class WebSocketHandler:
    def __init__(self, url: str, animation_handlers: Dict[str, Callable]):
        """
        Initialize WebSocket handler with animation callbacks

        Args:
            url: WebSocket server URL
            animation_handlers: Dictionary mapping message types to handler functions
        """
        self.url = url
        self.animation_handlers = animation_handlers
        self.ws = None

    def on_message(self, ws, message):
        """Handle incoming WebSocket messages."""
        print(f"Message reçu : {message}")
        try:
            if message in self.animation_handlers:
                self.animation_handlers[message]()
            else:
                print(f"Message non reconnu: {message}")
        except Exception as e:
            print(f"Erreur lors du traitement du message : {e}")
            if ws:
                ws.send(f"Erreur : {str(e)}")

    def on_error(self, ws, error):
        print(f"Erreur : {error}")

    def on_close(self, ws, close_status_code, close_msg):
        print("Connexion fermée")

    def on_open(self, ws):
        print("Connexion ouverte")
        ws.send("Prêt à recevoir des commandes.")

    def start(self):
        """Start WebSocket connection in a separate thread."""
        self.ws = websocket.WebSocketApp(
            self.url,
            on_message=self.on_message,
            on_error=self.on_error,
            on_close=self.on_close,
            on_open=self.on_open
        )

        websocket_thread = threading.Thread(target=self.ws.run_forever)
        websocket_thread.daemon = True
        websocket_thread.start()

    def stop(self):
        """Stop WebSocket connection."""
        if self.ws:
            self.ws.close()

# main.py
def main():
    # Configuration LED
    LED_CONFIG = {
        'LED_COUNT': 1520,  # Ajusté pour correspondre à la plus grande zone
        'LED_PIN1': 18,
        'LED_FREQ_HZ': 800000,
        'LED_DMA': 10,
        'LED_BRIGHTNESS': 255,
        'LED_INVERT': False,
    }

    # Définition des zones et leurs couleurs par défaut
    ZONES = {
        'FEU': {
            'range': range(621, 920),
            'default_color': Color(255, 69, 0),  # Orange
            'effect_color': Color(255, 0, 0)  # Rouge pour les effets
        },
        'EAU': {
            'range': range(1221, 1520),
            'default_color': Color(0, 0, 255),  # Bleu
            'effect_color': Color(0, 255, 255)  # Cyan pour les effets
        },
        'VENT': {
            'range': range(921, 1220),
            'default_color': Color(128, 128, 128),  # Gris
            'effect_color': Color(255, 255, 255)  # Blanc pour les effets
        },
        'ELECTRICITE': {
            'range': range(301, 620),
            'default_color': Color(255, 255, 0),  # Jaune
            'effect_color': Color(200, 200, 0)  # Jaune plus foncé pour les effets
        },
        'CRYSTAL': {
            'range': range(0, 300),
            'default_color': Color(128, 0, 128),  # Violet
            'effect_color': Color(180, 0, 180)  # Violet plus clair pour les effets
        }
    }

    # Initialize LED controller
    controller = LightController(
        LED_CONFIG['LED_COUNT'],
        LED_CONFIG['LED_PIN1'],
        LED_CONFIG['LED_FREQ_HZ'],
        LED_CONFIG['LED_DMA'],
        LED_CONFIG['LED_INVERT'],
        LED_CONFIG['LED_BRIGHTNESS']
    )

    # Définition des animations
    def animate_feu():
        controller.animate_flow(
            ZONES['FEU']['range'],
            ZONES['FEU']['default_color'],
            ZONES['FEU']['effect_color']
        )

    def animate_eau():
        controller.animate_flow(
            ZONES['EAU']['range'],
            ZONES['EAU']['default_color'],
            ZONES['EAU']['effect_color']
        )

    def animate_vent():
        controller.pulse(
            ZONES['VENT']['range'],
            ZONES['VENT']['default_color'],
            ZONES['VENT']['effect_color']
        )

    def animate_electricite():
        controller.blink(
            ZONES['ELECTRICITE']['range'],
            ZONES['ELECTRICITE']['default_color'],
            blink_times=5,
            delay=0.2
        )

    def animate_crystal():
        controller.pulse(
            ZONES['CRYSTAL']['range'],
            ZONES['CRYSTAL']['default_color'],
            ZONES['CRYSTAL']['effect_color'],
            duration=3.0
        )

    # Définition des handlers pour le WebSocket
    animation_handlers = {
        'animate_feu': animate_feu,
        'animate_eau': animate_eau,
        'animate_vent': animate_vent,
        'animate_electricite': animate_electricite,
        'animate_crystal': animate_crystal,
        'set_zone_color_feu': lambda: controller.set_zone_color(
            ZONES['FEU']['range'],
            ZONES['FEU']['default_color']
        ),
        'set_zone_color_eau': lambda: controller.set_zone_color(
            ZONES['EAU']['range'],
            ZONES['EAU']['default_color']
        ),
        'set_zone_color_vent': lambda: controller.set_zone_color(
            ZONES['VENT']['range'],
            ZONES['VENT']['default_color']
        ),
        'set_zone_color_electricite': lambda: controller.set_zone_color(
            ZONES['ELECTRICITE']['range'],
            ZONES['ELECTRICITE']['default_color']
        ),
        'set_zone_color_crystal': lambda: controller.set_zone_color(
            ZONES['CRYSTAL']['range'],
            ZONES['CRYSTAL']['default_color']
        ),
        'clear_all': controller.clear_strip,
        'reset_defaults': lambda: set_all_default_colors(controller, ZONES)
    }

    def set_all_default_colors(controller, zones):
        """Réinitialise toutes les zones à leurs couleurs par défaut"""
        for zone_info in zones.values():
            controller.set_zone_color(
                zone_info['range'],
                zone_info['default_color']
            )

    # Initialize and start WebSocket handler
    ws_handler = WebSocketHandler('ws://192.168.1.14:8080/rpiConnect', animation_handlers)
    ws_handler.start()

    try:
        # Initialisation des couleurs par défaut
        set_all_default_colors(controller, ZONES)

        # Main program loop
        while True:
            time.sleep(1)  # Garde le programme en vie

    except KeyboardInterrupt:
        print("Arrêt du programme.")
        controller.clear_strip()
        ws_handler.stop()
    finally:
        controller.clear_strip()


if __name__ == "__main__":
    main()