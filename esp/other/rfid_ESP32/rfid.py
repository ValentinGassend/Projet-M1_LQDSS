class RFIDTrigger:
    def __init__(self, mfrc_reader):
        self.MIFAREReader = mfrc_reader
        self.state = False

    def check_detection(self):
        while True:
            (status, tag_type) = self.MIFAREReader.request(self.MIFAREReader.REQIDL)
            if status == self.MIFAREReader.OK:
                (status, raw_uid) = self.MIFAREReader.anticoll()
                if status == self.MIFAREReader.OK:
#                     print("Badge détecté !")
                    self.state = True
                    return
                else:
                    self.state = False
            else:
                self.state = False

    def read(self,consecutive_failures):
        (status, tag_type) = self.MIFAREReader.request(self.MIFAREReader.REQIDL)
        if status == self.MIFAREReader.OK:
            (status, raw_uid) = self.MIFAREReader.anticoll()
            if status == self.MIFAREReader.OK:
                self.state = True
                consecutive_failures = 0
            else:
                self.state = False
                consecutive_failures += 1
        else:
            consecutive_failures += 1
            if consecutive_failures >= 2:
                self.state = False
        return consecutive_failures


    def end_read(self):
        self.state = False

    def get_state(self):
        return self.state