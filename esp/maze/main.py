from machine import Pin
import utime
from WSclient import WSclient
from DoubleRfid import RFIDController
from Button import ButtonController


class ESP32Controller:
    def __init__(self):
        # RFID Controller
        self.rfid = RFIDController()
        # WebSocket client
        self.ws_client = WSclient("Cudy-F810", "13022495", "maze_esp")
        # Button Controller
        self.button_controller = ButtonController()

        # Add activation state
        self.is_activated = False

        self.last_reconnect_attempt = 0
        self.reconnect_interval = 1

        self.controller = ButtonController()
        self.controller.add_button(23, "btn1")
        self.controller.add_button(27, "btn2")
        self.controller.add_button(14, "btn3")
        self.message_queue = []
    def attempt_reconnect(self):
        """Attempt to reconnect WebSocket connections"""
        current_time = utime.ticks_ms()
        if utime.ticks_diff(current_time, self.last_reconnect_attempt) > self.reconnect_interval:
            print("Attempting to reconnect WebSocket...")
            self.last_reconnect_attempt = current_time

            if self.ws_client.connect_wifi():
                print("WiFi reconnected successfully")
                self.ws_client.connect_websockets()
                print("WebSocket reconnection attempt completed")
            else:
                print("WiFi reconnection failed")
                
    def send_message(self, msg):
        """Envoie un message au serveur"""
        try:
            ws = self.ws_client.route_ws_map.get("message", None)
            if ws:
                print(f"Sending message: {msg}")
                ws.socket.setblocking(True)  # S'assure que l'envoi est bloquant
                ws.send(msg)
            else:
                print("WebSocket route 'message' not found")
                self.message_queue.append(msg)  # Sauvegarde le message pour réessayer plus tard
        except Exception as e:
            print(f"Error sending message: {e}")
            self.message_queue.append(msg)  # Sauvegarde le message en cas d'erreur
            self.attempt_reconnect()

    def handle_websocket_error(self, ws_route, error):
        """Handle WebSocket errors appropriately"""
        if error.args[0] == 128:  # ENOTCONN
            print(f"Connection lost on route {ws_route}, attempting reconnection...")
            self.attempt_reconnect()
        else:
            print(f"Error on WebSocket route {ws_route}: {error}")

    def handle_entrance_tag(self, card_id):
        """Callback for entrance RFID detection"""
        if self.is_activated:
            return

        if card_id == 322763907 and not self.is_activated:
            msg = f"maze_esp=>[maze_iphone,maze_esp,ambianceManager_rpi]=>rfid#maze"
            print(f"Sending RFID entrance message: {msg}")
            self.ws_client.route_ws_map.get("message", None).send(msg)

        else:
            print(f"card {card_id} is wrong card")

    def handle_exit_tag(self, card_id):
        """Callback for exit RFID detection"""
        if not self.is_activated:
            return

        msg = f"maze_esp=>[maze_iphone]=>rfid#false"
        print(f"Sending RFID exit message: {msg}")
        self.ws_client.route_ws_map.get("message", None).send(msg)

    def handle_button_press(self, button_name):
        """Handle button press events"""
        if not self.is_activated:
            return

        msg = f"maze_esp=>[maze_iphone]=>{button_name}#true"
        self.send_message(msg)  # Utilise la nouvelle méthode d'envoi

    def handle_button_release(self, button_name):
        """Handle button press events"""
        if not self.is_activated:
            return

        msg = f"maze_esp=>[maze_iphone]=>{button_name}#false"
        self.send_message(msg)  # Utilise la nouvelle méthode d'envoi

    def handle_websocket_messages(self):
        """Process WebSocket messages"""
        for ws_route, ws in self.ws_client.route_ws_map.items():
            try:
                ws.socket.setblocking(False)
                data = ws.socket.recv(1)
                ws.socket.setblocking(True)
                if data:
                    message = ws.receive(first_byte=data)
                    if message:
                        print(f"Message received on route {ws_route}: {message}")

                        # Check for activation message
                        if "rfid#maze" in message:
                            print("Maze ESP activated!")
                            self.is_activated = True

                        if "ping" in message.lower():
                            self.ws_client.process_message(ws, message)
                        else:
                            print(f"Received message: {message}")

            except OSError as e:
                if e.args[0] != 11:  # Ignore EAGAIN errors
                    self.handle_websocket_error(ws_route, e)

    def start(self):
        print("Starting controller...")
        if not self.ws_client.connect_wifi():
            print("WiFi connection failed. Stopping.")
            return

        self.ws_client.connect_websockets()
        print("Waiting for maze activation...")

        while True:
            try:
                
                 # Tente d'envoyer les messages en attente
                while self.message_queue:
                    msg = self.message_queue[0]  # Regarde le premier message
                    try:
                        self.send_message(msg)
                        self.message_queue.pop(0)  # Retire le message si envoyé avec succès
                    except:
                        break  # Arrête si l'envoi échoue

                # Check WebSocket messages
                self.handle_websocket_messages()

                # Check RFID readers
                self.rfid.check_readers(
                    callback_entrance=self.handle_entrance_tag,
                    callback_exit=self.handle_exit_tag
                )

                # Check buttons and handle presses
                self.controller.check_buttons(callback_press=self.handle_button_press,
                                              callback_release=self.handle_button_release)

                utime.sleep_ms(10)
            except Exception as e:
                print(f"General error: {e}")
                utime.sleep(5)
                self.__init__()  # Reset controller
                self.start()


if __name__ == "__main__":
    controller = ESP32Controller()
    controller.start()