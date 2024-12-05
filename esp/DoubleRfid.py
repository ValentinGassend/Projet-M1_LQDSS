from machine import Pin
from libs.mfrc522 import MFRC522
import utime
from WSclient import WSclient  # Import your WebSocket client class
from WebSocketClient import WebSocketClient

# Initialize WebSocket client
ws_client = WSclient("Cudy-F810", "13022495", "ws://192.168.10.146:8080/rpiConnect")

# Attempt to connect WiFi and WebSocket
def setup_connection():
    try:
        if ws_client.connect_wifi():
            ws = WebSocketClient(ws_client.WEBSOCKET_URL)
            if ws.connect():
                print("WebSocket connection established")
                return ws
        print("Failed to establish connection")
        return None
    except Exception as e:
        print(f"Connection error: {e}")
        return None

# Initialize two RFID readers with different SPI configurations
reader1 = MFRC522(spi_id=0, sck=5, miso=16, mosi=17, cs=18, rst=4)
reader2 = MFRC522(spi_id=1, sck=14, miso=26, mosi=27, cs=15, rst=10)

# LED for status indication
led = Pin(2, Pin.OUT)

# Variables to track the previous tag states
previous_tag_detected1 = False
previous_tag_detected2 = False

print("RFID Readers Ready. Bring TAGs closer...")
print(f"Reader1 SPI Config: spi_id=0, sck=5, miso=16, mosi=17, cs=18, rst=4")
print(f"Reader2 SPI Config: spi_id=1, sck=14, miso=12, mosi=13, cs=15, rst=10")

# Establish WebSocket connection
ws = setup_connection()

try:
    while True:
        # Check Reader 1
        reader1.init()
        (stat1, tag_type1) = reader1.request(reader1.REQIDL)
        current_tag_detected1 = stat1 == reader1.OK
        
        # Extensive debugging for Reader 1
        print(f"Reader1 Status: {stat1}, Type: {tag_type1}, Detected: {current_tag_detected1}")

        if current_tag_detected1 and not previous_tag_detected1:
            (stat1, uid1) = reader1.SelectTagSN()
            print(f"Reader1 Select Tag Status: {stat1}")
            
            if stat1 == reader1.OK:
                card1 = int.from_bytes(bytes(uid1), "little", False)
                print("ENTRANCE TAG DETECTED - CARD ID: " + str(card1))
                
                # Send card ID via WebSocket
                if ws:
                    try:
                        message = f"READER_ENTRANCE:TAG_DETECTED:{card1}"
                        if ws.send(message):
                            print(f"Sent message: {message}")
                            led.value(1)
                            utime.sleep_ms(200)
                            led.value(0)
                        else:
                            print("Failed to send message")
                            ws = setup_connection()
                    except Exception as e:
                        print(f"Send error: {e}")
                        ws = setup_connection()
        
        # Check Reader 2
        reader2.init()
        (stat2, tag_type2) = reader2.request(reader2.REQIDL)
        current_tag_detected2 = stat2 == reader2.OK
        
        # Extensive debugging for Reader 2
        print(f"Reader2 Status: {stat2}, Type: {tag_type2}, Detected: {current_tag_detected2}")

        if current_tag_detected2 and not previous_tag_detected2:
            (stat2, uid2) = reader2.SelectTagSN()
            print(f"Reader2 Select Tag Status: {stat2}")
            
            if stat2 == reader2.OK:
                card2 = int.from_bytes(bytes(uid2), "little", False)
                print("EXIT TAG DETECTED - CARD ID: " + str(card2))
                
                # Send card ID via WebSocket
                if ws:
                    try:
                        message = f"READER_EXIT:TAG_DETECTED:{card2}"
                        if ws.send(message):
                            print(f"Sent message: {message}")
                            led.value(1)
                            utime.sleep_ms(200)
                            led.value(0)
                        else:
                            print("Failed to send message")
                            ws = setup_connection()
                    except Exception as e:
                        print(f"Send error: {e}")
                        ws = setup_connection()
        
        # Update the previous states
        previous_tag_detected1 = current_tag_detected1
        previous_tag_detected2 = current_tag_detected2
        
        # Slightly longer delay to reduce CPU load
        utime.sleep_ms(100)

except KeyboardInterrupt:
    print("RFID Monitoring Stopped")
finally:
    # Ensure WebSocket is closed
    if ws:
        ws.close()