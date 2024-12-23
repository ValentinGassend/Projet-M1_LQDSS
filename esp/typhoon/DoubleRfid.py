from machine import Pin
from libs.mfrc522 import MFRC522
import utime

class RFIDController:
    def __init__(self):
        # Initialize two RFID readers with different SPI configurations
        self.reader1 = MFRC522(spi_id=0, sck=5, miso=16, mosi=17, cs=18, rst=4)
        self.reader2 = MFRC522(spi_id=1, sck=14, miso=26, mosi=27, cs=15, rst=10)
        
        # LED for status indication
        self.led = Pin(2, Pin.OUT)
        
        # Variables to track the previous tag states
        self.previous_tag_detected1 = False
        self.previous_tag_detected2 = False
        
        print("RFID Readers Ready. Bring TAGs closer...")
        print(f"Reader1 SPI Config: spi_id=0, sck=5, miso=16, mosi=17, cs=18, rst=4")
        print(f"Reader2 SPI Config: spi_id=1, sck=14, miso=26, mosi=27, cs=15, rst=10")

    def check_readers(self, callback_entrance=None, callback_exit=None):
        """
        Check both RFID readers and call appropriate callbacks when tags are detected
        
        Args:
            callback_entrance: Function to call when entrance tag is detected
            callback_exit: Function to call when exit tag is detected
        """
        # Check Reader 1 (Entrance)
        self.reader1.init()
        stat1, tag_type1 = self.reader1.request(self.reader1.REQIDL)
        current_tag_detected1 = stat1 == self.reader1.OK
        
        if current_tag_detected1 and not self.previous_tag_detected1:
            stat1, uid1 = self.reader1.SelectTagSN()
            if stat1 == self.reader1.OK:
                card1 = int.from_bytes(bytes(uid1), "little", False)
                print("ENTRANCE TAG DETECTED - CARD ID: " + str(card1))
                if callback_entrance:
                    callback_entrance(card1)
                self.blink_led()

        # Check Reader 2 (Exit)
        self.reader2.init()
        stat2, tag_type2 = self.reader2.request(self.reader2.REQIDL)
        current_tag_detected2 = stat2 == self.reader2.OK
        
        if current_tag_detected2 and not self.previous_tag_detected2:
            stat2, uid2 = self.reader2.SelectTagSN()
            if stat2 == self.reader2.OK:
                card2 = int.from_bytes(bytes(uid2), "little", False)
                print("EXIT TAG DETECTED - CARD ID: " + str(card2))
                if callback_exit:
                    callback_exit(card2)
                self.blink_led()
        
        # Update the previous states
        self.previous_tag_detected1 = current_tag_detected1
        self.previous_tag_detected2 = current_tag_detected2
        
        # Return current states
        return current_tag_detected1, current_tag_detected2

    def blink_led(self):
        """Blink the status LED"""
        self.led.value(1)
        utime.sleep_ms(200)
        self.led.value(0)