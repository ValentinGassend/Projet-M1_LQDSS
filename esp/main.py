from machine import Pin
from libs.mfrc522 import MFRC522
import utime

reader = MFRC522(spi_id=0, sck=5, miso=16, mosi=17, cs=18, rst=4)
led = Pin(2, Pin.OUT)

# Variable to track the previous tag state
previous_tag_detected = False

print("Bring TAG closer...")
print("")

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
                # You can add any specific action for first detection here
        
        # Detect tag removal
        elif not current_tag_detected and previous_tag_detected:
            print("TAG REMOVED")
            # You can add any specific action for tag removal here
        
        # Update the previous state
        previous_tag_detected = current_tag_detected
        
        utime.sleep_ms(50)  # Short delay to prevent excessive polling

except KeyboardInterrupt:
    print("Bye")