import time
from rpi_ws281x import PixelStrip, Color
import websocket
import threading

# Configuration des bandeaux LED
LED_COUNT = 1500        # Total de LEDs (4 éléments x 60 LEDs)
LED_PIN1 = 18           # GPIO pin connected to the pixels (must support PWM!)
LED_PIN2 = 13           # Second GPIO pin for the second strip
LED_PIN3 = 12           # Third GPIO pin for the third strip
LED_FREQ_HZ = 800000    # LED signal frequency in hertz (usually 800khz)
LED_DMA = 10            # DMA channel to use for generating signal (try 10)
LED_BRIGHTNESS = 255    # Set to 0 for darkest and 255 for brightest
LED_INVERT = False      # True to invert the signal (when using NPN transistor level shift)
LED_CHANNEL = 1
# Initialize strips
print(f"Initializing strip1 on GPIO {LED_PIN1}...")
strip1 = PixelStrip(LED_COUNT, LED_PIN1, LED_FREQ_HZ, LED_DMA, LED_INVERT, LED_BRIGHTNESS, channel=0)

# Définir les zones pour chaque élément
ZONE_FEU = range(0, 2000)          # LEDs 0 à 59
ZONE_EAU = range(0, 300)        # LEDs 60 à 119
ZONE_VENT = range(0, 300)      # LEDs 120 à 179
ZONE_ELECTRICITE = range(0, 200)  # LEDs 180 à 239
ZONE_BANDEAU1 = range(0,1600)
ZONE_BANDEAU2 = range(300,600)
ZONE_BANDEAU3 = range(600,900)
ZONE_BANDEAU4 = range(900,1200)
ZONE_BANDEAU5 = range(1200,1500)
# WebSocket server URL
WEBSOCKET_URL = "ws://192.168.1.14:8080/rpiConnect"

class LightController:
    def __init__(self, strip, ws=None):
        self.ws = ws
        self.strip = strip
        if self.strip is None:
            raise ValueError("Strip object is None!")
    def clear_strip(self):
        """Reset all LEDs to complete off state."""
        # Set each LED to 0 for RGB
        for i in range(LED_COUNT):
            self.strip.setPixelColor(i, Color(0, 0, 0))
        self.strip.show()
        
        # Force hardware reset
        self.strip.begin()
        
        # Ensure changes are written
        self.strip.show()
    def set_zone_color(self, zone, color):
        """
        Définit une couleur pour une zone spécifique.
        """
        for i in zone:
            self.strip.setPixelColor(i, color)
        self.strip.show()
        
    def fill_path_start(self, zone, color, duration=2):
        """
        Remplit une zone avec une couleur dans une direction (gauche à droite).
        :param duration: Durée totale de l'animation.
        """
        steps = len(zone)
        delay = duration / steps
        
        for i in zone:
            self.strip.setPixelColor(i, color)
            self.strip.show()  # Update the strip after each LED
            time.sleep(delay)

    def fill_path_end(self, zone, color, duration=2.0):
        """
        Remplit une zone avec une couleur dans la direction opposée (droite à gauche).
        :param duration: Durée totale de l'animation.
        """
        steps = len(zone)
        delay = duration / steps

        for i in reversed(zone):
            self.strip.setPixelColor(i, color)
            self.strip.show()
            time.sleep(delay)  

    def blink(self, zone, color, blink_times=3, delay=0.5):
        """
        Fait clignoter une zone plusieurs fois.
        :param blink_times: Nombre de clignotements.
        :param delay: Délai entre chaque clignotement.
        """
        for _ in range(blink_times):
            self.set_zone_color(zone, color)
            time.sleep(delay)
            self.set_zone_color(zone, Color(0, 0, 0))
            time.sleep(delay)
    
    def pulse(self, zone, base_color, pulse_color, duration=2.0):
        """
        Fait pulser une zone entre deux couleurs.
        """
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
        """
        Animation de battement de cœur pour une zone.
        """
        self.pulse(zone, base_color, pulse_color, duration)

    def animate_flow(self, zone, start_color, end_color, duration=2.0):
        """
        Animation de flux lumineux pour une zone.
        """
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

   """exemple anim avec envoie de message """
    def animate_electricity(self, zone):
        """
        Animation d'électricité pour une zone.
        :param zone: Plage de LEDs.
        """
        if self.ws:
            self.ws.send("electricity_animation_started")
        for i in zone:
            self.strip.setPixelColor(i, Color(255, 255, 0))  # Jaune
        self.strip.show()
        time.sleep(0.5)
        if self.ws:
            self.ws.send("electricity_animation_ended")


