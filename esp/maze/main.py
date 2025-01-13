from machine import Pin
import utime
from WSclient import WSclient
from DoubleRfid import RFIDController

class Button:
    """A single button implementation with debounce"""
    def __init__(self, pin_number, name, pull_up=True, debounce_time=50):
        if pull_up:
            self.pin = Pin(pin_number, Pin.IN, Pin.PULL_UP)
        else:
            self.pin = Pin(pin_number, Pin.IN)
        
        self.name = name
        self.debounce_time = debounce_time
        self.last_state = self.pin.value()
        self.last_debounce_time = 0
        self.current_state = self.last_state
        self.pressed = False
        self.released = False

    def update(self):
        """Update button state with debounce logic"""
        reading = self.pin.value()
        current_time = utime.ticks_ms()
        
        if reading != self.last_state:
            self.last_debounce_time = current_time
            
        if utime.ticks_diff(current_time, self.last_debounce_time) > self.debounce_time:
            if reading != self.current_state:
                self.current_state = reading
                self.pressed = (self.current_state == 0)  # Active low with pull-up
                self.released = (self.current_state == 1)
                return True
                
        self.last_state = reading
        return False

class ButtonController:
    """Manages multiple buttons using the improved single button implementation"""
    def __init__(self):
        self.buttons = {}
        # Track button activation states
        self.button_states = {
            "btn1": False,
            "btn2": False,
            "btn3": False
        }
        self.btn1_locked = False
        
    def add_button(self, pin_number, button_name):
        """Add a new button with the improved implementation"""
        button = Button(pin_number, button_name)
        self.buttons[button_name] = button
        return button
        
    def can_activate_button(self, button_name):
        """Check if a button can be activated based on sequence rules"""
        if button_name == "btn1" and self.btn1_locked:
            # btn1 can only be activated if both btn2 and btn3 have been activated
            return self.button_states["btn2"] and self.button_states["btn3"]
        return True
        
    def check_buttons(self, callback_press=None, callback_release=None):
        """Check all buttons and trigger callbacks when state changes"""
        for name, button in self.buttons.items():
            if button.update():
                if button.pressed:
                    if self.can_activate_button(name):
                        if callback_press:
                            callback_press(name)
                            self.button_states[name] = True
                            if name == "btn1":
                                self.btn1_locked = True
                    else:
                        print(f"{name} is locked - activate other buttons first")
                elif button.released and callback_release:
                    callback_release(name)
                        
    def reset_sequence(self):
        """Reset the button sequence"""
        self.button_states = {
            "btn1": False,
            "btn2": False,
            "btn3": False
        }
        self.btn1_locked = False

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
        self.reconnect_interval = 10  # 1 second in milliseconds
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
            msg = "maze_esp=>[maze_iphone,maze_esp,ambianceManager_rpi]=>rfid#maze"
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

    def handle_button_press(self, button_name):
        msg = f"maze_esp=>[maze_iphone]=>{button_name}#true"
        self.send_message(msg)

    def handle_button_release(self, button_name):
        msg = f"maze_esp=>[maze_iphone]=>{button_name}#false"
        self.send_message(msg)

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
                    callback_release=self.handle_button_release
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