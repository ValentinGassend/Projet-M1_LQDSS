import utime
from WSclient import WSclient
from machine import Pin
from neopixel import NeoPixel
import time
from WebSocketClient import WebSocketClient

class ESP32Controller:
    
        # Configuration

    def __init__(self):
        
        self.NUM_LEDS = 300  # Nombre de LEDs dans le bandeau
        self.PIN = 5        # Broche GPIO connectée au bandeau LED
        
        # Définition des zones
        self.ZONE_GROUND = (0, 120)     # Zone "ground" : LEDs 0 à 119
        self.ZONE_TABLE = (120, 300)    # Zone "table" : LEDs 120 à 299
        self.ZONE_GLOBAL = (0, 300)     # Zone "global" : LEDs 0 à 299
        
        self.ZONE_AIR= (250,300)
        self.ZONE_ELEC=(200,250)
        self.ZONE_WATER=(150,200)
        self.ZONE_FIRE=(100,150)
        
        # Initialisation
        self.np = NeoPixel(Pin(self.PIN), self.NUM_LEDS)
        self.ws_client = WSclient("Cudy-F810", "13022495", "crystal_esp1")
       
        
        self.COLORS = {
            "orange": (220, 50, 0),
            "purple": (128, 0, 128),
            "blue_grey": (96, 125, 139),
            "blue": (50, 50, 255),
            "yellow": (220, 210, 0),
            "green": (0, 255, 0),
            "red": (255, 0, 0),
            "pink": (255, 192, 203),
            "cyan": (0, 150, 255),
            "magenta": (255, 0, 255),
            "white": (255, 255, 255),
            "black": (0, 0, 0),
            "teal": (0, 128, 128),
            "gold": (210, 160, 0),
            "lavender": (230, 230, 250),
            "turquoise": (64, 224, 208),
        }
        
    def set_color(self,zone,r, g, b):
        start, end = zone
        for i in range(start, end):
            self.np[i] = (r, g, b)
        self.np.write()

    def clear(self,zone):
        self.set_color(zone, 0, 0, 0)

    
    def wheel(self,pos):
        if pos < 85:
            return (255 - pos * 3, pos * 3, 0)
        elif pos < 170:
            pos -= 85
            return (0, 255 - pos * 3, pos * 3)
        else:
            pos -= 170
            return (pos * 3, 0, 255 - pos * 3)
        
    def pulse_animation(self, zone, r, g, b, pulse_count=3, pulse_speed_ms=2, step=20):
        """
        Anime une zone avec un effet de pulsation (variation d'intensité d'une couleur).
        
        :param zone: Tuple (start, end) définissant la zone (ex: self.ZONE_GROUND).
        :param r: Composante rouge (0-255).
        :param g: Composante verte (0-255).
        :param b: Composante bleue (0-255).
        :param pulse_count: Nombre de cycles de pulsation.
        :param pulse_speed_ms: Délai en millisecondes entre chaque étape de variation.
        :param step: Pas d'incrémentation de l'intensité (plus grand = plus rapide).
        """
        start, end = zone
        for _ in range(pulse_count):
            # Augmente progressivement l'intensité
            for intensity in range(0, 256, step):
                scaled_r = int(r * intensity / 255)
                scaled_g = int(g * intensity / 255)
                scaled_b = int(b * intensity / 255)
                self.set_color(zone, scaled_r, scaled_g, scaled_b)
                utime.sleep_ms(pulse_speed_ms)
            
            # Diminue progressivement l'intensité
            for intensity in range(255, -1, -step):
                scaled_r = int(r * intensity / 255)
                scaled_g = int(g * intensity / 255)
                scaled_b = int(b * intensity / 255)
                self.set_color(zone, scaled_r, scaled_g, scaled_b)
                utime.sleep_ms(pulse_speed_ms)
    
    

    def color_transition_pulse(self, zone, color1, color2, pulse_speed_ms=10, step=5):
        """
        Transitions the LED strip from color1 to color2 with a pulsing effect.
        The animation stops once the strip has fully transitioned to color2.

        :param zone: Tuple (start, end) defining the zone (e.g., self.ZONE_GLOBAL).
        :param color1: Tuple (r, g, b) representing the starting color.
        :param color2: Tuple (r, g, b) representing the ending color.
        :param pulse_speed_ms: Delay in milliseconds between each step of the transition.
        :param step: Step size for the transition (larger = faster transition).
        """
        start, end = zone
        r1, g1, b1 = color1  # Unpack the first color
        r2, g2, b2 = color2  # Unpack the second color

        # Transition from color1 to color2
        for mix in range(0, 256, step):
            # Calculate the mixed color
            mixed_r = int(r1 + (r2 - r1) * mix / 255)
            mixed_g = int(g1 + (g2 - g1) * mix / 255)
            mixed_b = int(b1 + (b2 - b1) * mix / 255)

            # Apply the mixed color with a pulsing effect
            for intensity in range(0, 256, step):
                scaled_r = int(mixed_r * intensity / 255)
                scaled_g = int(mixed_g * intensity / 255)
                scaled_b = int(mixed_b * intensity / 255)
                self.set_color(zone, scaled_r, scaled_g, scaled_b)
                utime.sleep_ms(pulse_speed_ms)

            for intensity in range(255, -1, -step):
                scaled_r = int(mixed_r * intensity / 255)
                scaled_g = int(mixed_g * intensity / 255)
                scaled_b = int(mixed_b * intensity / 255)
                self.set_color(zone, scaled_r, scaled_g, scaled_b)
                utime.sleep_ms(pulse_speed_ms)

        # Final pulse cycle to ensure smooth transition to color2
        for intensity in range(0, 256, step):
            scaled_r = int(r2 * intensity / 255)
            scaled_g = int(g2 * intensity / 255)
            scaled_b = int(b2 * intensity / 255)
            self.set_color(zone, scaled_r, scaled_g, scaled_b)
            utime.sleep_ms(pulse_speed_ms)

        for intensity in range(255, -1, -step):
            scaled_r = int(r2 * intensity / 255)
            scaled_g = int(g2 * intensity / 255)
            scaled_b = int(b2 * intensity / 255)
            self.set_color(zone, scaled_r, scaled_g, scaled_b)
            utime.sleep_ms(pulse_speed_ms)

       
        
    def blink_animation(self, zone, r, g, b, blink_count=5, blink_delay_ms=500):
        """
        Fait clignoter les LEDs d'une zone spécifique.
        
        :param zone: Tuple (start, end) définissant la zone (ex: self.ZONE_GROUND).
        :param r: Composante rouge (0-255).
        :param g: Composante verte (0-255).
        :param b: Composante bleue (0-255).
        :param blink_count: Nombre de clignotements.
        :param blink_delay_ms: Délai en millisecondes entre chaque état (allumé/éteint).
        """
        start, end = zone
        for _ in range(blink_count):
            # Allume les LEDs
            self.set_color(zone, r, g, b)
            utime.sleep_ms(blink_delay_ms)
            
            # Éteint les LEDs
            self.clear(zone)
            utime.sleep_ms(blink_delay_ms)
    
    def fill_animation(self, zone, r, g, b, delay_ms=50, direction="start"):
        """
        Remplit progressivement une zone spécifique du bandeau LED.
        
        :param zone: Tuple (start, end) définissant la zone (ex: self.ZONE_GROUND).
        :param r: Composante rouge (0-255).
        :param g: Composante verte (0-255).
        :param b: Composante bleue (0-255).
        :param delay_ms: Délai en millisecondes entre chaque LED allumée.
        :param direction: Sens de remplissage ("start" ou "end").
        """
        start, end = zone
        if direction == "start":
            led_range = range(start, end)
        elif direction == "end":
            led_range = range(end - 1, start - 1, -1)
        else:
            raise ValueError("Direction must be 'start' or 'end'.")

        for i in led_range:
            self.np[i] = (r, g, b)
            self.np.write()
            utime.sleep_ms(delay_ms)

   
    def send_message(self, msg):
        """Envoie un message au serveur"""
        try:
            ws = self.ws_client.route_ws_map.get("message", None)
            if ws:
                print(f"Sending message: {msg}")
                ws.socket.setblocking(True)  # S'assure que l'envoi est bloquant
                ws.send(msg)
            else:
                print("WebSocket route 'message' not found")
                self.message_queue.append(msg)  # Sauvegarde le message pour réessayer plus tard
        except Exception as e:
            print(f"Error sending message: {e}")
            self.message_queue.append(msg)  # Sauvegarde le message en cas d'erreur
            self.attempt_reconnect()        

    def process_websocket_message(self, message):
        """Traite les messages WebSocket reçus"""
        if "led_crystal#on" in message:
            print("led_on#true")
            self.set_color(self.ZONE_GLOBAL, 150, 150, 150)
            self.send_message("ambianceManager=>[ambianceManager]=>led_on_crystal#true")
        elif "led_crystal#off" in message:
            print("led_off#true")
            self.set_color(self.ZONE_GLOBAL, 0, 0, 0)
            self.send_message("ambianceManager=>[ambianceManager]=>led_off_crystal#true")
        elif message == "crystal#tornado":
            print("Démarrage de l'animation 'crystal_to_tornado'")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_tornado#start")
            self.blink_animation(self.ZONE_AIR, *self.COLORS["blue_grey"], 15, 100)
            self.fill_animation(self.ZONE_AIR, *self.COLORS["blue_grey"], delay_ms=5, direction="end")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_tornado#end")
        elif message == "crystal#maze":
            print("Démarrage de l'animation 'crystal_maze'")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_volcano#maze")
            self.blink_animation(self.ZONE_ELEC, *self.COLORS["gold"], 15, 100)
            self.fill_animation(self.ZONE_ELEC, *self.COLORS["yellow"], delay_ms=5, direction="end")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_volcano#maze")
        elif message == "crystal#typhoon":
            print("Démarrage de l'animation 'crystal_typhoon'")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_typhoon#start")
            self.blink_animation(self.ZONE_WATER, *self.COLORS["blue"], 15, 100)
            self.fill_animation(self.ZONE_WATER, *self.COLORS["blue"], delay_ms=5, direction="end")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_typhoon#end")
        elif message == "crystal#volcano":
            print("Démarrage de l'animation 'crystal_volcano'")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_volcano#start")
            self.blink_animation(self.ZONE_FIRE, *self.COLORS["orange"], 15, 100)
            self.fill_animation(self.ZONE_FIRE, *self.COLORS["red"], delay_ms=5, direction="end")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_volcano#end")
        elif message == "crystal#finished":
            print("Démarrage de l'animation 'crystal_finished'")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_finish#start")
            self.blink_animation(self.ZONE_FIRE, *self.COLORS["orange"], 15, 100)
            self.blink_animation(self.ZONE_WATER, *self.COLORS["blue"], 15, 100)
            self.blink_animation(self.ZONE_AIR, *self.COLORS["blue_grey"], 15, 100)
            self.blink_animation(self.ZONE_ELEC, *self.COLORS["gold"], 15, 100)
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_finish#end")
        else:
            print("message inconnu :", message)

