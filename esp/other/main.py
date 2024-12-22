from machine import Pin, SoftI2C
from rfid_ESP32.rfid import RFIDTrigger
from BLE_ESP32.ble import Ble
import rfid_ESP32.libs.mfrc522 as mfrc522
import bluetooth
from led.led import Led
from btn.btn import Button
from pressFileManager.fileManager import ButtonPressCounter
import time
from pressFileManager.fileManager import ButtonPressCounter
from appointment.appointment import AppointmentManager
import json

base_time = time.time()  # Remplacez par votre temps de base

manager = AppointmentManager('appointments.json')
# Configuration RFID
mfrc_reader = mfrc522.MFRC522(5, 17, 16, 4, 18)
rfid_trigger = RFIDTrigger(mfrc_reader)
previous_state = False
consecutive_failures = 2

# Configuration Bluetooth
ble = bluetooth.BLE()
ble_obj = Ble(ble)
ble_obj.on_write(ble_obj.on_rx)
ble_obj.stop()

# Configuration LED et bouton
blue_pin_btn = Pin(27, Pin.OUT)
green_pin_btn = Pin(14, Pin.OUT)
red_pin_btn = Pin(26, Pin.OUT)
my_led_btn = Led(blue_pin_btn, green_pin_btn, red_pin_btn)


blue_pin_rappel = Pin(32, Pin.OUT)
green_pin_rappel = Pin(33, Pin.OUT)
red_pin_rappel = Pin(25, Pin.OUT)
my_led_rappel = Led(blue_pin_rappel, green_pin_rappel, red_pin_rappel)

my_button = Button(23)
button_status = False
start_time = 0
led_duration = 2  # Durée d'allumage de la LED en secondes
led_rappel_active = False
# Configuration gestionnaire de fichiers
file_name = 'button_press.json'
counter = ButtonPressCounter(file_name)

while True:
    ble_obj.on_write(ble_obj.on_rx)
    # Lecture RFID
    consecutive_failures = rfid_trigger.read(consecutive_failures)
    current_state = rfid_trigger.get_state()

    # Gestion du changement d'état du badge RFID
    if not current_state == previous_state:
        if current_state and not previous_state:
            print("Badge détecté !")
            
            # Effectuer les actions souhaitées pour le badge détecté (exécuté une seule fois)
            # Activer le Bluetooth
            ble_obj.start()
            print(current_state)
        elif not current_state and previous_state:
            print("Badge retiré !")
            # Effectuer les actions souhaitées pour le badge retiré (exécuté une seule fois)
            # Désactiver le Bluetooth
            ble_obj.stop()
        previous_state = current_state
    else:
        current_time = time.time()  # Calcul du temps actuel
        localtime = time.localtime(current_time)  # Convertir le temps actuel en une structure de temps locale
        next_time = base_time + 60  # Ajouter 60 secondes pour la prochaine minute

        if not time.time() < next_time:
            appointment_found = False
            # Extraire les éléments de la date de la structure de temps locale
            year = localtime[0]
            month = localtime[1]
            day = localtime[2]
            hour = localtime[3]
            minute = localtime[4]
            second = localtime[5]
            for i in range(minute, minute + 10):
                # Vérifier si le nombre de minutes dépasse 59
                if i > 59:
                    # Passer à l'heure suivante
                    hour += 1
                    i = i % 60

                # Vérifier si le changement d'heure nécessite un changement de jour
                if hour > 23:
                    # Passer au jour suivant
                    day += 1
                    hour = hour % 24

                # Vérifier s'il y a un rendez-vous à l'heure actuelle
                target_date = f"{year:04d}-{month:02d}-{day:02d} {hour:02d}:{i:02d}"
                appointment_exists = manager.check_appointment(target_date)

                if appointment_exists:
                    print(f"Un rendez-vous est prévu à la date {target_date}")
                    appointment_found = True

            if appointment_found:
                # Allumer la LED des rendez-vous en rouge si un rendez-vous a été trouvé
                if not led_rappel_active:
                    red_pin_rappel.on()
                    led_rappel_active = True
            else:
                # Éteindre la LED des rendez-vous si aucun rendez-vous n'a été trouvé
                if led_rappel_active:
                    red_pin_rappel.off()
                    led_rappel_active = False
            # Mettre à jour le temps de base pour la prochaine itération
            base_time = next_time

        if not button_status:
            button_status = my_button.check_status()
            if button_status:
                start_time = time.time()
                counter.add_button_press()  # Ajouter un appui sur le bouton dans le fichier
        else:
            print("Appui long détecté")
            my_led_btn.on_green()
            current_time = time.time()
            if current_time - start_time >= led_duration:
                my_led_btn.turn_off()
                button_status = False
    # Gestion des messages Bluetooth
    received_data = ble_obj.get_value()
    if received_data:
        message = received_data.strip()
        print("Message reçu :", message)
        time.sleep(0.1)
        # Vérifiez le contenu du message et répondez en conséquence
        if message == "Hello server!":
            ble_obj.response = "Hi client!"  # Stocke la réponse dans la variable
        elif message == "delete_data":
            counter.delete_button_press()  # Supprimer les informations du fichier
            ble_obj.response = "Data deleted"
        elif message == "Waiting Data":
            try:
                data = counter.read_data()
                if data is not None:
                    count = data['count']
                    ble_obj.response = f"pressed_value: {count}"
                else:
                    ble_obj.response = "No data available"
            except:
                ble_obj.response = "No data available"
        elif message == "Data retrieved":
            pass
        else:
            ble_obj.response = "Unknown command"

        if ble_obj.response is not None:
            ble_obj.send(ble_obj.response)  # Envoie la réponse via BLE
            print("Réponse envoyée :", ble_obj.response)
            ble_obj.response = None  # Réinitialise la variable de réponse

    if ble_obj.is_connected():
        # Attendez un court instant avant d'envoyer un message
        time.sleep(0.1)
        message = "Server message"
        print("Message envoyé :", message)
        ble_obj.send(message.encode())  # Envoyer un message au client connecté


