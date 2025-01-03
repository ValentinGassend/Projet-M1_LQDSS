from machine import Pin
import utime
from WSclient import WSclient
from libs.WebSocketClient import WebSocketClient
from QuadrupleRelay import RelayController
from DoubleRfid import RFIDController

class ESP32Controller:
    def __init__(self):
        # RFID Controller
        self.rfid = RFIDController()

        # Relays initialization
        self.relays = [
            RelayController(32),
            RelayController(33),
            RelayController(25),
            RelayController(26)
        ]

        self.last_reconnect_attempt = 0
        self.reconnect_interval = 1
        # WebSocket client
        self.ws_client = WSclient("Cudy-F810", "13022495", "typhoon_esp")

    def handle_entrance_tag(self, card_id):
        """Callback for entrance RFID detection"""
        if card_id == "327204323":
            msg = f"typhoon_esp=>[typhon_iphone]=>rfid#true"
            self.ws_client.route_ws_map.get("message", None).send(msg)
        else:
            print(f"card {card_id} is wrong card")



    def handle_exit_tag(self, card_id):
        """Callback for exit RFID detection"""
        msg = f"typhoon_esp=>[typhon_iphone]=>rfid#false"
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_sphero_message(self, sphero_num, state):
        """Handle sphero-related relay control messages."""
        try:
            relay_num = int(sphero_num[-1]) - 1  # Extract relay number from sphero identifier
            if 0 <= relay_num < len(self.relays):
                if state.lower() == "true":
                    self.relays[relay_num].on()
                elif state.lower() == "false":
                    self.relays[relay_num].off()
                elif state.lower() == "completed":
                    self.relays[relay_num].on()  # Turn relay on and leave it on
        except Exception as e:
            print(f"Erreur traitement message sphero: {e}")

    def handle_relay_message(self, message):
        """Handle incoming relay control messages"""
        try:
            # Extraire la dernière partie utile du message après le second `=>`
            if "=>" in message:
                parts = message.split("=>")
                if len(parts) > 2:
                    payload = parts[-1]  # On prend la partie après le dernier `=>`
                    if "#" in payload:
                        sphero_cmd, state = payload.split("#")
                        if sphero_cmd.startswith("sphero"):
                            print("start with sphero")
                            self.handle_sphero_message(sphero_cmd, state)
        except Exception as e:
            print(f"Erreur traitement message relais: {e}")

    def handle_websocket_messages(self):
        """Process WebSocket messages"""
        for ws_route, ws in self.ws_client.route_ws_map.items():
            try:
                ws.socket.setblocking(False)
                data = ws.socket.recv(1)
                ws.socket.setblocking(True)
                if data:
                    message = ws.receive(first_byte=data)
                    if message:
                        print(f"Message received on route {ws_route}: {message}")
                        if ws_route == "message":
                            self.handle_relay_message(message)
                        self.ws_client.process_message(ws, message)
            except OSError as e:
                if e.args[0] != 11:  # Ignore EAGAIN errors
                    print(f"Error on WebSocket route {ws_route}: {e}")
                    self.handle_websocket_error(ws_route, e)

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
                # Vérification des messages WebSocket
                self.handle_websocket_messages()

                # Vérification des lecteurs RFID
                self.rfid.check_readers(
                    callback_entrance=self.handle_entrance_tag,
                    callback_exit=self.handle_exit_tag
                )

                utime.sleep_ms(100)

            except Exception as e:
                print(f"Erreur générale: {e}")
                utime.sleep(5)
                self.__init__()  # Réinitialiser le contrôleur
                self.start()

if __name__ == "__main__":
    controller = ESP32Controller()
    controller.start()