# #VENT ANIMATION 
# #stelle_to_tornado#true 
# controller.fill_animation(controller.ZONE_GLOBAL, *controller.COLORS["purple"], delay_ms=1, direction="start")
# utime.sleep(0.1)
# controller.pulse_animation(controller.ZONE_TABLE, *controller.COLORS["purple"])
# 
# #rfid#tornado
# controller.pulse_animation(controller.ZONE_TABLE, *controller.COLORS["blue_grey"])
# controller.set_color(controller.ZONE_TABLE, *controller.COLORS["blue_grey"])
# 
# #tornado_finished#true
# controller.blink_animation(controller.ZONE_TABLE, *controller.COLORS["blue_grey"])
# controller.set_color(controller.ZONE_TABLE, *controller.COLORS["blue_grey"])
# 
# #tornado_to_stelle#true
# controller.fill_animation(controller.ZONE_GROUND, *controller.COLORS["blue_grey"], delay_ms=1, direction="end")
# controller.set_color(controller.ZONE_TABLE, 0,0,0)
# controller.fill_animation(controller.ZONE_GROUND, 0,0,0, delay_ms=1, direction="end")


    def handle_websocket_messages(self):
            for ws_route, ws in self.ws_client.route_ws_map.items():
                try:
                    ws.socket.setblocking(False)
                    data = ws.socket.recv(1)
                    ws.socket.setblocking(True)
                    if data:
                        message = ws.receive(first_byte=data)
                        if message:
                            print(f"Message received on route {ws_route}: {message}")
                            self.process_websocket_message(message)

                            if "ping" in message.lower():
                                self.ws_client.process_message(ws, message)

                except OSError as e:
                    if e.args[0] != 11:
                        print(f"Error on WebSocket route {ws_route}: {e}")
                        self.handle_websocket_error(ws_route, e)

    def attempt_reconnect(self):
        """Attempt to reconnect WebSocket connections"""
        current_time = utime.ticks_ms()
        if utime.ticks_diff(current_time, self.last_reconnect_attempt) > self.reconnect_interval:
            print("Attempting to reconnect WebSocket...")
            self.last_reconnect_attempt = current_time

            if self.ws_client.connect_wifi():
                print("WiFi reconnected successfully")
                self.ws_client.connect_websockets()
                print("WebSocket reconnection attempt completed")
            else:
                print("WiFi reconnection failed")

    def handle_websocket_error(self, ws_route, error):
        """Handle WebSocket errors appropriately"""
        if error.args[0] == 128:  # ENOTCONN
            print(f"Connection lost on route {ws_route}, attempting reconnection...")
            self.attempt_reconnect()
        else:
            print(f"Error on WebSocket route {ws_route}: {error}")
    def start(self):
            print("Démarrage du contrôleur...")

            if not self.ws_client.connect_wifi():
                print("Connexion WiFi échouée. Arrêt.")
                return

            self.ws_client.connect_websockets()

            while True:
               
                try:
                    self.handle_websocket_messages()
                 
                    utime.sleep_ms(100)

                except Exception as e	:
                    print(f"Erreur générale: {e}")
                    utime.sleep(5)
                    self.init()
                    self.start()




