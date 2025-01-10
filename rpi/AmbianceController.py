# led_controller.py
from rpi_ws281x import PixelStrip, Color
import time


class LightController:
    def __init__(self, led_count, pin, freq_hz=800000, dma=10, invert=False, brightness=255, channel=0):
        self.strip = PixelStrip(led_count, pin, freq_hz, dma, invert, brightness, channel=channel)
        self.strip.begin()

    def clear_strip(self):
        """Reset all LEDs to complete off state."""
        for i in range(self.strip.numPixels()):
            self.strip.setPixelColor(i, Color(0, 0, 0))
        self.strip.show()
        self.strip.begin()
        self.strip.show()

    def set_zone_color(self, zone, color):
        """Définit une couleur pour une zone spécifique."""
        for i in zone:
            self.strip.setPixelColor(i, color)
        self.strip.show()

    def fill_path_start(self, zone, color, duration=2):
        """Remplit une zone avec une couleur de gauche à droite."""
        steps = len(zone)
        delay = duration / steps

        for i in zone:
            self.strip.setPixelColor(i, color)
            self.strip.show()
            time.sleep(delay)

    def fill_path_end(self, zone, color, duration=2.0):
        """Remplit une zone avec une couleur de droite à gauche."""
        steps = len(zone)
        delay = duration / steps

        for i in reversed(zone):
            self.strip.setPixelColor(i, color)
            self.strip.show()
            time.sleep(delay)

    def blink(self, zone, color, blink_times=3, delay=0.5):
        """Fait clignoter une zone plusieurs fois."""
        for _ in range(blink_times):
            self.set_zone_color(zone, color)
            time.sleep(delay)
            self.set_zone_color(zone, Color(0, 0, 0))
            time.sleep(delay)

    def pulse(self, zone, base_color, pulse_color, duration=2.0):
        """Fait pulser une zone entre deux couleurs."""
        steps = 20
        delay = duration / steps

        for _ in range(steps):
            for i in zone:
                self.strip.setPixelColor(i, pulse_color)
            self.strip.show()
            time.sleep(delay)

            for i in zone:
                self.strip.setPixelColor(i, base_color)
            self.strip.show()
            time.sleep(delay)

    def animate_heartbeat(self, zone, base_color, pulse_color, duration=1.0):
        """Animation de battement de cœur."""
        self.pulse(zone, base_color, pulse_color, duration)

    def animate_flow(self, zone, start_color, end_color, duration=2.0):
        """Animation de flux lumineux."""
        steps = len(zone)
        delay = duration / steps

        for i in zone:
            self.strip.setPixelColor(i, start_color)
            self.strip.show()
            time.sleep(delay)

        for i in zone:
            self.strip.setPixelColor(i, end_color)
            self.strip.show()
            time.sleep(delay)


# main.py
def main():
    # Configuration LED
    LED_CONFIG = {
        'LED_COUNT': 1520,  # Ajusté pour correspondre à la plus grande zone
        'LED_PIN1': 18,
        'LED_FREQ_HZ': 800000,
        'LED_DMA': 10,
        'LED_BRIGHTNESS': 255,
        'LED_INVERT': False,
    }

    # Définition des zones et leurs couleurs par défaut
    ZONES = {
        'FEU': {
            'range': range(621, 920),
            'default_color': Color(255, 69, 0),  # Orange
            'effect_color': Color(255, 0, 0)  # Rouge pour les effets
        },
        'EAU': {
            'range': range(1233, 1520),
            'default_color': Color(0, 0, 255),  # Bleu
            'effect_color': Color(0, 255, 255)  # Cyan pour les effets
        },
        'VENT': {
            'range': range(933, 1220),
            'default_color': Color(128, 128, 128),  # Gris
            'effect_color': Color(255, 255, 255)  # Blanc pour les effets
        },
        'ELECTRICITE': {
            'range': range(301, 633),
            'default_color': Color(255, 255, 0),  # Jaune
            'effect_color': Color(200, 200, 0)  # Jaune plus foncé pour les effets
        },
        'CRYSTAL': {
            'range': range(0, 300),
            'default_color': Color(128, 0, 128),  # Violet
            'effect_color': Color(180, 0, 180)  # Violet plus clair pour les effets
        }
    }

    # Initialize LED controller
    controller = LightController(
        LED_CONFIG['LED_COUNT'],
        LED_CONFIG['LED_PIN1'],
        LED_CONFIG['LED_FREQ_HZ'],
        LED_CONFIG['LED_DMA'],
        LED_CONFIG['LED_INVERT'],
        LED_CONFIG['LED_BRIGHTNESS']
    )

    # Définition des animations
    def animate_feu():
        controller.animate_flow(
            ZONES['FEU']['range'],
            ZONES['FEU']['default_color'],
            ZONES['FEU']['effect_color']
        )

    def animate_eau():
        controller.animate_flow(
            ZONES['EAU']['range'],
            ZONES['EAU']['default_color'],
            ZONES['EAU']['effect_color']
        )

    def animate_vent():
        controller.pulse(
            ZONES['VENT']['range'],
            ZONES['VENT']['default_color'],
            ZONES['VENT']['effect_color']
        )

    def animate_electricite():
        controller.blink(
            ZONES['ELECTRICITE']['range'],
            ZONES['ELECTRICITE']['default_color'],
            blink_times=5,
            delay=0.2
        )

    def animate_crystal():
        controller.pulse(
            ZONES['CRYSTAL']['range'],
            ZONES['CRYSTAL']['default_color'],
            ZONES['CRYSTAL']['effect_color'],
            duration=3.0
        )

    # Définition des handlers pour le WebSocket
    animation_handlers = {
        'animate_feu': animate_feu,
        'animate_eau': animate_eau,
        'animate_vent': animate_vent,
        'animate_electricite': animate_electricite,
        'animate_crystal': animate_crystal,
        'set_zone_color_feu': lambda: controller.set_zone_color(
            ZONES['FEU']['range'],
            ZONES['FEU']['default_color']
        ),
        'set_zone_color_eau': lambda: controller.set_zone_color(
            ZONES['EAU']['range'],
            ZONES['EAU']['default_color']
        ),
        'set_zone_color_vent': lambda: controller.set_zone_color(
            ZONES['VENT']['range'],
            ZONES['VENT']['default_color']
        ),
        'set_zone_color_electricite': lambda: controller.set_zone_color(
            ZONES['ELECTRICITE']['range'],
            ZONES['ELECTRICITE']['default_color']
        ),
        'set_zone_color_crystal': lambda: controller.set_zone_color(
            ZONES['CRYSTAL']['range'],
            ZONES['CRYSTAL']['default_color']
        ),
        'clear_all': controller.clear_strip,
        'reset_defaults': lambda: set_all_default_colors(controller, ZONES)
    }

    def set_all_default_colors(controller, zones):
        """Réinitialise toutes les zones à leurs couleurs par défaut"""
        for zone_info in zones.values():
            controller.set_zone_color(
                zone_info['range'],
                zone_info['default_color']
            )

    # Initialize and start WebSocket handler
    # ws_handler = WSclient('ws://192.168.1.14:8080/rpiConnect', animation_handlers)
    # ws_handler.start()

    try:
        # Initialisation des couleurs par défaut
        animate_crystal()

        # Main program loop
        while True:
            time.sleep(1)  # Garde le programme en vie

    except KeyboardInterrupt:
        print("Arrêt du programme.")
        controller.clear_strip()
        controller.clear_strip()
        # ws_handler.stop()
    finally:
        controller.clear_strip()
        controller.clear_strip()


if __name__ == "__main__":
    main()