def test_strips(controllers, test_zones):
    """
    Test multiple LED strips automatically
    
    Args:
        controllers: List of LightController objects
        test_zones: List of zones corresponding to each controller
    """
    print("Testing strip control...")
    
    # Clear all strips
    for controller in controllers:
        controller.clear_strip()
    time.sleep(1)
    
    # Test each strip
    for i, (controller, zone) in enumerate(zip(controllers, test_zones)):
        print(f"Testing strip {i+1}...")
        controller.set_zone_color(zone, Color(255 if i == 0 else 0, 0, 255 if i == 1 else 0))
        time.sleep(2)
        controller.clear_strip()
    
    print("Strip test complete")

# WebSocket event handlers
def on_message(ws, message):
    """
    Callback when a message is received from the WebSocket server.
    """
    print(f"Message reçu : {message}")
    try:
        if message == "animate_volcano":
            light_controller1.animate_volcano(ZONE_FEU)
        elif message == "animate_water":
            light_controller1.animate_water(ZONE_EAU)   
        elif message == "animate_wind":
            light_controller1.animate_wind(ZONE_VENT)
        elif message == "animate_electricity":
            light_controller1.animate_electricity(ZONE_ELECTRICITE)
        elif message == "set_zone_color_feu":
            light_controller1.set_zone_color(ZONE_FEU, Color(255, 69, 0))  # Orange
        elif message == "set_zone_color_eau":
            light_controller2.c(ZONE_EAU, Color(0, 0, 255))  # Bleu
        elif message == "set_zone_color_vent":
            light_controller1.set_zone_color(ZONE_VENT, Color(128, 128, 128))  # Gris
        elif message == "set_zone_color_electricite":
            light_controller2.set_zone_color(ZONE_ELECTRICITE, Color(255, 255, 0))  # Jaune
        elif message == "clear_strip":
            light_controller1.clear_strip()

    except Exception as e:
        print(f"Erreur lors du traitement du message : {e}")
        if ws:
            ws.send(f"Erreur : {str(e)}")

def on_error(ws, error):
    """
    Callback when an error occurs.
    """
    print(f"Erreur : {error}")

def on_close(ws, close_status_code, close_msg):
    """
    Callback when the WebSocket connection is closed.
    """
    print("Connexion fermée")

def on_open(ws):
    """
    Callback when the WebSocket connection is opened.
    """
    print("Connexion ouverte")
    ws.send("Prêt à recevoir des commandes.")

# Create WebSocket connection
ws = websocket.WebSocketApp(
    WEBSOCKET_URL,
    on_message=on_message,
    on_error=on_error,
    on_close=on_close,
    on_open=on_open
)

# Initialize LightController with WebSocket
light_controller1 = LightController(strip1, ws)
# light_controller2 = LightController(strip2, ws)
# light_controller3 = LightController(strip3, ws)

# Run WebSocket in a separate thread
def run_websocket():
    ws.run_forever()

websocket_thread = threading.Thread(target=run_websocket)
websocket_thread.daemon = True
websocket_thread.start()

# Main loop
try:
    light_controller1.set_zone_color(ZONE_BANDEAU1, Color(128, 128, 0))
    time.sleep(1)
  
    # # Keep the script running
    while True:
        time.sleep(1)
        light_controller1.set_zone_color(ZONE_BANDEAU1, Color(128, 128, 0))
      
except KeyboardInterrupt:
    print("Arrêt du programme.")
    light_controller1.clear_strip()
finally:
    light_controller1.clear_strip()