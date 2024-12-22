import bluetooth
import time
from BLE_ESP32.ble_simple_peripheral import BLESimplePeripheral

class Ble(BLESimplePeripheral):
    def __init__(self, ble, name="Liveo"):
        self.ble = ble
        self.name = name
        super().__init__(self.ble, self.name)
        self.value = False
        self.connected = False  # Ajoute l'attribut connected
        self.response = None  # Variable pour stocker la réponse
        self.advertising_started = False  # Ajoute l'attribut advertising_started

    def on_rx(self, v):
        message = v.decode()  # Décode les octets en utilisant l'encodage UTF-8
        print("Message reçu :", message)
        self.value = message

    def get_value(self):
        sended_value = self.value
        if sended_value:
            self.value = False  # Réinitialise la valeur
            return sended_value

    def is_connected(self):
        return self.connected
    
    def on_connect(self, client_config):
        self.connected = True
    
    def on_disconnect(self, client_config):
        self.connected = False

    def start(self):
#         self.ble.active(True)
#         self.ble.gap_advertise(0, adv_data=self._payload)
        super().__init__(self.ble, self.name)

    def stop(self):
        self.ble.active(False)
