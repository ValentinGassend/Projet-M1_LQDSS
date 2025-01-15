import _thread
import utime
from WSclient import WSclient
from machine import Pin
from neopixel import NeoPixel

class ESP32Controller:
    def __init__(self):
        self.NUM_LEDS = 300
        self.PIN = 5
        
        self.ZONE_GROUND = (0, 120)
        self.ZONE_TABLE = (120, 300)
        self.ZONE_GLOBAL = (1, 205)
        
        #self.ZONE_AIR = (175, 205)
        #self.ZONE_ELEC = (100, 175)
        #self.ZONE_WATER = (50, 100)
        #self.ZONE_FIRE = (1, 50)
        
        
        self.ZONE_AIR = (185, 205)
        self.ZONE_ELEC = (110, 185)
        self.ZONE_WATER = (60, 110)
        self.ZONE_FIRE = (1, 60)
        
        self.np = NeoPixel(Pin(self.PIN), self.NUM_LEDS)
        self.ws_client = WSclient("Cudy-F810", "13022495", "crystal_espLed")
        
        self.current_animation = None
        self.stop_animation = False
        self.animation_lock = _thread.allocate_lock()
        
        self.COLORS = {
            "orange": (110, 25, 0),
            "purple": (255, 0, 255),
            "blue_grey": (96, 125, 139),
            "blue": (0, 0, 255),
            "white": (255, 255, 255),
            "yellow": (192, 192, 0),
            "green": (0, 255, 0),
            "red": (192, 0, 0),
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

    def stop_current_animation(self):
        with self.animation_lock:
            self.stop_animation = True
            while self.current_animation:
                utime.sleep_ms(50)
            self.stop_animation = False

    def websocket_thread(self):
        while True:
            try:
                self.handle_websocket_messages()
                utime.sleep_ms(100)
            except Exception as e:
                print(f"WebSocket thread error: {e}")
                utime.sleep(5)

    def animation_thread(self, animation_func, args):
        with self.animation_lock:
            self.current_animation = animation_func.__name__
            try:
                animation_func(*args)
            finally:
                self.current_animation = None

    def start_animation(self, animation_func, args=()):
        self.stop_current_animation()
        _thread.start_new_thread(self.animation_thread, (animation_func, args))

    def set_color(self, zone, r, g, b):
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

   
    def process_websocket_message(self, message):
        if "led_crystal#on" in message:
            print("led_on#true")
            self.start_animation(self.set_color, (self.ZONE_GLOBAL, 128, 0, 128))
            self.send_message("ambianceManager=>[ambianceManager]=>led_on_crystal#true")
            
        elif "led_crystal#off" in message:
            print("led_off#true")
            self.start_animation(self.set_color, (self.ZONE_GLOBAL, 0, 0, 0))
            self.send_message("ambianceManager=>[ambianceManager]=>led_off_crystal#true")
            
        elif message == "crystal#tornado":
            print("Démarrage de l'animation 'crystal_to_tornado'")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_tornado#start")
            self.start_animation(self.tornado_animation)
            
        elif message == "crystal#maze":
            print("Démarrage de l'animation 'crystal_maze'")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_maze#start")
            self.start_animation(self.maze_animation)
            
        elif message == "crystal#typhoon":
            print("Démarrage de l'animation 'crystal_typhoon'")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_typhoon#start")
            self.start_animation(self.typhoon_animation)
            
        elif message == "crystal#volcano":
            print("Démarrage de l'animation 'crystal_volcano'")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_volcano#start")
            self.start_animation(self.volcano_animation)
            
        elif message == "crystal#finished":
            print("Démarrage de l'animation 'crystal_finished'")
            self.send_message("ambianceManager=>[ambianceManager]=>crystal_finish#start")
            self.start_animation(self.finish_animation)
            
        else:
            print("message inconnu :", message)

    def tornado_animation(self):
        if not self.stop_animation:
            self.blink_animation(self.ZONE_AIR, *self.COLORS["white"], 15, 100)
        if not self.stop_animation:
            self.fill_animation(self.ZONE_AIR, *self.COLORS["white"], delay_ms=5, direction="end")
        self.send_message("ambianceManager=>[ambianceManager]=>crystal_tornado#end")

    def maze_animation(self):
        if not self.stop_animation:
            self.blink_animation(self.ZONE_ELEC, *self.COLORS["gold"], 15, 100)
        if not self.stop_animation:
            self.fill_animation(self.ZONE_ELEC, *self.COLORS["yellow"], delay_ms=5, direction="end")
        self.send_message("ambianceManager=>[ambianceManager]=>crystal_maze#end")

    def typhoon_animation(self):
        if not self.stop_animation:
            self.blink_animation(self.ZONE_WATER, *self.COLORS["blue"], 15, 100)
        if not self.stop_animation:
            self.fill_animation(self.ZONE_WATER, *self.COLORS["blue"], delay_ms=5, direction="end")
        self.send_message("ambianceManager=>[ambianceManager]=>crystal_typhoon#end")

    def volcano_animation(self):
        if not self.stop_animation:
            self.blink_animation(self.ZONE_FIRE, *self.COLORS["orange"], 15, 100)
        if not self.stop_animation:
            self.fill_animation(self.ZONE_FIRE, *self.COLORS["orange"], delay_ms=5, direction="end")
        self.send_message("ambianceManager=>[ambianceManager]=>crystal_volcano#end")

    def finish_animation(self):
        if not self.stop_animation:
            self.blink_animation(self.ZONE_FIRE, *self.COLORS["orange"], 15, 100)
        if not self.stop_animation:
            self.blink_animation(self.ZONE_WATER, *self.COLORS["blue"], 15, 100)
        if not self.stop_animation:
            self.blink_animation(self.ZONE_AIR, *self.COLORS["white"], 15, 100)
        if not self.stop_animation:
            self.blink_animation(self.ZONE_ELEC, *self.COLORS["gold"], 15, 100)
        self.send_message("ambianceManager=>[ambianceManager]=>crystal_finish#end")

    def start(self):
        print("Starting controller...")
        if not self.ws_client.connect_wifi():
            print("WiFi connection failed. Stopping.")
            return

        self.ws_client.connect_websockets()
        
        _thread.start_new_thread(self.websocket_thread, ())
        
        while True:
            utime.sleep(1)
            
    def handle_websocket_messages(self):
        """Gère la réception des messages WebSocket"""
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
                if e.args[0] != 11:  # 11 is EAGAIN (no data available)
                    print(f"Error on WebSocket route {ws_route}: {e}")
                    self.handle_websocket_error(ws_route, e)

    def handle_websocket_error(self, ws_route, error):
        """Gère les erreurs WebSocket"""
        if error.args[0] == 128:  # ENOTCONN
            print(f"Connection lost on route {ws_route}, attempting reconnection...")
            self.attempt_reconnect()
        else:
            print(f"Error on WebSocket route {ws_route}: {error}")

    def attempt_reconnect(self):
        """Tente de se reconnecter au WebSocket"""
        print("Attempting to reconnect WebSocket...")
        
        if self.ws_client.connect_wifi():
            print("WiFi reconnected successfully")
            self.ws_client.connect_websockets()
            print("WebSocket reconnection attempt completed")
        else:
            print("WiFi reconnection failed")

    def send_message(self, msg):
        """Envoie un message au serveur WebSocket"""
        try:
            ws = self.ws_client.route_ws_map.get("message", None)
            if ws:
                print(f"Sending message: {msg}")
                ws.socket.setblocking(True)
                ws.send(msg)
            else:
                print("WebSocket route 'message' not found")
        except Exception as e:
            print(f"Error sending message: {e}")
            self.attempt_reconnect()

# Création et démarrage du contrôleur
controller = ESP32Controller()
controller.start()