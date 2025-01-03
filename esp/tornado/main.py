from machine import Pin
import utime
from WSclient import WSclient
from DoubleRfid import RFIDController
from MultiMicro import Microphone

class ESP32Controller:
    def __init__(self):
        self.rfid = RFIDController()
        self.ws_client = WSclient("Cudy-F810", "13022495", "tornado_esp")
        self.microphones = [
            Microphone(pin_number=34, sound_threshold=300),
            Microphone(pin_number=35, sound_threshold=250),
            Microphone(pin_number=36, sound_threshold=250),
            Microphone(pin_number=32, sound_threshold=250)
        ]

    def handle_entrance_tag(self, card_id):
        msg = f"tornado_esp=>[tornado_rpi]=>rfid#true"
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_exit_tag(self, card_id):
        msg = f"tornado_esp=>[tornado_rpi]=>rfid#false"
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_mic_message(self, message):
        try:
            if "=>" in message:
                parts = message.split("=>")
                if len(parts) > 2:
                    payload = parts[-1]
                    mic_cmd, state = payload.split("#")
                    if mic_cmd.startswith("mic"):
                        mic_num = int(mic_cmd[-1]) - 1
                        if 0 <= mic_num < len(self.microphones):
                            print(f"Processing microphone {mic_num + 1} state: {state}")
        except Exception as e:
            print(f"Error processing microphone message: {e}")

    def monitor_microphones(self):
        for index, mic in enumerate(self.microphones, start=1):
            try:
                samples = mic.read_samples()
                audio_info = mic.analyze_audio(samples)
                current_state = "true" if audio_info['sound_detected'] else "false"
                
                if current_state != mic.last_detection_state:
                    msg = f"tornado_esp=>[tornado_rpi]=>mic{index}#{current_state}"
                    print(f"Sending microphone message: {msg}")
                    self.ws_client.route_ws_map.get("message", None).send(msg)
                    mic.last_detection_state = current_state
            except Exception as e:
                print(f"Error monitoring microphone {index}: {e}")

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
                        
                        if "ping" in message.lower():
                            self.ws_client.process_message(ws, message)
                        else:
                            self.handle_mic_message(message)
                        
            except OSError as e:
                if e.args[0] != 11:
                    print(f"Error on WebSocket route {ws_route}: {e}")

    def start(self):
        print("Starting controller...")
        if not self.ws_client.connect_wifi():
            print("WiFi connection failed.")
            return

        self.ws_client.connect_websockets()

        while True:
            try:
                self.handle_websocket_messages()
                self.rfid.check_readers(
                    callback_entrance=self.handle_entrance_tag,
                    callback_exit=self.handle_exit_tag
                )
                self.monitor_microphones()
                utime.sleep_ms(100)
            except Exception as e:
                print(f"General error: {e}")
                utime.sleep(5)
                self.__init__()
                self.start()

if __name__ == "__main__":
    controller = ESP32Controller()
    controller.start()