import threading
import time
import logging
from AmbianceController import LightController
from WSclient import AmbianceManagerClient
from rpi_ws281x import PixelStrip, Color

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s: %(message)s')

class AmbianceManager:
    def __init__(self):
        # LED configuration
        LED_CONFIG = {
            'LED_COUNT': 1520,
            'LED_PIN1': 18,
            'LED_FREQ_HZ': 800000,
            'LED_DMA': 10,
            'LED_INVERT': False,
            'LED_BRIGHTNESS': 255,
        }
        
        # Initialize LightController
        self.light_controller = LightController(
            LED_CONFIG['LED_COUNT'],
            LED_CONFIG['LED_PIN1'],
            LED_CONFIG['LED_FREQ_HZ'],
            LED_CONFIG['LED_DMA'],
            LED_CONFIG['LED_INVERT'],
            LED_CONFIG['LED_BRIGHTNESS']
        )
        
        # Initialize AmbianceManagerClient
        self.ws_client = AmbianceManagerClient("ws://192.168.10.146:8080/ambianceManager")
        
        # Pass the handle_message method as the message_handler for the "Message" route
        self.ws_client.connect_to_routes(message_handler=self.handle_message)

    def handle_message(self, message):
        print("handle message test")
        logging.info(f"Received message: {message}")
        
        # Check if the message is "set_zone_color#true"
        if message == "set_zone_color#true":
            # Execute the set_zone_color command with hardcoded parameters
            self.light_controller.set_zone_color(zone=range(0, 600), color=Color(255, 69, 0))
            logging.info("Executed set_zone_color with hardcoded parameters")
            
            # Send a confirmation back to the server
            self.ws_client.send_message_to_route("Message", "Command executed")
        else:
            logging.warning(f"Unknown message: {message}")
       

    # def execute_command(self, command):
    #     cmd = command.get("command")
    #     params = command.get("params", {})
    #     logging.info(f"command : {cmd}")
        
    #     if cmd == "set_zone_color":
    #         self.light_controller.set_zone_color(zone=range(300, 600), color=Color(255, 69, 0))
    #         print("blabla")
    #         logging.info(f"Setting zone color with params: {params}")
    #         logging.info(f"cmd : {cmd}")
    #     elif cmd == "clear_strip":
    #         self.light_controller.clear_strip()
    #         logging.info("Clearing the LED strip")
    #     elif cmd == "animate":
    #         animation = params.get("type")
    #         if animation == "feu":
    #             self.light_controller.animate_feu()
    #             logging.info("Starting 'feu' animation")
    #         elif animation == "eau":
    #             self.light_controller.animate_eau()
    #             logging.info("Starting 'eau' animation")
    #         else:
    #             logging.warning(f"Unknown animation type: {animation}")
    #     else:
    #         logging.warning(f"Commande inconnue : {cmd}")

    def test_animations(self):
        logging.info("Starting local animation test")
        self.light_controller.set_zone_color(zone=[0, 100], red=255, green=0, blue=0)
        time.sleep(2)
        self.light_controller.clear_strip()
        time.sleep(1)
        self.light_controller.animate_feu()
        time.sleep(5)
        self.light_controller.animate_eau()
        time.sleep(5)
        self.light_controller.clear_strip()
        logging.info("Local animation test completed")

    def start(self):
        # Start WebSocket client threads
        threading.Thread(target=self.ws_client.run, daemon=True).start()
        logging.info("AmbianceManager démarré.")

    def stop(self):
        # Stop WebSocket clients
        self.ws_client.send_message_to_route("Connect", "Goodbye from AmbianceManager")
        self.ws_client.stop()
        logging.info("AmbianceManager arrêté.")

if __name__ == "__main__":
    # Create AmbianceManager instance
    ambiance_manager = AmbianceManager()
    ambiance_manager.start()
    
    # Uncomment the line below to run local animation tests
    # ambiance_manager.test_animations()
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        ambiance_manager.stop()