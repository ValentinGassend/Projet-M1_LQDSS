import RPi.GPIO as GPIO
import time
import sys
sys.stdout.reconfigure(line_buffering=True)
# Configuration des broches
LASER_SENSOR_PIN = 18  # Modifier selon la broche utilisée

# Configuration de la bibliothèque GPIO
GPIO.setmode(GPIO.BCM)  # Utilise le mode BCM pour les broches
GPIO.setup(LASER_SENSOR_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)  # Configure la broche avec une résistance pull-up

try:
    print("Surveillance du capteur photosensible...")
    
    start_time = time.time()  # Enregistre le temps de début
    duration = 10  # Durée maximale d'exécution en secondes
    
    while True:
        # Vérifie si le temps d'exécution dépasse la limite
        elapsed_time = time.time() - start_time
        if elapsed_time > duration:
            print("Temps d'exécution atteint. Arrêt du script.")
            break

        # Lit l'état du capteur
        sensor_state = GPIO.input(LASER_SENSOR_PIN)
        
        # Affiche l'état actuel
        if sensor_state == GPIO.HIGH:  # Aucun signal détecté
            print("ATTENTION : Laser hors ligne de visée !")
        else:  # Signal laser détecté
            print("Laser aligné.")
        
        # Ajoute un délai pour éviter une surcharge
        time.sleep(0.5)  # Ajustez la fréquence de balayage si nécessaire

except KeyboardInterrupt:
    # Interrompt proprement le programme avec Ctrl+C
    print("\nArrêt du programme.")

finally:
    # Nettoie la configuration GPIO pour éviter tout conflit
    GPIO.cleanup()
