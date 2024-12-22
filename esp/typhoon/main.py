from machine import Pin
import utime
from libs.mfrc522 import MFRC522
from WSclient import WSclient
from WebSocketClient import WebSocketClient
from QuadrupleRelay import RelayController

class ESP32Controller:
    def __init__(self):
        # RFID readers (from DoubleRfid.py)
        self.reader1 = MFRC522(spi_id=0, sck=5, miso=16, mosi=17, cs=18, rst=4)
        self.reader2 = MFRC522(spi_id=1, sck=14, miso=26, mosi=27, cs=15, rst=10)
        self.previous_tag1 = False
        self.previous_tag2 = False

        # Relays (from QuadrupleRelay.py)
        self.relays = [
            RelayController(32),
            RelayController(33),
            RelayController(25),
            RelayController(26)
        ]

        # WebSocket (from WSclient.py)
        self.ws_client = WSclient("Cudy-F810", "13022495", "typhoon_esp")
        self.ws = None

        # LED indicator
        self.led = Pin(2, Pin.OUT)

    def start(self):
        print("Démarrage du contrôleur...")
        
        # Connexion WiFi et WebSocket
        if self.ws_client.connect_wifi():
            self.ws = WebSocketClient(f"ws://192.168.10.146:8080/typhoon_espConnect")
            if not self.ws.connect():
                print("Échec connexion WebSocket")
                return

        while True:
            try:
                # Vérification des messages WebSocket
                try:
                    data = self.ws.socket.recv(1)
                    if data:
                        message = self.ws.receive(first_byte=data)
                        if message:
                            # Traitement des commandes relais
                            if "#" in message:
                                cmd, state = message.split("#")
                                relay_num = int(cmd[-1]) - 1
                                if 0 <= relay_num <= 3:
                                    if state.lower() == "true":
                                        self.relays[relay_num].on()
                                    else:
                                        self.relays[relay_num].off()
                except:
                    pass

                # Vérification RFID 1 (Entrée)
                self.reader1.init()
                stat1, _ = self.reader1.request(self.reader1.REQIDL)
                if stat1 == self.reader1.OK and not self.previous_tag1:
                    if self.reader1.SelectTagSN()[0] == self.reader1.OK:
                        msg = "typhoon_esp=>[typhon_iphone]=>rfid#true"
                        self.ws.send(msg)
                        self.led.value(1)
                        utime.sleep_ms(100)
                        self.led.value(0)
                self.previous_tag1 = (stat1 == self.reader1.OK)

                # Vérification RFID 2 (Sortie)
                self.reader2.init()
                stat2, _ = self.reader2.request(self.reader2.REQIDL)
                if stat2 == self.reader2.OK and not self.previous_tag2:
                    if self.reader2.SelectTagSN()[0] == self.reader2.OK:
                        msg = "typhoon_esp=>[typhon_iphone]=>rfid#false"
                        self.ws.send(msg)
                        self.led.value(1)
                        utime.sleep_ms(100)
                        self.led.value(0)
                self.previous_tag2 = (stat2 == self.reader2.OK)

                utime.sleep_ms(100)

            except Exception as e:
                print(f"Erreur: {e}")
                # Tentative de reconnexion
                if self.ws:
                    self.ws.close()
                utime.sleep(5)
                self.__init__()

# Démarrage
if __name__ == "__main__":
    controller = ESP32Controller()
    controller.start()