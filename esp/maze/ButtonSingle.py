import machine
import utime

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

def main():
    # Create a button instance
    button = Button(pin_number=23, name="test_button")  # Replace with your GPIO pin number
    
    print("Monitoring button state...")
    
    while True:
        if button.update():
            if button.pressed:
                print(f"{button.name} pressed")
            if button.released:
                print(f"{button.name} released")
        
        # Small delay to prevent excessive CPU usage
        utime.sleep_ms(10)

# Run the main function
if __name__ == '__main__':
    main()
