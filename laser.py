import RPi.GPIO as GPIO
import time

# Configuration des broches
LASER_SENSOR_PIN = 18  # Modifier selon la broche utilisée

# Configuration de la bibliothèque GPIO
GPIO.setmode(GPIO.BCM)  # Numérotation BCM des broches
GPIO.setup(LASER_SENSOR_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

try:
    print("Surveillance du capteur photosensible...")
    while True:
        sensor_state = GPIO.input(LASER_SENSOR_PIN)
        print(f"État du capteur : {sensor_state}")  # Affiche l'état brut
        if sensor_state == GPIO.HIGH:  # Pas de signal détecté
            print("ATTENTION : Laser hors ligne de visée !")
        else:  # Signal laser détecté
            print("Laser aligné.")
        time.sleep(1)  # Pause pour observer les changements
except KeyboardInterrupt:
    print("\nArrêt du programme.")
finally:
    GPIO.cleanup()
