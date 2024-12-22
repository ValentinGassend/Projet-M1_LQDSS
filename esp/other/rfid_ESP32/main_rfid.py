from rfid_ESP32.rfid import RFIDTrigger
import rfid_ESP32.libs.mfrc522 as mfrc522
mfrc_reader = mfrc522.MFRC522(5, 17, 16, 4, 18)
rfid_trigger = RFIDTrigger(mfrc_reader)

previous_state = False

while True:
    rfid_trigger.check_detection()
    current_state = rfid_trigger.get_state()

    if current_state and not previous_state:
        pass
        # Effectuer les actions souhaitées pour le badge détecté (exécuté une seule fois)
        # ...

    if not current_state and previous_state:
        print("Badge retiré !")
        # Effectuer les actions souhaitées pour le badge retiré (exécuté une seule fois)
        # ...

    previous_state = current_state