controller = ESP32Controller()
# Démarrage du contrôleur
controller.start()
#controller.pulse_animation(controller.ZONE_TABLE, *controller.COLORS["purple"])
# Animation de pulsation avec transition entre rouge et bleu
# controller.color_transition_pulse(
#     zone=controller.ZONE_GLOBAL,
#     color1=controller.COLORS["purple"],  # Starting color
#     color2=controller.COLORS["blue"],    # Ending color
#     pulse_speed_ms=3,                   # Speed of the pulse
#     step=55                               # Step size for transition
# )
# 
# controller.set_color(controller.ZONE_TABLE, *controller.COLORS["blue"])


# #VENT ANIMATION 
# #stelle_to_tornado#true 
# controller.fill_animation(controller.ZONE_GLOBAL, *controller.COLORS["purple"], delay_ms=1, direction="start")
# utime.sleep(0.1)
# controller.pulse_animation(controller.ZONE_TABLE, *controller.COLORS["purple"])
# 
# #rfid#tornado
# controller.pulse_animation(controller.ZONE_TABLE, *controller.COLORS["blue_grey"])
# controller.set_color(controller.ZONE_TABLE, *controller.COLORS["blue_grey"])
# 
# #tornado_finished#true
# controller.blink_animation(controller.ZONE_TABLE, *controller.COLORS["blue_grey"])
# controller.set_color(controller.ZONE_TABLE, *controller.COLORS["blue_grey"])
# 
# #tornado_to_stelle#true
# controller.fill_animation(controller.ZONE_GROUND, *controller.COLORS["blue_grey"], delay_ms=1, direction="end")
# controller.set_color(controller.ZONE_TABLE, 0,0,0)
# controller.fill_animation(controller.ZONE_GROUND, 0,0,0, delay_ms=1, direction="end")



