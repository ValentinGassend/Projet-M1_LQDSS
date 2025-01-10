import websocket
import threading
import time


class WebSocketRouteClient:
    def __init__(self, uri, route_name, message_handler=None):  # Add message_handler parameter
        self.uri = uri
        self.route_name = route_name
        self.ws = None
        self.message_handler = message_handler  # Initialize message_handler

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
            # Delegate message handling to the external handler
            if self.message_handler:
                self.message_handler(message)  # Call the external message_handler
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

    def connect_to_routes(self, message_handler=None):  # Add message_handler parameter
        for route_suffix in self.routes.keys():
            uri = f"{self.base_uri}{route_suffix}"
            # Pass message_handler only for the "Message" route
            if route_suffix == "Message":
                client = WebSocketRouteClient(uri, route_suffix, message_handler)
            else:
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