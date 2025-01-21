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
        # Désactiver tous les relais à l'initialisation
        for relay in self.relays:
            relay.off()  # on() désactive le relay car la logique est inversée

        self.last_reconnect_attempt = 0
        self.reconnect_interval = 1
        # WebSocket client
        self.ws_client = WSclient("Cudy-F810", "13022495", "typhoon_esp")

        # État verrouillé des relais
        self.relay_locked = [False] * 4

    def handle_entrance_tag(self, card_id):
        """Callback for entrance RFID detection"""
        if card_id == 327204323:
            msg = f"typhon_esp=>[typhoon_iphone,typhoon_esp,ambianceManager,remoteController_iphone1,remoteController_iphone2]=>rfid#typhoon"
            self.ws_client.route_ws_map.get("message", None).send(msg)
        else:
            print(f"card {card_id} is wrong card")

    def handle_exit_tag(self, card_id):
        """Callback for exit RFID detection"""
        msg = f"typhoon_esp=>[typhon_iphone]=>rfid#false"
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_sphero_message(self, message):
        """Handle sphero-related relay control messages."""
        try:
            if "#" in message:
                sphero_cmd, state = message.split("#")
                
                if command == "all_relays" and state == "completed":
                    self.reset_all_relays()
                    return
                if sphero_cmd.startswith("sphero"):
                    relay_num = int(sphero_cmd[-1]) - 1  # Extract relay number (sphero1 -> relay 0)
                    
                    if 0 <= relay_num < len(self.relays):
                        # Ne pas modifier si le relais est verrouillé
                        if self.relay_locked[relay_num]:
                            return
                            
                        if state.lower() == "true":
                            self.relays[relay_num].on()
                            print(f"Relay {relay_num + 1} activated")
                        elif state.lower() == "false":
                            self.relays[relay_num].off()
                            print(f"Relay {relay_num + 1} deactivated")
                        elif state.lower() == "completed":
                            self.relays[relay_num].on()
                            self.relay_locked[relay_num] = True  # Verrouiller le relais
                            print(f"Relay {relay_num + 1} locked in active state")
                            self.check_all_relays_completed()
        except Exception as e:
            print(f"Erreur traitement message sphero: {e}")

    def set_relay_state(self, relay_num, state):
        """Set relay state and notify server."""
        if self.relay_locked[relay_num]:
            return

        if 0 <= relay_num < len(self.relays):
            try:
                if state:
                    self.relays[relay_num].off()  # Activate relay
                else:
                    self.relays[relay_num].on()  # Deactivate relay

                self.notify_relay_state(relay_num, state)
                print(f"Relay {relay_num + 1} set to {state}")
            except Exception as e:
                print(f"Error setting relay {relay_num + 1} state: {e}")
    
    def reset_all_relays(self):
        """Reset all relays to their initial state and unlock them."""
        for i, relay in enumerate(self.relays):
            relay.off()  # Désactive le relay (logique inversée)
            self.relay_locked[i] = False  # Déverrouille le relay
            self.notify_relay_state(i, False)
        print("All relays have been reset and unlocked")

    def check_all_relays_completed(self):
        """Check if all relays are locked (completed) and notify server if true."""
        if all(self.relay_locked):
            try:
                msg = f"typhoon_esp=>[ambianceManager, typhoon_esp]=>all_relays#completed"
                if "message" in self.ws_client.route_ws_map:
                    self.ws_client.route_ws_map["message"].send(msg)
                    print("All relays completed notification sent")
                    self.reset_all_relays()
                else:
                    print("WebSocket message route not available")
            except Exception as e:
                print(f"Error sending all relays completed message: {e}")

    def notify_relay_state(self, relay_num, state):
        """Send relay state update to server."""
        
        try:
            state_str = str(state).lower()
            msg = f"typhoon_esp=>[typhoon_iphone]=>relay{relay_num + 1}#{state_str}"
            if "message" in self.ws_client.route_ws_map:
                self.ws_client.route_ws_map["message"].send(msg)
                print(f"Sent relay state update: {msg}")
            else:
                print("WebSocket message route not available")
        except Exception as e:
            print(f"Error sending relay state: {e}")

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


                        # Gérer les messages sphero
                        if "sphero" in message and "#" in message:
                            self.handle_sphero_message(message)
                            
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

            if self.ws_client.connect_wifi():
                print("WiFi reconnected successfully")
                self.ws_client.connect_websockets()

                for i, relay in enumerate(self.relays):
                    # Get current state (remember logic is inverted)
                    current_state = not relay.value()  # Convert to logical state
                    self.notify_relay_state(i, current_state)

                print("WebSocket reconnection completed and states resynchronized")
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
        print("Waiting for typhoon activation...")

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