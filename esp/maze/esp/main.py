from machine import Pin
import utime
from WSclient import WSclient
from DoubleRfid import RFIDController

class Button:
    """A single button implementation with debounce"""

    def __init__(self, pin_number, name, pull_up=True):
        if pull_up:
            self.pin = Pin(pin_number, Pin.IN, Pin.PULL_UP)
        else:
            self.pin = Pin(pin_number, Pin.IN)

        self.name = name
        self.last_state = self.pin.value()
        self.pressed = False
        self.released = False

    def update(self):
        """Update button state with no debounce"""
        reading = self.pin.value()

        if reading != self.last_state:
            self.pressed = (reading == 0)  # Active low with pull-up
            self.released = (reading == 1)
            self.last_state = reading
            return True

        return False


class ButtonController:
    """Manages multiple buttons with sequence logic"""
    def __init__(self):
        self.buttons = {}
        self.button_states = {
            "btn1": False,
            "btn2": False,
            "btn3": False
        }
        self.btn1_first_press = True  # Track if it's the first press of btn1
        self.btn1_locked = False
        self.btn1_unlock_notified = False  # Track if unlock message has been sent

    def add_button(self, pin_number, button_name):
        button = Button(pin_number, button_name)
        self.buttons[button_name] = button
        return button

    def can_activate_button(self, button_name):
        if button_name == "btn1":
            if self.btn1_first_press:
                return True
            elif self.btn1_locked:
                return self.button_states["btn2"] and self.button_states["btn3"]
        return True

    def get_button_message(self, button_name, is_pressed):
        if button_name == "btn1" and is_pressed:
            if self.btn1_first_press:
                return f"{button_name}#start"
            elif self.button_states["btn2"] and self.button_states["btn3"]:
                return f"{button_name}#end"
        return f"{button_name}#{'true' if is_pressed else 'false'}"

    def check_buttons(self, callback_press=None, callback_release=None, server_message_callback=None):
        for name, button in self.buttons.items():
            if button.update():
                if button.pressed:
                    if self.can_activate_button(name):
                        if callback_press:
                            message = self.get_button_message(name, True)
                            callback_press(message)
                            self.button_states[name] = True

                            if name == "btn1":
                                if self.btn1_first_press:
                                    self.btn1_first_press = False
                                    self.btn1_locked = True
                            self.check_button_sequence(callback_press, server_message_callback)
                    else:
                        print(f"{name} is locked - activate other buttons first")
                elif button.released and callback_release:
                    message = self.get_button_message(name, False)
                    callback_release(message)

    def check_button_sequence(self, callback_press=None, server_message_callback=None):
        if (self.btn1_locked and not self.btn1_unlock_notified and
                self.button_states["btn2"] and self.button_states["btn3"]):
            if callback_press:
                callback_press("btn1#unlock")
                self.btn1_unlock_notified = True
                
                # Send message to server when btn1 is unlocked
                if server_message_callback:
                    server_message = "maze_esp=>[remoteController_iphone1,remoteController_iphone2,remoteController_iphone3,maze_esp,ambianceManager]=>btn1#unlock"
                    server_message_callback(server_message)


    def reset_sequence(self):
        self.button_states = {
            "btn1": False,
            "btn2": False,
            "btn3": False
        }
        self.btn1_first_press = True
        self.btn1_locked = False
        self.btn1_unlock_notified = False


class ESP32Controller:
    def __init__(self):
        self.rfid = RFIDController()
        self.ws_client = WSclient("Cudy-F810", "13022495", "maze_esp")
        self.button_controller = ButtonController()
        
        # Initialize buttons
        self.button_controller.add_button(23, "btn1")
        self.button_controller.add_button(27, "btn2")
        self.button_controller.add_button(14, "btn3")
        
        self.ct_attempt = 0
        self.reconnect_interval = 10000  # 10 seconds in milliseconds
        self.message_queue = []

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
                self.message_queue.append(msg)
        except Exception as e:
            print(f"Error sending message: {e}")
            self.message_queue.append(msg)
            self.attempt_reconnect()

    def handle_websocket_error(self, ws_route, error):
        if error.args[0] == 128:  # ENOTCONN
            print(f"Connection lost on route {ws_route}, attempting reconnection...")
            self.attempt_reconnect()
        else:
            print(f"Error on WebSocket route {ws_route}: {error}")

    def handle_entrance_tag(self, card_id):
        
        if card_id == 322763907:
            msg = "maze_esp=>[remoteController_iphone1,remoteController_iphone2,remoteController_iphone3,maze_esp,ambianceManager]=>rfid#maze"
            print(f"Sending RFID entrance message: {msg}")
            ws = self.ws_client.route_ws_map.get("message", None)
            if ws:
                ws.send(msg)
        else:
            print(f"card {card_id} is wrong card")

    def handle_exit_tag(self, card_id):
        
        msg = "maze_esp=>[maze_iphone]=>rfid#false"
        print(f"Sending RFID exit message: {msg}")
        ws = self.ws_client.route_ws_map.get("message", None)
        if ws:
            ws.send(msg)
            # Reset button sequence when exit tag is detected
            self.button_controller.reset_sequence()

    def handle_button_press(self, message):
        msg = f"maze_esp=>[remoteController_iphone3,ambianceManager]=>{message}"
        self.send_message(msg)

    def handle_button_release(self, message):
        msg = f"maze_esp=>[remoteController_iphone3,ambianceManager]=>{message}"
        #self.send_message(msg)

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
                        
                        if "rfid#maze" in message:
                            # Reset button sequence when maze is activated
                            self.button_controller.reset_sequence()
                            
                        if "ping" in message.lower():
                            self.ws_client.process_message(ws, message)
                        else:
                            print(f"Received message: {message}")
                            
            except OSError as e:
                if e.args[0] != 11:  # Ignore EAGAIN errors
                    self.handle_websocket_error(ws_route, e)

    def start(self):
        print("Starting controller...")
        if not self.ws_client.connect_wifi():
            print("WiFi connection failed. Stopping.")
            return

        self.ws_client.connect_websockets()
        print("Waiting for maze activation...")

        while True:
            try:
                # Process message queue
                while self.message_queue:
                    msg = self.message_queue[0]
                    try:
                        self.send_message(msg)
                        self.message_queue.pop(0)
                    except:
                        break

                # Check WebSocket messages
                self.handle_websocket_messages()

                # Check RFID readers
                self.rfid.check_readers(
                    callback_entrance=self.handle_entrance_tag,
                    callback_exit=self.handle_exit_tag
                )

                # Check buttons
                self.button_controller.check_buttons(
                    callback_press=self.handle_button_press,
                    callback_release=self.handle_button_release,
                    server_message_callback=self.send_message
                )

                utime.sleep_ms(10)
                
            except Exception as e:
                print(f"General error: {e}")
                utime.sleep(5)
                self.__init__()
                self.start()

if __name__ == "__main__":
    controller = ESP32Controller()
    controller.start()