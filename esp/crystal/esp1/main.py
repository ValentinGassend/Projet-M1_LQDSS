from machine import Pin
import utime
from WSclient import WSclient
from libs.WebSocketClient import WebSocketClient
from DoubleRfid import RFIDController


class ESP32Controller:
    def __init__(self):
        # RFID Controller
        self.rfid = RFIDController()

        # WebSocket client
        self.ws_client = WSclient("Cudy-F810", "13022495", "crystal_esp1")

        self.last_reconnect_attempt = 0
        self.reconnect_interval = 1

        self.badge_states = {"maze": False, "volcano": False, "typhoon": False, "tornado": False}
    def handle_entrance_tag(self, card_id):
        if card_id == 323235155:
            self.badge_states["volcano"] = True
            msg = f"crystal_esp1=>[crystal_esp2,crystal_esp1,ambianceManager]=>rfid_crystal_volcano#true"

            self.check_crystal_start()
            print(f"Sending RFID entrance message: {msg}")

            self.ws_client.route_ws_map.get("message", None).send(msg)
        else:
            print(f"card {card_id} is wrong card")

    def handle_exit_tag(self, card_id):
        if card_id == 322763907:
            self.badge_states["maze"] = True
            msg = f"crystal_esp1=>[crystal_esp2,crystal_esp1,ambianceManager]=>rfid_crystal_maze#true"

            self.check_crystal_start()
            print(f"Sending RFID exit message: {msg}")
            self.ws_client.route_ws_map.get("message", None).send(msg)
        else:
            print(f"card {card_id} is wrong card")

    def check_crystal_start(self):
        if all(self.badge_states.values()):
            msg = f"crystal_esp1=>[crystal_esp2,crystal_esp1,ambianceManager]=>crystal_started#true"
            print(f"Sending message: {msg}")
            self.ws_client.route_ws_map.get("message", None).send(msg)

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
                        self.process_message(message)
                        # Check if message contains "ping"
                        if "ping" in message.lower():
                            # Forward ping messages directly to process_message
                            self.ws_client.process_message(ws, message)

            except OSError as e:
                if e.args[0] != 11:
                    print(f"Error on WebSocket route {ws_route}: {e}")
                    self.handle_websocket_error(ws_route, e)

    def process_message(self, message):
        if "rfid_crystal_typhoon#true" in message:
            self.badge_states["typhoon"] = True
            self.check_crystal_start()
        elif "rfid_crystal_tornado#true" in message:
            self.badge_states["tornado"] = True
            self.check_crystal_start()

    def attempt_reconnect(self):
        """Attempt to reconnect WebSocket connections"""
        current_time = utime.ticks_ms()
        if utime.ticks_diff(current_time, self.last_reconnect_attempt) > self.reconnect_interval:
            print("Attempting to reconnect WebSocket...")
            self.last_reconnect_attempt = current_time

            # Reinitialize WiFi connection
            if self.ws_client.connect_wifi():
                print("WiFi reconnected successfully")
                # Reinitialize WebSocket connections
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
                self.rfid.check_readers(
                    callback_entrance=self.handle_entrance_tag,
                    callback_exit=self.handle_exit_tag
                )
                utime.sleep_ms(100)

            except Exception as e:
                print(f"Erreur générale: {e}")
                utime.sleep(5)
                self.__init__()
                self.start()


if __name__ == "__main__":
    controller = ESP32Controller()
    controller.start()

