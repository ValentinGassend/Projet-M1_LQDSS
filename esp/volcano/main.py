from machine import Pin
import utime
from WSclient import WSclient
from libs.WebSocketClient import WebSocketClient
from DoubleRfid import RFIDController
from Button import ButtonController
from QuadrupleRelay import RelayController

class ESP32Controller:
    def __init__(self):
        self.rfid = RFIDController()
        self.ws_client = WSclient("Cudy-F810", "13022495", "volcano_esp1")
        self.button_controller = ButtonController()
        self.relays = [
            RelayController(32),
            RelayController(33)
        ]
        
        self.button_controller.add_button(23, "btn1")
        self.button_controller.add_button(27, "btn2")
        self.button_controller.add_button(14, "btn3")

    def notify_relay_state(self, relay_num, state):
        msg = f"volcano_esp1=>[volcano_esp2]=>relay{relay_num + 1}#{state}"
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def set_relay_state(self, relay_num, state):
        if 0 <= relay_num < len(self.relays):
            if state:
                self.relays[relay_num].on()
            else:
                self.relays[relay_num].off()
            self.notify_relay_state(relay_num, str(state).lower())
        
    def handle_entrance_tag(self, card_id):
        msg = f"volcano_esp1=>[volcano_esp2]=>rfid#fire"
        print(f"Sending RFID entrance message: {msg}")
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_exit_tag(self, card_id):
        msg = f"volcano_esp1=>[volcano_esp2]=>rfid#first"
        print(f"Sending RFID exit message: {msg}")
        self.ws_client.route_ws_map.get("message", None).send(msg)
        
    def handle_relay_message(self, message):
        try:
            if "=>" in message:
                parts = message.split("=>")
                if len(parts) > 2:
                    payload = parts[-1]
                    relay_cmd, state = payload.split("#")
                    if relay_cmd.startswith("relay"):
                        relay_num = int(relay_cmd[-1]) - 1
                        self.set_relay_state(relay_num, state.lower() == "true")
        except Exception as e:
            print(f"Error processing relay message: {e}")

    def handle_button_press(self, button_name):
        msg = f"volcano_esp1=>[volcano_esp1, volcano_esp2]=>btn#true"
        print(f"Button {button_name} pressed, sending message: {msg}")
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_websocket_messages(self):
        for ws_route, ws in self.ws_client.route_ws_map.items():
            try:
                ws.socket.setblocking(False)
                data = ws.socket.recv(1)
                if data:
                    message = ws.receive(first_byte=data)
                    if message:
                        print(f"Message received on route {ws_route}: {message}")
                        self.handle_relay_message(message)
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
                self.button_controller.run(
                    callback_press=self.handle_button_press
                )
                utime.sleep_ms(100)
            except Exception as e:
                print(f"General error: {e}")
                utime.sleep(5)
                self.__init__()
                self.start()

if __name__ == "__main__":
    controller = ESP32Controller()
    controller.start()