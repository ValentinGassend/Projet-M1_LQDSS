import RPi.GPIO as GPIO
from mfrc522 import SimpleMFRC522
from time import sleep

# Initialisation du module RFID
reader = SimpleMFRC522()

# Dictionnaire des badges avec leurs éléments associés
elements = {
    81773571232: "feu",  # Remplacez les IDs par les IDs réels des badges
    428429715043: "eau",
    
}

# Liste des badges scannés
badges_scannes = set()

try:
    while True:
        print("Placer votre carte")
        id, text = reader.read()
        
        if id is not None:
            print("ID: %s\nText: %s" % (id, text))
            
            # Vérification si l'ID lu est dans le dictionnaire
            if id in elements:
                element = elements[id]
                print(f"Badge détecté : {element}")
                
                # Ajouter l'élément scanné à la liste des badges scannés
                badges_scannes.add(element)
                print(f"Badges scannés actuellement : {badges_scannes}")
                
                # Vérification si tous les éléments ont été scannés
                if set(elements.values()) == badges_scannes:
                    print("Tous les badges ont été scannés ! État : True")
                    badges_scannes.clear()  # Réinitialiser après validation
            else:
                print("Badge non reconnu.")
            
            sleep(2)  # Temps d'attente pour éviter les doubles lectures
except KeyboardInterrupt:
    print("Exiting...")
    GPIO.cleanup()
