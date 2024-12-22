from BLE_ESP32.ble import Ble
import bluetooth
import time

ble = bluetooth.BLE()
ble_obj = Ble(ble)
ble_obj.on_write(ble_obj.on_rx)
ble_obj.stop()

while True:
    received_data = ble_obj.get_value()
    if received_data:
        message = received_data.strip()
        print("Message reçu :", message)
        time.sleep(0.1)
        # Vérifiez le contenu du message et répondez en conséquence
        if message == "Hello server!":
            ble_obj.response = "Hi client!"  # Stocke la réponse dans la variable
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

