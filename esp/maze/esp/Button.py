import machine
import utime

class Button:
    """
    A class to handle individual button interactions with debounce
    """
    def __init__(self, pin_number, name, pull_up=True, debounce_time=0):
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
        
        self.name = name
        self.debounce_time = debounce_time
        self.last_state = self.pin.value()
        self.last_debounce_time = 0
        self.current_state = self.last_state
        self.state_changed = False

    def check(self):
        """
        Check button state with debounce logic
        
        Returns:
            bool or None: True if pressed, False if released, None if no change
        """
        reading = self.pin.value()
        current_time = utime.ticks_ms()
        state_to_return = None
        
        # Si l'état a changé, mettre à jour le temps de debounce
        if reading != self.last_state:
            self.last_debounce_time = current_time
        
        # Vérifier si le temps de debounce est passé
        if utime.ticks_diff(current_time, self.last_debounce_time) > self.debounce_time:
            # Si l'état est différent de l'état courant
            if reading != self.current_state:
                self.current_state = reading
                # Renvoyer True pour appuyé (0 car pull-up), False pour relâché (1)
                state_to_return = (self.current_state == 0)
                
        self.last_state = reading
        return state_to_return

class ButtonController:
    """
    Manages multiple buttons
    """
    def __init__(self):
        """
        Initialize button controller
        """
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

    def check_buttons(self, callback_press=None, callback_release=None):
        """
        Check all buttons and trigger callbacks immediately
        
        Args:
            callback_press (function): Callback function for button press
            callback_release (function): Callback function for button release
        """
        for name, button in self.buttons.items():
            state = button.check()
            if state is not None:  # Si un changement d'état est détecté
                if state and callback_press:  # True = Bouton appuyé
                    callback_press(name)
                elif not state and callback_release:  # False = Bouton relâché
                    callback_release(name)