# 
# #ELEC ANIMATION 
# #stelle_to_maze#true 
# controller.fill_animation(controller.ZONE_GLOBAL, *controller.COLORS["purple"], delay_ms=1, direction="start")
# utime.sleep(0.1)
# controller.pulse_animation(controller.ZONE_TABLE, *controller.COLORS["purple"])
# controller.set_color((120,140), *controller.COLORS["teal"])
# utime.sleep(2)
# #rfid#maze
# controller.pulse_animation(controller.ZONE_TABLE, *controller.COLORS["gold"])
# controller.set_color(controller.ZONE_TABLE, *controller.COLORS["gold"])
# 
# #maze_finished#true
# controller.blink_animation(controller.ZONE_TABLE, *controller.COLORS["gold"])
# controller.set_color(controller.ZONE_TABLE, *controller.COLORS["gold"])
# 
# #maze_to_stelle#true
# controller.fill_animation(controller.ZONE_GROUND, *controller.COLORS["gold"], delay_ms=1, direction="end")
# controller.set_color(controller.ZONE_TABLE, 0,0,0)
# controller.fill_animation(controller.ZONE_GROUND, 0,0,0, delay_ms=1, direction="end")
# 


# #EAU ANIMATION 
# #stelle_to_typhoon#true 
# controller.fill_animation(controller.ZONE_GLOBAL, *controller.COLORS["purple"], delay_ms=1, direction="start")
# utime.sleep(0.1)
# controller.pulse_animation(controller.ZONE_TABLE, *controller.COLORS["purple"])
# 
# #rfid#typhoon
# controller.pulse_animation(controller.ZONE_TABLE, *controller.COLORS["cyan"])
# controller.set_color(controller.ZONE_TABLE, *controller.COLORS["cyan"])
# 
# #typhoon_finished#true
# controller.blink_animation(controller.ZONE_TABLE, *controller.COLORS["cyan"])
# controller.set_color(controller.ZONE_TABLE, *controller.COLORS["cyan"])
# 
# #typhoon_to_stelle#true
# controller.fill_animation(controller.ZONE_GROUND, *controller.COLORS["cyan"], delay_ms=1, direction="end")
# controller.set_color(controller.ZONE_TABLE, 0,0,0)
# controller.fill_animation(controller.ZONE_GROUND, 0,0,0, delay_ms=1, direction="end")
# 
# 
# 
# 
# #FEU ANIMATION 
# #stelle_to_volcano#true 
# controller.fill_animation(controller.ZONE_GLOBAL, *controller.COLORS["purple"], delay_ms=1, direction="start")
# utime.sleep(0.1)
# controller.pulse_animation(controller.ZONE_TABLE, *controller.COLORS["purple"])
# 
# #rfid#volcano
# controller.pulse_animation(controller.ZONE_TABLE, *controller.COLORS["orange"])
# controller.set_color(controller.ZONE_TABLE, *controller.COLORS["orange"])
# #volcano_finished#true
# 
# controller.blink_animation(controller.ZONE_TABLE, *controller.COLORS["orange"])
# controller.set_color(controller.ZONE_TABLE, *controller.COLORS["orange"])
# 
# #volcano_to_stelle#true
# controller.fill_animation(controller.ZONE_GROUND, *controller.COLORS["orange"], delay_ms=1, direction="end")
# controller.set_color(controller.ZONE_TABLE, 0,0,0)
# controller.fill_animation(controller.ZONE_GROUND, 0,0,0, delay_ms=1, direction="end")





#controller.blink_animation(controller.ZONE_TABLE, *controller.COLORS["orange"], 3, 250)

