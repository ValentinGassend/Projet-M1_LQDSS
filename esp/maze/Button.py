import machine
import utime
from WSclient import WSclient
from WebSocketClient import WebSocketClient

class Button:
    """
    A class to handle individual button interactions with debounce
    """
    def __init__(self, pin_number, name, pull_up=True, debounce_time=50):
        """
        Initialize a button
        
        Args:
            pin_number (int): GPIO pin number for the button
            name (str): Unique name/identifier for the button
            pull_up (bool): Use internal pull-up resistor
            debounce_time (int): Debounce time in milliseconds
        """
        # Configure pin mode
        if pull_up:
            self.pin = machine.Pin(pin_number, machine.Pin.IN, machine.Pin.PULL_UP)
        else:
            self.pin = machine.Pin(pin_number, machine.Pin.IN)
        
        # Button identification
        self.name = name
        
        # Debounce variables
        self.debounce_time = debounce_time
        self.last_state = self.pin.value()
        self.last_debounce_time = 0
        
        # State tracking
        self.current_state = self.last_state
        self.pressed = False
        self.released = False

    def update(self):
        """
        Update button state with debounce logic
        
        Returns:
            bool: True if button state changed
        """
        reading = self.pin.value()
        current_time = utime.ticks_ms()

        # Debounce logic
        if reading != self.last_state:
            self.last_debounce_time = current_time

        # Check if debounce time has passed
        if (utime.ticks_diff(current_time, self.last_debounce_time) > self.debounce_time):
            # State change detection
            if reading != self.current_state:
                self.current_state = reading
                
                # Determine press/release
                self.pressed = (self.current_state == 0)  # Assumes active low
                self.released = (self.current_state == 1)
                
                return True

        self.last_state = reading
        return False

class WebSocketManager:
    """
    Manages WebSocket connection and message sending
    """
    def __init__(self, wifi_ssid, wifi_password, websocket_url):
        """
        Initialize WebSocket connection
        
        Args:
            wifi_ssid (str): WiFi network name
            wifi_password (str): WiFi password
            websocket_url (str): WebSocket server URL
        """
        self.ws_client = WSclient(wifi_ssid, wifi_password, websocket_url)
        self.ws = None
        self.connected = False

    def connect(self):
        """
        Establish WiFi and WebSocket connections
        
        Returns:
            bool: Connection status
        """
        try:
            # Connect to WiFi
            if self.ws_client.connect_wifi():
                # Establish WebSocket connection
                self.ws = WebSocketClient(self.ws_client.WEBSOCKET_URL)
                if self.ws.connect():
                    print("WebSocket connection established")
                    self.connected = True
                    return True
            
            print("Failed to establish connection")
            self.connected = False
            return False
        
        except Exception as e:
            print(f"Connection error: {e}")
            self.connected = False
            return False

    def send_message(self, message):
        """
        Send a message via WebSocket
        
        Args:
            message (dict): Message to send
        """
        if not self.connected:
            # Try to reconnect if not connected
            self.connect()
        
        if self.connected and self.ws:
            try:
                # Convert message to string and send
                self.ws.send(str(message))
                print(f"Sent message: {message}")
            except Exception as e:
                print(f"WebSocket send error: {e}")
                self.connected = False

class ButtonController:
    """
    Manages multiple buttons and their WebSocket messaging
    """
    def __init__(self, wifi_ssid, wifi_password, websocket_url):
        """
        Initialize button controller with WebSocket support
        
        Args:
            wifi_ssid (str): WiFi network name
            wifi_password (str): WiFi password
            websocket_url (str): WebSocket server URL
        """
        # Create WebSocket manager
        self.websocket_manager = WebSocketManager(
            wifi_ssid, 
            wifi_password, 
            websocket_url
        )
        
        # Dictionary to store buttons
        self.buttons = {}

    def add_button(self, pin_number, button_name):
        """
        Add a new button to the controller
        
        Args:
            pin_number (int): GPIO pin number
            button_name (str): Unique name for the button
        
        Returns:
            Button: Created button instance
        """
        button = Button(pin_number, button_name)
        self.buttons[button_name] = button
        return button

    def run(self):
        """
        Main loop to monitor buttons and send WebSocket messages
        """
        # Establish initial connection
        self.websocket_manager.connect()
        
        print("Button monitoring started...")
        
        while True:
            try:
                # Check each button
                for name, button in self.buttons.items():
                    if button.update():
                        # Button state changed
                        if button.pressed:
                            # Prepare and send WebSocket message for button press
                            message = {
                                "type": "button_press",
                                "button": name
                            }
                            self.websocket_manager.send_message(message)
                        
                        if button.released:
                            # Prepare and send WebSocket message for button release
                            message = {
                                "type": "button_release",
                                "button": name
                            }
                            self.websocket_manager.send_message(message)
                
                # Small delay to prevent excessive CPU usage
                utime.sleep_ms(10)
            
            except Exception as e:
                print(f"Error in main loop: {e}")
                # Attempt to reconnect
                self.websocket_manager.connect()

def main():
    # Create button controller with WiFi and WebSocket details
    controller = ButtonController(
        wifi_ssid="Cudy-F810",      # Replace with your WiFi SSID
        wifi_password="13022495",   # Replace with your WiFi password
        websocket_url="ws://192.168.10.146:8080/rpiConnect"  # Replace with your WebSocket server URL
    )

    # Add buttons
    controller.add_button(23, "red_button")
    controller.add_button(27, "blue_button")
    controller.add_button(14, "green_button")

    # Start monitoring and sending messages
    controller.run()

# Run the main function
if __name__ == '__main__':
    main()