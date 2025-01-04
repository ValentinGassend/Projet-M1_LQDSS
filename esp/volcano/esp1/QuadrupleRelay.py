from machine import Pin
from time import sleep

class RelayController:
    def __init__(self, pin_number, active_low=True):
        """
        Initialize the relay controller.
        
        :param pin_number: GPIO pin number for the relay
        :param active_low: Whether the relay is activated by a low signal (default True)
        """
        self.relay = Pin(pin_number, Pin.OUT)
        self.active_low = active_low
        # Ensure relay starts in OFF state
        self.off()
    
    def on(self):
        """Turn the relay ON"""
        if self.active_low:
            self.relay.value(0)
        else:
            self.relay.value(1)
    
    def off(self):
        """Turn the relay OFF"""
        if self.active_low:
            self.relay.value(1)
        else:
            self.relay.value(0)
    
    def toggle(self):
        """Toggle the relay state"""
        current_state = self.relay.value()
        self.relay.value(1 - current_state)
    
    def pulse(self, on_time=1, off_time=10):
        """
        Pulse the relay on and off.
        
        :param on_time: Duration the relay stays ON (in seconds)
        :param off_time: Duration the relay stays OFF (in seconds)
        """
        self.on()
        sleep(on_time)
        self.off()
        sleep(off_time)

def sequential_relay_control():
    # Create relay controllers for multiple pins
    relays = [
        RelayController(32),  # First relay
        RelayController(33),  # Second relay
        RelayController(25),  # Third relay
        RelayController(26)   # Fourth relay
    ]
    
    while True:
        # Sequentially activate relays
        for relay in relays:
            relay.on()
            sleep(2)  # Keep each relay on for 2 seconds
        
        # Sequentially deactivate relays
        for relay in reversed(relays):
            relay.off()
            sleep(2)  # Wait 2 seconds after turning each relay off
