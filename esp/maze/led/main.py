import _thread
import utime
from WSclient import WSclient
from machine import Pin
from neopixel import NeoPixel
import time
from WebSocketClient import WebSocketClient


class ESP32Controller:
    def __init__(self):
        self.NUM_LEDS = 657
        self.PIN = 5

        self.ZONE_GROUND = (0, 120)
        self.ZONE_TABLE = (120, 300)
        self.ZONE_GLOBAL = (0, self.NUM_LEDS)
        
        self.ZONE_INSIDE = (428, 585)
        
        self.ZONE_BTN1 = (633, 657)
        self.ZONE_BTN2 = (609, 633)
        self.ZONE_BTN3 = (585, 609)
        
        self.np = NeoPixel(Pin(self.PIN), self.NUM_LEDS)
        self.ws_client = WSclient("Cudy-F810", "13022495", "maze_espLed")

        # Thread control
        self.current_animation = None
        self.stop_animation = False
        self.animation_lock = _thread.allocate_lock()

        # WebSocket reconnection control
        self.last_reconnect_attempt = 0
        self.reconnect_interval = 5000  # 5 seconds

        self.COLORS = {
            "orange": (220, 50, 0),
            "purple": (96, 0, 96),
            "blue_grey": (96, 125, 139),
            "blue": (50, 50, 255),
            "yellow": (55, 55, 0),
            "green": (0, 255, 0),
            "red": (255, 0, 0),
            "pink": (255, 192, 203),
            "cyan": (0, 150, 255),
            "magenta": (255, 0, 255),
            "white": (50, 50, 50),
            "black": (0, 0, 0),
            "teal": (0, 128, 128),
            "gold": (210, 160, 0),
            "lavender": (230, 230, 250),
            "turquoise": (64, 224, 208),
            "maze": (55, 30, 0),
            "typhoon": (0, 0, 48),
            "tornado": (48, 48, 30),
            "volcano": (148, 25, 0),
        }

    def stop_current_animation(self):
        with self.animation_lock:
            self.stop_animation = True
            while self.current_animation:
                utime.sleep_ms(50)
            self.stop_animation = False
    def continuous_inside_animation(self):
        """
        Continuously runs the inside_progressive_animation until stopped
        """
        while self.run_inside_animation and not self.stop_animation:
            self.inside_finished_animation()
            utime.sleep_ms(100)  # Small delay between iterations
     
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

    def clear(self, zone):
        self.set_color(zone, 0, 0, 0)

    def wheel(self, pos):
        if pos < 85:
            return (255 - pos * 3, pos * 3, 0)
        elif pos < 170:
            pos -= 85
            return (0, 255 - pos * 3, pos * 3)
        else:
            pos -= 170
            return (pos * 3, 0, 255 - pos * 3)

    def pulse_animation(self, zone, r, g, b, pulse_count=3, pulse_speed_ms=2, step=20):
        start, end = zone
        current_pulse = 0
        
        while current_pulse < pulse_count:
            # Fondu d'entrée (fade in)
            for intensity in range(0, 256, step):
                scaled_r = min(r, int(r * intensity / 255))
                scaled_g = min(g, int(g * intensity / 255))
                scaled_b = min(b, int(b * intensity / 255))
                self.set_color(zone, scaled_r, scaled_g, scaled_b)
                utime.sleep_ms(pulse_speed_ms)
            
            # Pause à l'intensité maximale
            utime.sleep_ms(200)  # Pause plus longue au maximum
            
            # Si c'est la dernière pulsation ou si on doit arrêter, on reste au maximum
            if current_pulse == pulse_count - 1 or self.stop_animation:
                self.set_color(zone, r, g, b)
                return
            
            # Sinon, on continue avec le fade out
            for intensity in range(255, -1, -step):
                scaled_r = min(r, int(r * intensity / 255))
                scaled_g = min(g, int(g * intensity / 255))
                scaled_b = min(b, int(b * intensity / 255))
                self.set_color(zone, scaled_r, scaled_g, scaled_b)
                utime.sleep_ms(pulse_speed_ms)
            
            current_pulse += 1
            
    def color_transition_pulse(self, zone, color1, color2, pulse_speed_ms=10, step=5):
        if self.stop_animation:
            return

        r1, g1, b1 = color1
        r2, g2, b2 = color2

        for mix in range(0, 256, step):
            if self.stop_animation:
                return

            mixed_r = int(r1 + (r2 - r1) * mix / 255)
            mixed_g = int(g1 + (g2 - g1) * mix / 255)
            mixed_b = int(b1 + (b2 - b1) * mix / 255)

            for intensity in range(0, 256, step):
                if self.stop_animation:
                    return
                scaled_r = int(mixed_r * intensity / 255)
                scaled_g = int(mixed_g * intensity / 255)
                scaled_b = int(mixed_b * intensity / 255)
                self.set_color(zone, scaled_r, scaled_g, scaled_b)
                utime.sleep_ms(pulse_speed_ms)

            for intensity in range(255, -1, -step):
                if self.stop_animation:
                    return
                scaled_r = int(mixed_r * intensity / 255)
                scaled_g = int(mixed_g * intensity / 255)
                scaled_b = int(mixed_b * intensity / 255)
                self.set_color(zone, scaled_r, scaled_g, scaled_b)
                utime.sleep_ms(pulse_speed_ms)

    def blink_animation(self, zone, r, g, b, blink_count=5, blink_delay_ms=500):
        if self.stop_animation:
            return

        for _ in range(blink_count):
            if self.stop_animation:
                return
            self.set_color(zone, r, g, b)
            utime.sleep_ms(blink_delay_ms)
            self.clear(zone)
            utime.sleep_ms(blink_delay_ms)

    def fill_animation(self, zone, r, g, b, delay_ms=50, direction="start"):
        if self.stop_animation:
            return

        start, end = zone
        if direction == "start":
            led_range = range(start, end)
        elif direction == "end":
            led_range = range(end - 1, start - 1, -1)
        else:
            raise ValueError("Direction must be 'start' or 'end'")

        for i in led_range:
            if self.stop_animation:
                return
            self.np[i] = (r, g, b)
            self.np.write()
            utime.sleep_ms(delay_ms)

    def inside_finished_animation(self):
        """
        Animation pour la zone intérieure avec segments lumineux aléatoires et timing chaotique
        Chaque segment s'allume et s'éteint de façon indépendante avec des délais aléatoires
        L'animation dure environ 1 seconde avec un timing contrôlé
        Les LEDs s'allument progressivement avec des timings aléatoires pour un effet chaotique
        """
        import random
        
        start, end = self.ZONE_INSIDE
        maze_color = self.COLORS["maze"]
        
        # Nettoyer la zone
        self.clear(self.ZONE_INSIDE)
        
        # Générer des points de départ aléatoires avec espacement suffisant
        start_points = []
        while len(start_points) < 10:
            segment_length = random.randint(1, 5)
            point = random.randint(start, end - segment_length)
            
            overlap = False
            for existing_point in start_points:
                if abs(point - existing_point[0]) < max(segment_length + 2, existing_point[1] + 2):
                    overlap = True
                    break
                    
            if not overlap:
                # Ajouter délais aléatoires pour apparition et durée
                start_delay = random.randint(0, 200)  # Délai avant apparition (0-200ms)
                duration = random.randint(300, 800)   # Durée d'illumination (300-800ms)
                start_points.append((point, segment_length, start_delay, duration))
        
        # Enregistrer le temps de départ
        start_time = utime.ticks_ms()
        
        # Dictionnaire pour suivre l'état des segments
        segment_states = {}
        
        # Boucle principale d'animation
        while True:
            current_time = utime.ticks_ms()
            elapsed = utime.ticks_diff(current_time, start_time)
            
            if elapsed >= 1000:  # Arrêter après 1 seconde
                break
                
            # Gérer chaque segment
            for point, length, start_delay, duration in start_points:
                segment_key = (point, length)
                
                # Vérifier si c'est le moment d'allumer le segment
                if elapsed >= start_delay and segment_key not in segment_states:
                    # Allumer le segment
                    for i in range(length):
                        self.np[point + i] = maze_color
                        if random.random() < 0.3:
                            self.np.write()
                            utime.sleep_ms(random.randint(5, 15))
                    self.np.write()
                    segment_states[segment_key] = current_time
                
                # Vérifier si c'est le moment d'éteindre le segment
                elif segment_key in segment_states:
                    segment_elapsed = utime.ticks_diff(current_time, segment_states[segment_key])
                    if segment_elapsed >= duration:
                        # Éteindre le segment
                        for i in range(length):
                            self.np[point + i] = (0, 0, 0)
                        self.np.write()
                        del segment_states[segment_key]
            
            utime.sleep_ms(10)  # Petit délai pour éviter de surcharger le processeur
        
        # Nettoyer la zone à la fin
        self.clear(self.ZONE_INSIDE)
    def inside_progressive_animation(self):
        """
        Progressively illuminates the RFID LED zone from 4 random starting points,
        with bidirectional propagation from each point.
        """
        import random
        
        start, end = self.ZONE_INSIDE
        maze_color = self.COLORS["maze"]
        zone_length = end - start
        
        # Clear the zone first
        self.clear(self.ZONE_INSIDE)
        
        # Generate 4 random starting points within the zone
        # Using randint instead of sample
        start_points = []
        while len(start_points) < 6:
            point = random.randint(start, end-1)
            if point not in start_points:
                start_points.append(point)
        start_points.sort()
        
        # Create lists to track active propagation points
        # Each entry is (current_pos, direction)
        propagation_points = []
        for point in start_points:
            # Add both directions for each point: 1 for forward, -1 for backward
            propagation_points.append([point, 1])
            propagation_points.append([point, -1])
            # Light up the initial points
            self.np[point] = maze_color
        
        # Keep track of lit LEDs to avoid duplicates
        lit_leds = set(start_points)
        
        # Continue until all LEDs in the zone are lit
        while len(lit_leds) < zone_length and not self.stop_animation:
            points_to_remove = []
            
            # Process each propagation point
            for i, (pos, direction) in enumerate(propagation_points):
                # Calculate next position
                next_pos = pos + direction
                
                # Check if next position is within bounds
                if start <= next_pos < end and next_pos not in lit_leds:
                    # Light up the LED
                    self.np[next_pos] = maze_color
                    lit_leds.add(next_pos)
                    # Update position
                    propagation_points[i][0] = next_pos
                else:
                    # Mark this propagation point for removal
                    points_to_remove.append(i)
            
            # Remove completed propagation points
            for i in sorted(points_to_remove, reverse=True):
                propagation_points.pop(i)
            
            # Update display
            self.np.write()
            utime.sleep_ms(10)  # Adjust speed of progression
    def crystal_to_maze_animation(self):
        self.send_message("ambianceManager=>[ambianceManager]=>crystal_to_maze#start")
        self.fill_animation(self.ZONE_GROUND, *self.COLORS["purple"], delay_ms=6, direction="start")
        
        self.fill_animation(self.ZONE_TABLE, *self.COLORS["purple"], delay_ms=6, direction="start")
        if not self.stop_animation:
            self.pulse_animation(self.ZONE_TABLE, *self.COLORS["purple"],2)
        self.send_message("ambianceManager=>[ambianceManager]=>crystal_to_maze#end")

    def maze_rfid_animation(self):
        # Send start message
        self.send_message("ambianceManager=>[ambianceManager]=>maze_rfid#start")
        
        # Get the purple color from the predefined colors
        purple = self.COLORS["purple"]
        
        # Execute the pulse animation with the specified parameters
        if not self.stop_animation:
            # Do the animation first
            self.pulse_animation(self.ZONE_TABLE, 
                               purple[0], purple[1], purple[2],
                               pulse_count=2,    
                               pulse_speed_ms=20,  
                               step=35)
            
            # Only send end message after animation is complete
            if not self.stop_animation:  # Check again in case animation was stopped
                self.send_message("ambianceManager=>[ambianceManager]=>maze_rfid#end")
    def maze_finished_animation(self):
        self.send_message("ambianceManager=>[ambianceManager]=>maze_finished#start")
        
        # Set the flag to start continuous inside animation
        self.run_inside_animation = True
        
        # Start the continuous inside animation in a separate thread
        _thread.start_new_thread(self.continuous_inside_animation, ())
        
        # Remplissage rapide depuis la fin
        start, end = self.ZONE_TABLE
        for i in range(end - 1, start - 1, -1):
            if self.stop_animation:
                return
            self.np[i] = self.COLORS["maze"]
            self.np.write()
            utime.sleep_ms(1)
        
        # Une seule pulsation en maze
        if not self.stop_animation:
            # Augmentation de l'intensité
            for intensity in range(0, 256, 35):
                if self.stop_animation:
                    return
                r, g, b = self.COLORS["maze"]
                scaled_r = int(r * intensity / 255)
                scaled_g = int(g * intensity / 255)
                scaled_b = int(b * intensity / 255)
                self.set_color(self.ZONE_TABLE, scaled_r, scaled_g, scaled_b)
                utime.sleep_ms(2)
            
            # Diminution de l'intensité
            for intensity in range(255, -1, -35):
                if self.stop_animation:
                    return
                r, g, b = self.COLORS["maze"]
                scaled_r = int(r * intensity / 255)
                scaled_g = int(g * intensity / 255)
                scaled_b = int(b * intensity / 255)
                self.set_color(self.ZONE_TABLE, scaled_r, scaled_g, scaled_b)
                utime.sleep_ms(2)
            
            # Retour à la couleur maze pleine
            self.set_color(self.ZONE_TABLE, *self.COLORS["maze"])
        
        self.send_message("ambianceManager=>[ambianceManager]=>maze_finished#end")

    def maze_to_crystal_animation(self):
        self.send_message("ambianceManager=>[ambianceManager]=>maze_to_crystal#start")
        self.fill_animation(self.ZONE_GROUND, *self.COLORS["maze"], delay_ms=5, direction="end")
        self.send_message("ambianceManager=>[ambianceManager]=>maze_to_crystal#end")

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
                if e.args[0] != 11:  # 11 is EAGAIN (no data available)
                    print(f"Error on WebSocket route {ws_route}: {e}")
                    self.handle_websocket_error(ws_route, e)

    def process_websocket_message(self, message):
        if "led_maze#on" in message:
            print("led_on#true")
            #self.set_color(self.ZONE_GLOBAL, 55, 30, 0)
            
            self.start_animation(self.inside_progressive_animation)
            self.send_message("ambianceManager=>[ambianceManager]=>led_on_maze#true")

        elif "led_maze#off" in message or "Hello" in message:
            print("led_off#true")
            self.start_animation(self.set_color, (self.ZONE_GLOBAL, 0, 0, 0))
            self.send_message("ambianceManager=>[ambianceManager]=>led_off_maze#true")

        elif message == "crystal_to_maze#true" or message == "crystal_tornado#end":
            print("Starting 'crystal_to_maze' animation")
            self.start_animation(self.crystal_to_maze_animation)

        elif message == "rfid#maze":
            print("Starting 'maze_rfid' animation")
            self.start_animation(self.maze_rfid_animation)
            self.start_animation(self.inside_progressive_animation)


        elif message == "maze_finished#true":
            print("Starting 'maze_finished' animation")
            self.start_animation(self.maze_finished_animation)

        
        elif message == "maze_to_crystal#end":
            print("Setting all zones to maze color")
            self.run_inside_animation = False  # Ensure the animation is stopped
            # Set all zones to maze color
            self.set_color(self.ZONE_TABLE, *self.COLORS["maze"])
            self.set_color(self.ZONE_GROUND, *self.COLORS["maze"])
            self.set_color(self.ZONE_INSIDE, *self.COLORS["maze"])
            self.set_color(self.ZONE_BTN1, *self.COLORS["maze"])
            self.set_color(self.ZONE_BTN2, *self.COLORS["maze"])
            self.set_color(self.ZONE_BTN3, *self.COLORS["maze"])
        
        elif message == "maze_to_crystal#true" or message == "maze_finished#end":
            print("Starting 'maze_to_crystal' animation")
            self.start_animation(self.maze_to_crystal_animation)
        
        elif message == "btn1#start":
            self.set_color(self.ZONE_BTN2, *self.COLORS["tornado"])
            self.set_color(self.ZONE_BTN3, *self.COLORS["tornado"])
            
        
        elif message == "btn1#unlock":
            self.set_color(self.ZONE_BTN1, *self.COLORS["tornado"])
            
        elif message == "btn1#end":
            self.set_color(self.ZONE_BTN1, *self.COLORS["maze"])
            self.start_animation(self.inside_progressive_animation)
            self.start_animation(self.maze_finished_animation)

        elif message == "btn1#false":
            print("Button 1 OFF")
            self.clear(self.ZONE_BTN1)
            
        elif message == "btn2#true":
            print("Button 2 ON")
            self.set_color(self.ZONE_BTN2, *self.COLORS["maze"])
            
        elif message == "btn3#true":
            print("Button 3 ON")
            self.set_color(self.ZONE_BTN3, *self.COLORS["maze"])


        else:
            print("Unknown message:", message)

    def handle_websocket_error(self, ws_route, error):
        if error.args[0] == 128:  # ENOTCONN
            print(f"Connection lost on route {ws_route}, attempting reconnection...")
            self.attempt_reconnect()
        else:
            print(f"Error on WebSocket route {ws_route}: {error}")

    def attempt_reconnect(self):
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

    def send_message(self, msg):
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

    def start(self):
        print("Starting controller...")
        if not self.ws_client.connect_wifi():
            print("WiFi connection failed. Stopping.")
            return

        self.ws_client.connect_websockets()

        # Start WebSocket thread
        _thread.start_new_thread(self.websocket_thread, ())

        # Main loop
        while True:
            utime.sleep(1)


# Create and start controller
controller = ESP32Controller()
controller.start()
