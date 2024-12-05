import machine
import utime
import array
import math
from WSclient import WSclient  # Import your WebSocket client class
from WebSocketClient import WebSocketClient

# Configuration du pin pour le micro
MICROPHONE_PIN = machine.ADC(machine.Pin(34))  # GPIO34

# Configuration de l'échantillonnage
SAMPLE_RATE = 10000  # Fréquence d'échantillonnage (Hz)
SAMPLE_DURATION = 0.1  # Durée d'échantillonnage en secondes
NUM_SAMPLES = int(SAMPLE_RATE * SAMPLE_DURATION)

# Seuil de détection sonore
SOUND_THRESHOLD = 300  # À ajuster selon votre micro

# Initialize WebSocket client
ws_client = WSclient("Cudy-F810", "13022495", "ws://192.168.10.146:8080/rpiConnect")

# Variables globales
ws = None
last_detection_state = False

def setup_connection():
    """Établir la connexion WiFi et WebSocket"""
    global ws
    try:
        if ws_client.connect_wifi():
            ws = WebSocketClient(ws_client.WEBSOCKET_URL)
            if ws.connect():
                print("WebSocket connection established")
                return True
        print("Failed to establish connection")
        return False
    except Exception as e:
        print(f"Connection error: {e}")
        return False

def read_microphone():
    """
    Lit les échantillons audio du microphone
    
    Returns:
        array: Échantillons audio
    """
    samples = array.array('H', [0] * NUM_SAMPLES)
    
    # Configuration de l'ADC
    MICROPHONE_PIN.atten(machine.ADC.ATTN_11DB)  # Plage de tension la plus large
    
    # Échantillonnage
    for i in range(NUM_SAMPLES):
        samples[i] = MICROPHONE_PIN.read()
        utime.sleep_us(int(1_000_000 / SAMPLE_RATE))
    
    return samples

def analyze_audio(samples):
    """
    Analyse les données audio
    
    Args:
        samples (array): Tableau des échantillons audio
    
    Returns:
        dict: Informations sur l'audio détecté
    """
    # Calcul du niveau sonore RMS
    rms = math.sqrt(sum(sample**2 for sample in samples) / len(samples))
    
    # Détection de seuil sonore
    is_sound_detected = rms > SOUND_THRESHOLD
    
    return {
        'rms': rms,
        'sound_detected': is_sound_detected
    }

def main():
    global ws, last_detection_state
    
    # Établir la connexion WiFi et WebSocket au démarrage
    connection_established = setup_connection()
    
    print("Démarrage de la détection audio...")
    
    while True:
        try:
            # Lecture des échantillons
            samples = read_microphone()
            
            # Analyse des données
            audio_info = analyze_audio(samples)
            
            # Gestion des changements d'état
            current_detection_state = audio_info['sound_detected']
            
            # Envoi de message lors du changement d'état
            if current_detection_state != last_detection_state:
                # Préparer le message en fonction de l'état
                message_type = "sound_above_threshold" if current_detection_state else "sound_below_threshold"
                message = {
                    "type": message_type,
                    "rms": audio_info['rms']
                }
                
                # Envoi du message WebSocket
                if connection_established and ws:
                    try:
                        ws.send(str(message))
                        print(f"Message envoyé: {message}")
                    except Exception as e:
                        print(f"Erreur d'envoi WebSocket: {e}")
                        # Réessayer de se connecter
                        connection_established = setup_connection()
                
                # Mise à jour de l'état précédent
                last_detection_state = current_detection_state
            
            # Affichage des résultats
            print(f"RMS: {audio_info['rms']:.2f} | État: {'Au-dessus' if current_detection_state else 'En-dessous'}")
        
        except Exception as e:
            print(f"Erreur dans la boucle principale: {e}")
        
        # Pause entre deux mesures
        utime.sleep(0.1)

# Démarrage du programme principal
if __name__ == '__main__':
    main()