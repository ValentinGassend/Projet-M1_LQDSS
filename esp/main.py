from machine import Pin, SPI
from libs.mfrc522 import MFRC522
import utime
from WSclient import WSclient

class RFIDReader:
    def __init__(self, name, spi_id, sck, miso, mosi, cs, rst):
        self.name = name
        self.reader = MFRC522(spi_id=spi_id, sck=sck, miso=miso, mosi=mosi, cs=cs, rst=rst)
        self.previous_tag_detected = False

    def detect_tag(self):
        try:
            self.reader.init()
            (stat, tag_type) = self.reader.request(self.reader.REQIDL)
            
            if stat == self.reader.OK:
                print(f"[{self.name}] Tag detected!")
                (stat, uid) = self.reader.SelectTagSN()
                if stat == self.reader.OK:
                    card = int.from_bytes(bytes(uid), "little", False)
                    print(f"[{self.name}] Card UID: {card}")
                    return card
                else:
                    print(f"[{self.name}] Failed to read UID.")
            else:
                print(f"[{self.name}] No tag detected.")
        except Exception as e:
            print(f"[{self.name}] Error: {e}")
        return None


class RFIDSystem:
    def __init__(self, ssid, password, websocket_url):
        # Initialize WebSocket client
        self.ws_client = WSclient(ssid, password, websocket_url)
        
        # Initialize two RFID readers with different SPI configurations
        self.reader1 = RFIDReader(
            name="READER_ENTRANCE", 
            spi_id=0, 
            sck=5, 
            miso=16, 
            mosi=17, 
            cs=18, 
            rst=4
        )
        
        self.reader2 = RFIDReader(
            name="READER_EXIT", 
            spi_id=1,  # Different SPI bus 
            sck=14,     # Different pin for SCK 
            miso=12,    # Different pin for MISO
            mosi=13,    # Different pin for MOSI
            cs=15,      # Different pin for CS
            rst=10     # Different pin for RST
        )
        
        # LED for status indication
        self.led = Pin(2, Pin.OUT)
        
        # WebSocket connection
        self.ws = None

    def setup_connection(self):
        try:
            if self.ws_client.connect_wifi():
                ws = WebSocketClient(self.ws_client.WEBSOCKET_URL)
                if ws.connect():
                    print("WebSocket connection established")
                    return ws
            print("Failed to establish connection")
            return None
        except Exception as e:
            print(f"Connection error: {e}")
            return None

    def send_message(self, reader_name, card_info):
        if not self.ws:
            self.ws = self.setup_connection()
        
        if self.ws:
            try:
                # Create message with reader name and card info
                if card_info == "REMOVED":
                    message = f"{reader_name}:TAG_REMOVED"
                else:
                    message = f"{reader_name}:TAG_DETECTED:{card_info}"
                
                if self.ws.send(message):
                    print(f"Sent message: {message}")
                    # Blink LED to confirm send
                    self.led.value(1)
                    utime.sleep_ms(200)
                    self.led.value(0)
                    return True
                else:
                    print("Failed to send message")
                    self.ws = self.setup_connection()
                    return False
            except Exception as e:
                print(f"Send error: {e}")
                self.ws = self.setup_connection()
                return False
        return False

    def run(self):
        print("RFID Readers Ready. Bring tags closer...")
        
        try:
            while True:
                # Check Reader 1
                tag1 = self.reader1.detect_tag()
                if tag1 is not None:
                    self.send_message(self.reader1.name, tag1)
                
                # Check Reader 2
                tag2 = self.reader2.detect_tag()
                if tag2 is not None:
                    self.send_message(self.reader2.name, tag2)
                
                # Small delay to prevent excessive polling
                utime.sleep_ms(50)

        except KeyboardInterrupt:
            print("RFID Monitoring Stopped")
        finally:
            # Ensure WebSocket is closed
            if self.ws:
                self.ws.close()

# Usage
if __name__ == "__main__":
    rfid_system = RFIDSystem(
        ssid="Cudy-F810", 
        password="13022495", 
        websocket_url="ws://192.168.10.146:8080/rpiConnect"
    )
    rfid_system.run()