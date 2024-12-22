from machine import Pin
from time import time


class Button:
    def __init__(self, button_pin):
        self.button = Pin(button_pin, Pin.IN)
        self.last_state = False
        self.started_time = 0
        self.enabled = True

    def check_status(self, threshold=2):
        if self.button.value() == 1:
            if not self.enabled:
                return False
            if not self.last_state:
                self.started_time = time()
            self.last_state = True
            pressed_time = time() - self.started_time
            if pressed_time >= threshold:
                self.enabled = False
                return True
        else:
            self.last_state = False
            self.enabled = True
        return False