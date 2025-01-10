import websocket
import threading
import time


class WebSocketRouteClient:
    def __init__(self, uri, route_name):
        self.uri = uri
        self.route_name = route_name
        self.ws = None

    def on_open(self, ws):
        print(f"[{self.route_name}] Connexion ouverte")
        if "Connect" in self.route_name:
            self.send_message(f"Hello from {self.route_name}")

    def on_message(self, ws, message):
        print(f"[{self.route_name}] Message reçu : {message}")
        if message == "ping":
            print(f"[{self.route_name}] Répond à ping par pong")
            self.send_message("pong")
        else:
            self.handle_message(message)

    def on_error(self, ws, error):
        print(f"[{self.route_name}] Erreur : {error}")

    def on_close(self, ws, close_status_code, close_msg):
        print(f"[{self.route_name}] Connexion fermée")

    def connect(self):
        self.ws = websocket.WebSocketApp(
            self.uri,
            on_open=self.on_open,
            on_message=self.on_message,
            on_error=self.on_error,
            on_close=self.on_close
        )
        thread = threading.Thread(target=self.ws.run_forever)
        thread.daemon = True
        thread.start()

    def send_message(self, message):
        if self.ws:
            self.ws.send(message)

    def handle_message(self, message):
        print(f"[{self.route_name}] Traitement du message : {message}")


class AmbianceManagerClient:
    def __init__(self, base_uri):
        self.base_uri = base_uri
        self.routes = {
            "Connect": None,
            "Message": None,
            "Ping": None,
        }

    def connect_to_routes(self):
        for route_suffix in self.routes.keys():
            uri = f"{self.base_uri}{route_suffix}"
            client = WebSocketRouteClient(uri, route_suffix)
            client.connect()
            self.routes[route_suffix] = client

    def send_message_to_route(self, route_suffix, message):
        if route_suffix in self.routes and self.routes[route_suffix]:
            self.routes[route_suffix].send_message(message)
        else:
            print(f"Route {route_suffix} n'est pas connectée ou introuvable.")

    def run(self):
        try:
            while True:
                time.sleep(1)  # Maintient le script en cours d'exécution
        except KeyboardInterrupt:
            print("Fermeture des connexions...")
            for route_suffix, client in self.routes.items():
                if client and client.ws:
                    client.ws.close()


# Adresse de base du serveur (à adapter)
base_server_uri = "ws://192.168.10.146:8080/ambianceManager"

# Créer le client et se connecter aux routes
ambiance_manager_client = AmbianceManagerClient(base_server_uri)
ambiance_manager_client.connect_to_routes()

# Maintenir le client en cours d'exécution
ambiance_manager_client.run()
