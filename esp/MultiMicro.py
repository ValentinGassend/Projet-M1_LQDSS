import machine
import utime
import array
import math
from WSclient import WSclient
from WebSocketClient import WebSocketClient

class Microphone:
    """
    Classe représentant un microphone connecté à un pin ADC
    """
    def __init__(self, pin_number, sample_rate=10000, sample_duration=0.1, sound_threshold=300):
        """
        Initialise un microphone
        
        Args:
            pin_number (int): Numéro du pin GPIO pour le microphone
            sample_rate (int): Fréquence d'échantillonnage
            sample_duration (float): Durée d'échantillonnage
            sound_threshold (int): Seuil de détection sonore
        """
        self.pin = machine.ADC(machine.Pin(pin_number))
        self.pin.atten(machine.ADC.ATTN_11DB)  # Plage de tension la plus large
        
        self.sample_rate = sample_rate
        self.sample_duration = sample_duration
        self.sound_threshold = sound_threshold
        
        self.num_samples = int(self.sample_rate * self.sample_duration)
        self.last_detection_state = False

    def read_samples(self):
        """
        Lit les échantillons audio du microphone
        
        Returns:
            array: Échantillons audio
        """
        samples = array.array('H', [0] * self.num_samples)
        
        for i in range(self.num_samples):
            samples[i] = self.pin.read()
            utime.sleep_us(int(1_000_000 / self.sample_rate))
        
        return samples

    def analyze_audio(self, samples):
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
        is_sound_detected = rms > self.sound_threshold
        
        return {
            'rms': rms,
            'sound_detected': is_sound_detected
        }

class SoundMonitor:
    """
    Classe de gestion globale pour la surveillance sonore et la connexion WebSocket
    """
    def __init__(self, wifi_ssid, wifi_password, websocket_url):
        """
        Initialise le moniteur sonore
        
        Args:
            wifi_ssid (str): SSID du réseau WiFi
            wifi_password (str): Mot de passe WiFi
            websocket_url (str): URL du serveur WebSocket
        """
        self.ws_client = WSclient(wifi_ssid, wifi_password, websocket_url)
        self.ws = None
        self.microphones = []
        self.connection_established = False

    def add_microphone(self, pin_number, sound_threshold=300):
        """
        Ajoute un microphone au système
        
        Args:
            pin_number (int): Numéro du pin GPIO pour le microphone
            sound_threshold (int): Seuil de détection sonore
        
        Returns:
            Microphone: L'instance du microphone ajouté
        """
        mic = Microphone(pin_number, sound_threshold=sound_threshold)
        self.microphones.append(mic)
        return mic

    def setup_connection(self):
        """
        Établir la connexion WiFi et WebSocket
        
        Returns:
            bool: True si la connexion est établie, False sinon
        """
        try:
            if self.ws_client.connect_wifi():
                self.ws = WebSocketClient(self.ws_client.WEBSOCKET_URL)
                if self.ws.connect():
                    print("WebSocket connection established")
                    self.connection_established = True
                    return True
            print("Failed to establish connection")
            self.connection_established = False
            return False
        except Exception as e:
            print(f"Connection error: {e}")
            self.connection_established = False
            return False

    def send_websocket_message(self, message):
        """
        Envoie un message via WebSocket
        
        Args:
            message (dict): Message à envoyer
        """
        if self.connection_established and self.ws:
            try:
                self.ws.send(str(message))
                print(f"Message envoyé: {message}")
            except Exception as e:
                print(f"Erreur d'envoi WebSocket: {e}")
                self.connection_established = self.setup_connection()

    def run(self):
        """
        Boucle principale de surveillance sonore
        """
        # Établir la connexion WiFi et WebSocket au démarrage
        self.setup_connection()
        
        print("Démarrage de la détection audio multimicrophone...")
        
        while True:
            try:
                # Traitement pour chaque microphone
                for index, mic in enumerate(self.microphones, 1):
                    # Lecture des échantillons
                    samples = mic.read_samples()
                    
                    # Analyse des données
                    audio_info = mic.analyze_audio(samples)
                    
                    # Gestion des changements d'état
                    current_detection_state = audio_info['sound_detected']
                    
                    # Envoi de message lors du changement d'état
                    if current_detection_state != mic.last_detection_state:
                        # Préparer le message en fonction de l'état
                        message_type = f"sound_{'above' if current_detection_state else 'below'}_threshold_mic{index}"
                        message = {
                            "type": message_type,
                            "mic_index": index,
                            "rms": audio_info['rms']
                        } 
                        
                        # Envoi du message WebSocket
                        self.send_websocket_message(message)
                        
                        # Mise à jour de l'état précédent
                        mic.last_detection_state = current_detection_state
                    
                    # Affichage des résultats
                    print(f"Mic{index} - RMS: {audio_info['rms']:.2f} | État: {'Au-dessus' if current_detection_state else 'En-dessous'}")
            
            except Exception as e:
                print(f"Erreur dans la boucle principale: {e}")
            
            # Pause entre deux mesures
            utime.sleep(0.1)

# Exemple d'utilisation
def main():
    # Créer un moniteur sonore
    sound_monitor = SoundMonitor(
        wifi_ssid="Cudy-F810", 
        wifi_password="13022495", 
        websocket_url="ws://192.168.10.146:8080/rpiConnect"
    )
    
    # Ajouter des microphones
    sound_monitor.add_microphone(pin_number=34, sound_threshold=300)  # Premier micro
    sound_monitor.add_microphone(pin_number=35, sound_threshold=250)  # Deuxième micro
    sound_monitor.add_microphone(pin_number=36, sound_threshold=250)  # troisième micro
    sound_monitor.add_microphone(pin_number=32, sound_threshold=250)  # troisième micro
    # On peut facilement ajouter d'autres microphones avec .add_microphone()
    
    # Démarrer la surveillance
    sound_monitor.run()

# Démarrage du programme principal
if __name__ == '__main__':
    main()