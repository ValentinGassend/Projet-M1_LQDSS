import utime
from WSclient import WSclient
from machine import Pin
from neopixel import NeoPixel
import time



class ESP32Controller:
    
        # Configuration

    def __init__(self):
        
        self.NUM_LEDS = 300  # Nombre de LEDs dans le bandeau
        self.PIN = 5        # Broche GPIO connectée au bandeau LED

        # Initialisation
        self.np = NeoPixel(Pin(self.PIN), self.NUM_LEDS)
        self.ws_client = WSclient("Cudy-F810", "13022495", "typhoon_esp")
        
        
    def set_color(self,r, g, b):
        for i in range(self.NUM_LEDS):
            self.np[i] = (r, g, b)
        self.np.write()

    def clear(self):
        for i in range(self.NUM_LEDS):
            np[i] = (0, 0, 0)
        self.np.write()

    def rainbow_cycle(self,wait):
        for j in range(255):
            for i in range(self.NUM_LEDS):
                rc_index = (i * 256 // self.NUM_LEDS) + j
                self.np[i] = self.wheel(rc_index & 255)
            self.np.write()
            time.sleep_ms(wait)

    def wheel(self,pos):
        if pos < 85:
            return (255 - pos * 3, pos * 3, 0)
        elif pos < 170:
            pos -= 85
            return (0, 255 - pos * 3, pos * 3)
        else:
            pos -= 170
            return (pos * 3, 0, 255 - pos * 3)


    
    def process_websocket_message(self, message):
        """Traite les messages WebSocket reçus"""
        if "ledON" in message:
            print("Message ledon")
            
        elif "ledOFF" in message:
            print("Message ledOFF")
        else:
            print("message inconnus")
            #self.set_color(50,50,50)
            self.rainbow_cycle(20)
            #self.set_color(255, 0, 0)
           #self.set_color(0, 255, 0)
            #self.set_color(0, 0, 255)
           # self.set_color(255, 255, 0)
            
            #self.rainbow_cycle(20)
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

                except Exception as e:
                    print(f"Erreur générale: {e}")
                    utime.sleep(5)
                    self.init()
                    self.start()



controller = ESP32Controller()
controller.start()
