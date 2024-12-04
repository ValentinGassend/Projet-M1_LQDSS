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

# Initialize components
reader = MFRC522(spi_id=0, sck=5, miso=16, mosi=17, cs=18, rst=4)
led = Pin(2, Pin.OUT)

# Variable to track the previous tag state
previous_tag_detected = False
print("Bring TAG closer...")
print("")

# Establish WebSocket connection
ws = setup_connection()

try:
    while True:
        reader.init()
        (stat, tag_type) = reader.request(reader.REQIDL)
        
        # Check if a tag is currently detected
        current_tag_detected = (stat == reader.OK)
        
        # Detect tag first detection
        if current_tag_detected and not previous_tag_detected:
            (stat, uid) = reader.SelectTagSN()
            if stat == reader.OK:
                card = int.from_bytes(bytes(uid), "little", False)
                print("TAG FIRST DETECTED - CARD ID: " + str(card))
                
                # Send card ID via WebSocket
                if ws:
                    try:
                        message = f"TAG_DETECTED:{card}"
                        if ws.send(message):
                            print(f"Sent message: {message}")
                            led.value(1)  # Optional: Blink LED to confirm send
                            utime.sleep_ms(200)
                            led.value(0)
                        else:
                            print("Failed to send message")
                            # Attempt to reconnect if sending fails
                            ws = setup_connection()
                    except Exception as e:
                        print(f"Send error: {e}")
                        ws = setup_connection()
        
        # Detect tag removal
        elif not current_tag_detected and previous_tag_detected:
            print("TAG REMOVED")
            if ws:
                try:
                    message = "TAG_REMOVED"
                    if ws.send(message):
                        print(f"Sent message: {message}")
                    else:
                        print("Failed to send removal message")
                        ws = setup_connection()
                except Exception as e:
                    print(f"Send error: {e}")
                    ws = setup_connection()
        
        # Update the previous state
        previous_tag_detected = current_tag_detected
        
        utime.sleep_ms(50)  # Short delay to prevent excessive polling

except KeyboardInterrupt:
    print("Bye")
finally:
    # Ensure WebSocket is closed
    if ws:
        ws.close()