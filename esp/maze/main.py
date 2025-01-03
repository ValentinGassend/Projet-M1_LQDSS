from machine import Pin
import utime
from WSclient import WSclient
from DoubleRfid import RFIDController
from Button import ButtonController

class ESP32Controller:
    def __init__(self):
        # RFID Controller
        self.rfid = RFIDController()
        # WebSocket client
        self.ws_client = WSclient("Cudy-F810", "13022495", "maze_esp")
        # Button Controller
        self.button_controller = ButtonController()
        
        
        self.controller = ButtonController()
        self.controller.add_button(23, "btn1")
        self.controller.add_button(27, "btn2")
        self.controller.add_button(14, "btn3")
        # Add buttons

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
            
    def handle_entrance_tag(self, card_id):
        """Callback for entrance RFID detection"""
        msg = f"maze_esp=>[maze_iphone]=>rfid#fire"
        print(f"Sending RFID entrance message: {msg}")
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_exit_tag(self, card_id):
        """Callback for exit RFID detection"""
        msg = f"maze_esp=>[maze_iphone]=>rfid#first"
        print(f"Sending RFID exit message: {msg}")
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_button_press(self, button_name):
        """Handle button press events"""
        msg = f"maze_esp=>[maze_iphone]=>{button_name}#true"
        print(f"Button {button_name} pressed, sending message: {msg}")
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_button_release(self, button_name):
        """Handle button press events"""
        msg = f"maze_esp=>[maze_iphone]=>{button_name}#false"
        print(f"Button {button_name} pressed, sending message: {msg}")
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
                        
                        # Check if message contains "ping"
                        if "ping" in message.lower():
                            # Forward ping messages directly to process_message
                            self.ws_client.process_message(ws, message)
                        else:
                            # Handle other messages here if needed
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

        while True:
            try:
                # Check WebSocket messages
                self.handle_websocket_messages()
                
                # Check RFID readers
                self.rfid.check_readers(
                    callback_entrance=self.handle_entrance_tag,
                    callback_exit=self.handle_exit_tag
                )
                
                # Check buttons and handle presses
                self.controller.check_buttons(callback_press=self.handle_button_press, callback_release=self.handle_button_release)
                
                utime.sleep_ms(100)
            except Exception as e:
                print(f"General error: {e}")
                utime.sleep(5)
                self.__init__()  # Reset controller
                self.start()

if __name__ == "__main__":
    controller = ESP32Controller()
    controller.start()