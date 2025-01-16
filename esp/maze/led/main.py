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
            "purple": (128, 0, 128),
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
        if self.stop_animation:
            return
            
        start, end = zone
        for _ in range(pulse_count):
            if self.stop_animation:
                return
                
            for intensity in range(0, 256, step):
                if self.stop_animation:
                    return
                scaled_r = int(r * intensity / 255)
                scaled_g = int(g * intensity / 255)
                scaled_b = int(b * intensity / 255)
                self.set_color(zone, scaled_r, scaled_g, scaled_b)
                utime.sleep_ms(pulse_speed_ms)
            
            for intensity in range(255, -1, -step):
                if self.stop_animation:
                    return
                scaled_r = int(r * intensity / 255)
                scaled_g = int(g * intensity / 255)
                scaled_b = int(b * intensity / 255)
                self.set_color(zone, scaled_r, scaled_g, scaled_b)
                utime.sleep_ms(pulse_speed_ms)

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

    def crystal_to_maze_animation(self):
        self.send_message("ambianceManager=>[ambianceManager]=>crystal_to_maze#start")
        self.fill_animation(self.ZONE_GLOBAL, *self.COLORS["purple"], delay_ms=6, direction="start")
        if not self.stop_animation:
            self.pulse_animation(self.ZONE_TABLE, *self.COLORS["purple"])
        if not self.stop_animation:
            self.set_color(self.ZONE_GLOBAL, *self.COLORS["purple"])
        self.send_message("ambianceManager=>[ambianceManager]=>crystal_to_maze#end")

    def maze_rfid_animation(self):
        self.send_message("ambianceManager=>[ambianceManager]=>maze_rfid#start")
        self.blink_animation(self.ZONE_TABLE, *self.COLORS["purple"], 3, 300)
        if not self.stop_animation:
            self.set_color(self.ZONE_GLOBAL, *self.COLORS["purple"])
        self.send_message("ambianceManager=>[ambianceManager]=>maze_rfid#end")

    def maze_finished_animation(self):
        self.send_message("ambianceManager=>[ambianceManager]=>maze_finished#start")
        self.color_transition_pulse(self.ZONE_TABLE, self.COLORS["purple"], self.COLORS["gold"], 2, step=35)
        if not self.stop_animation:
            self.set_color(self.ZONE_TABLE, *self.COLORS["gold"])
        self.send_message("ambianceManager=>[ambianceManager]=>maze_finished#end")

    def maze_to_crystal_animation(self):
        self.send_message("ambianceManager=>[ambianceManager]=>maze_to_crystal#start")
        self.fill_animation(self.ZONE_GROUND, *self.COLORS["gold"], delay_ms=5, direction="end")
        if not self.stop_animation:
            self.set_color(self.ZONE_GLOBAL, *self.COLORS["gold"])
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
            self.set_color(self.ZONE_GLOBAL,55, 30, 0)
            self.send_message("ambianceManager=>[ambianceManager]=>led_on_maze#true")
            
        elif "led_maze#off" in message:
            print("led_off#true")
            self.start_animation(self.set_color, (self.ZONE_GLOBAL, 0, 0, 0))
            self.send_message("ambianceManager=>[ambianceManager]=>led_off_maze#true")
            
        elif message == "crystal_to_maze#true":
            print("Starting 'crystal_to_maze' animation")
            self.start_animation(self.crystal_to_maze_animation)
            
        elif message == "rfid#maze":
            print("Starting 'maze_rfid' animation")
            self.start_animation(self.maze_rfid_animation)
            
        elif message == "maze_finished#true":
            print("Starting 'maze_finished' animation")
            self.start_animation(self.maze_finished_animation)
            
        elif message == "maze_to_crystal#true":
            print("Starting 'maze_to_crystal' animation")
            self.start_animation(self.maze_to_crystal_animation)
            
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