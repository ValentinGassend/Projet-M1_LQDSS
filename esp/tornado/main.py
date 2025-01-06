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

        # Add state tracking
        self.is_activated = False
        self.last_reconnect_attempt = 0
        self.reconnect_interval = 1

    def handle_entrance_tag(self, card_id):
        if not self.is_activated:
            return

        if card_id == 152301587:
            msg = f"tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>rfid#tornado"
            self.ws_client.route_ws_map.get("message", None).send(msg)
        else:
            print(f"card {card_id} is wrong card")

    def handle_exit_tag(self, card_id):
        if not self.is_activated:
            return

        msg = f"tornado_esp=>[tornado_rpi]=>rfid#false"
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_mic_message(self, message):
        if not self.is_activated:
            return

        try:
            if "#" in message:
                mic_cmd, state = message.split("#")
                if mic_cmd.startswith("mic"):
                    mic_num = int(mic_cmd[-1]) - 1
                    if 0 <= mic_num < len(self.microphones):
                        print(f"Processing microphone {mic_num + 1} state: {state}")
        except Exception as e:
            print(f"Error processing microphone message: {e}")

    def monitor_microphones(self):
        if not self.is_activated:
            return

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

                        # Check for activation message
                        if "rfid#tornado" in message:
                            print("Tornado ESP activated!")
                            self.is_activated = True

                        if "ping" in message.lower():
                            self.ws_client.process_message(ws, message)
                        else:
                            self.handle_mic_message(message)

            except OSError as e:
                if e.args[0] != 11:
                    print(f"Error on WebSocket route {ws_route}: {e}")
                    self.handle_websocket_error(ws_route, e)

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

    def handle_websocket_error(self, ws_route, error):
        if error.args[0] == 128:  # ENOTCONN
            print(f"Connection lost on route {ws_route}, attempting reconnection...")
            self.attempt_reconnect()
        else:
            print(f"Error on WebSocket route {ws_route}: {error}")

    def start(self):
        print("Starting controller...")
        if not self.ws_client.connect_wifi():
            print("WiFi connection failed.")
            return

        self.ws_client.connect_websockets()
        print("Waiting for tornado activation...")

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