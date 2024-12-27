from machine import Pin
import utime
from WSclient import WSclient
from libs.WebSocketClient import WebSocketClient
from DoubleRfid import RFIDController
from Microphone import Microphone

class ESP32Controller:
    def __init__(self):
        # RFID Controller
        self.rfid = RFIDController()

        # WebSocket client
        self.ws_client = WSclient("Cudy-F810", "13022495", "tornado_esp")

        # Microphones
        self.microphones = [
            Microphone(pin_number=34, sound_threshold=300),  # Microphone 1
            Microphone(pin_number=35, sound_threshold=250),  # Microphone 2
            Microphone(pin_number=36, sound_threshold=250),  # Microphone 3
            Microphone(pin_number=32, sound_threshold=250)   # Microphone 4
        ]

    def handle_entrance_tag(self, card_id):
        """Callback for entrance RFID detection"""
        msg = f"tornado_esp=>[tornado_rpi]=>rfid#true"
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_exit_tag(self, card_id):
        """Callback for exit RFID detection"""
        msg = f"tornado_esp=>[tornado_rpi]=>rfid#false"
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_microphone_message(self, mic_id, state):
        """Callback for microphone state changes"""
        msg = f"tornado_esp=>[tornado_rpi]=>mic{mic_id}#{state}"
        self.ws_client.route_ws_map.get("message", None).send(msg)

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
                        self.ws_client.process_message(ws, message)
            except OSError as e:
                if e.args[0] != 11:  # Ignore EAGAIN errors
                    print(f"Error on WebSocket route {ws_route}: {e}")

    def monitor_microphones(self):
        """Monitor the state of all microphones and send WebSocket messages on state changes"""
        for index, mic in enumerate(self.microphones, start=1):
            samples = mic.read_samples()
            audio_info = mic.analyze_audio(samples)
            current_state = "true" if audio_info['sound_detected'] else "false"
            
            if current_state != mic.last_detection_state:
                self.handle_microphone_message(index, current_state)
                mic.last_detection_state = current_state

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

                # Surveillance des microphones
                self.monitor_microphones()

                utime.sleep_ms(100)

            except Exception as e:
                print(f"Erreur générale: {e}")
                utime.sleep(5)
                self.__init__()  # Réinitialiser le contrôleur
                self.start()

if __name__ == "__main__":
    controller = ESP32Controller()
    controller.start()
