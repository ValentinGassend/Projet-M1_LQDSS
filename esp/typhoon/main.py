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

        # WebSocket client
        self.ws_client = WSclient("Cudy-F810", "13022495", "typhoon_esp")

    def handle_entrance_tag(self, card_id):
        """Callback for entrance RFID detection"""
        msg = f"typhoon_esp=>[typhon_iphone]=>rfid#{card_id}#true"
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_exit_tag(self, card_id):
        """Callback for exit RFID detection"""
        msg = f"typhoon_esp=>[typhon_iphone]=>rfid#{card_id}#false"
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_relay_message(self, message):
        """Handle incoming relay control messages"""
        try:
            if "#" in message:
                cmd, state = message.split("#")
                relay_num = int(cmd[-1]) - 1
                if 0 <= relay_num <= 3:
                    if state.lower() == "true":
                        self.relays[relay_num].on()
                    else:
                        self.relays[relay_num].off()
        except Exception as e:
            print(f"Erreur traitement message relais: {e}")

    def handle_websocket_messages(self):
        """Process WebSocket messages"""
        for ws_route, ws in self.ws_client.route_ws_map.items():
            try:
                ws.socket.setblocking(False)
                data = ws.socket.recv(1)
                if data:
                    message = ws.receive(first_byte=data)
                    if message:
                        print(f"Message received on route {ws_route}: {message}")
                        if ws_route == "message":
                            self.handle_relay_message(message)
                        self.ws_client.process_message(ws,message)
            except OSError as e:
                if e.args[0] != 11:  # Ignore EAGAIN errors
                    print(f"Error on WebSocket route {ws_route}: {e}")

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
