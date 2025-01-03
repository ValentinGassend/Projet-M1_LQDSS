import machine
import utime

class Button:
    """
    A class to handle individual button interactions with debounce
    """
    def __init__(self, pin_number, name, pull_up=True, debounce_time=50):
        if pull_up:
            self.pin = machine.Pin(pin_number, machine.Pin.IN, machine.Pin.PULL_UP)
        else:
            self.pin = machine.Pin(pin_number, machine.Pin.IN)
        
        self.name = name
        self.debounce_time = debounce_time
        self.last_state = self.pin.value()
        self.last_debounce_time = 0
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

        # Reset press/release flags
        self.pressed = False
        self.released = False

        if reading != self.last_state:
            self.last_debounce_time = current_time

        if (utime.ticks_diff(current_time, self.last_debounce_time) > self.debounce_time):
            if reading != self.current_state:
                self.current_state = reading
                self.pressed = (self.current_state == 0)
                self.released = (self.current_state == 1)
                return True

        self.last_state = reading
        return False

class ButtonController:
    """
    Manages multiple buttons without blocking
    """
    def __init__(self):
        self.buttons = {}

    def add_button(self, pin_number, button_name):
        """
        Add a new button to the controller
        """
        button = Button(pin_number, button_name)
        self.buttons[button_name] = button
        return button

    def check_buttons(self, callback_press=None, callback_release=None):
        """
        Check button states once without blocking
        """
        for name, button in self.buttons.items():
            if button.update():
                if button.pressed and callback_press:
                    callback_press(name)
                if button.released and callback_release:
                    callback_release(name)