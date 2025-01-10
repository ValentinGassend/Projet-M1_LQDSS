import threading

class AmbianceManager:
    def __init__(self, ws_client, light_controller):
        """
        Initialise le gestionnaire d'ambiance.

        :param ws_client: Instance d'un client WebSocket (ex. AMWSClient).
        :param light_controller: Instance d'un contrôleur de LED (ex. LightController).
        """
        self.ws_client = ws_client
        self.light_controller = light_controller
        self.running = False

    def start(self):
        """Démarre le gestionnaire d'ambiance."""
        self.running = True
        threading.Thread(target=self.ws_client.start, daemon=True).start()
        print("AmbianceManager démarré.")

    def stop(self):
        """Arrête le gestionnaire d'ambiance."""
        self.running = False
        self.ws_client.stop()
        print("AmbianceManager arrêté.")

    def handle_message(self, message):
        """
        Gère un message reçu via WebSocket.

        :param message: Message reçu sous forme de dictionnaire.
        """
        command = message.get("command")
        params = message.get("params", {})

        if command == "set_zone_color":
            self.light_controller.set_zone_color(**params)
        elif command == "clear_strip":
            self.light_controller.clear_strip()
        elif command == "animate":
            animation = params.get("type")
            if animation == "feu":
                self.light_controller.animate_feu()
            elif animation == "eau":
                self.light_controller.animate_eau()
            # Ajoutez d'autres animations ici
        else:
            print(f"Commande inconnue : {command}")

    def on_websocket_message(self, message):
        """
        Callback appelé lorsque le client WebSocket reçoit un message.

        :param message: Message brut reçu (généralement JSON).
        """
        try:
            import json
            parsed_message = json.loads(message)
            self.handle_message(parsed_message)
        except json.JSONDecodeError:
            print(f"Erreur de décodage du message : {message}")

# Exemple d'utilisation :
if __name__ == "__main__":
    from AmbianceController import LightController, AMWSClient

    # Initialisation des composants
    light_controller = LightController()
    ws_client = AMWSClient()

    # Création du gestionnaire d'ambiance
    ambiance_manager = AmbianceManager(ws_client, light_controller)

    # Configuration du callback WebSocket
    ws_client.on_message = ambiance_manager.on_websocket_message

    # Démarrage du gestionnaire
    ambiance_manager.start()

    try:
        while True:
            pass  # Maintenir le programme actif
    except KeyboardInterrupt:
        ambiance_manager.stop()
