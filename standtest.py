#!/usr/bin/env python3
# NeoPixel library strandtest example
# Author: Tony DiCola (tony@tonydicola.com)
#
# Direct port of the Arduino NeoPixel library strandtest example.  Showcases
# various animations on a strip of NeoPixels.

import time
from rpi_ws281x import *
import argparse

# LED strip configuration:
LED_COUNT      = 1600     # Number of LED pixels.
LED_PIN        = 18      # GPIO pin connected to the pixels (18 uses PWM!).
#LED_PIN        = 10      # GPIO pin connected to the pixels (10 uses SPI /dev/spidev0.0).
LED_FREQ_HZ    = 800000  # LED signal frequency in hertz (usually 800khz)
LED_DMA        = 10      # DMA channel to use for generating a signal (try 10)
LED_BRIGHTNESS = 60      # Set to 0 for darkest and 255 for brightest
LED_INVERT     = False   # True to invert the signal (when using NPN transistor level shift)
LED_CHANNEL    = 0       # set to '1' for GPIOs 13, 19, 41, 45 or 53





def set_full_strip_color(strip, color):
    """
    Set a single color for the entire LED strip.
    
    Args:
        strip: The LED strip object
        color: Color in the format Color(r, g, b)
    """
    for i in range(strip.numPixels()):
        strip.setPixelColor(i, color)
    strip.show()

def set_zone_color(strip, start_led, end_led, color):
    """
    Set a color for a specific zone of LEDs.
    
    Args:
        strip: The LED strip object
        start_led: Starting LED index (inclusive)
        end_led: Ending LED index (inclusive)
        color: Color in the format Color(r, g, b)
    """
    # Ensure indices are within bounds
    num_pixels = strip.numPixels()
    start_led = max(0, min(start_led, num_pixels - 1))
    end_led = max(0, min(end_led, num_pixels - 1))
    
    # Set color for specified range
    for i in range(start_led, end_led + 1):
        strip.setPixelColor(i, color)
    strip.show()

# Define functions which animate LEDs in various ways.
def colorWipe(strip, color, wait_ms=50):
    """Wipe color across display a pixel at a time."""
    for i in range(strip.numPixels()):
        strip.setPixelColor(i, color)
        strip.show()
        time.sleep(wait_ms/1000.0)

def clear_strip(strip):
        """Éteint toutes les LEDs."""
        for i in range(strip.numPixels()):
            strip.setPixelColor(i, Color(0, 0, 0))
        strip.show()

def theaterChase(strip, color, wait_ms=50, iterations=10):
    """Movie theater light style chaser animation."""
    for j in range(iterations):
        for q in range(3):
            for i in range(0, strip.numPixels(), 3):
                strip.setPixelColor(i+q, color)
            strip.show()
            time.sleep(wait_ms/1000.0)
            for i in range(0, strip.numPixels(), 3):
                strip.setPixelColor(i+q, 0)

def wheel(pos):
    """Generate rainbow colors across 0-255 positions."""
    if pos < 85:
        return Color(pos * 3, 255 - pos * 3, 0)
    elif pos < 170:
        pos -= 85
        return Color(255 - pos * 3, 0, pos * 3)
    else:
        pos -= 170
        return Color(0, pos * 3, 255 - pos * 3)
def set_zone_color(strip, color):
        """
        Définit une couleur pour une zone spécifique.
        :param zone: Plage de LEDs (ex: ZONE_FEU).
        :param color: Couleur au format Color(r, g, b).
        """
      
        strip.setPixelColor( color)
        strip.show()
def rainbow(strip, wait_ms=20, iterations=1):
    """Draw rainbow that fades across all pixels at once."""
    for j in range(256*iterations):
        for i in range(strip.numPixels()):
            strip.setPixelColor(i, wheel((i+j) & 255))
        strip.show()
        time.sleep(wait_ms/1000.0)

def rainbowCycle(strip, wait_ms=20, iterations=5):
    """Draw rainbow that uniformly distributes itself across all pixels."""
    for j in range(256*iterations):
        for i in range(strip.numPixels()):
            strip.setPixelColor(i, wheel((int(i * 256 / strip.numPixels()) + j) & 255))
        strip.show()
        time.sleep(wait_ms/1000.0)

def theaterChaseRainbow(strip, wait_ms=50):
    """Rainbow movie theater light style chaser animation."""
    for j in range(256):
        for q in range(3):
            for i in range(0, strip.numPixels(), 3):
                strip.setPixelColor(i+q, wheel((i+j) % 255))
            strip.show()
            time.sleep(wait_ms/1000.0)
            for i in range(0, strip.numPixels(), 3):
                strip.setPixelColor(i+q, 0)

# Main program logic follows:
if __name__ == '__main__':
    # Process arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('-c', '--clear', action='store_true', help='clear the display on exit')
    args = parser.parse_args()

    # Create NeoPixel object with appropriate configuration.
    strip2 = Adafruit_NeoPixel(1500, 18, LED_FREQ_HZ, LED_DMA, LED_INVERT, LED_BRIGHTNESS, LED_CHANNEL)

    # Create NeoPixel object with appropri
    # ate configuration.
    strip1 = Adafruit_NeoPixel(LED_COUNT, 18, LED_FREQ_HZ, LED_DMA, LED_INVERT, LED_BRIGHTNESS, 0)

    # Cate configuration.
    strip3 = Adafruit_NeoPixel(LED_COUNT, 18, LED_FREQ_HZ, LED_DMA, LED_INVERT, LED_BRIGHTNESS,0)
    # Intialize the library (must be called once before other functions).
    strip1.begin()
    strip2.begin()
    strip3.begin()

    print ('Press Ctrl-C to quit.')
    if not args.clear:
        print('Use "-c" argument to clear LEDs on exit')

    try:
        while True:
            print('=== Début du cycle d\'animations ===')
            
            
            
            print('  - Theater Chase blanc sur strip3')
            theaterChase(strip3, Color(127, 127, 127))
            print('  - Theater Chase blanc sur strip2')
            theaterChase(strip2, Color(127, 127, 127))
            print('  - Theater Chase blanc sur strip1')
            theaterChase(strip1, Color(127, 127, 127))
            
            print('  - Animation arc-en-ciel sur strip3')
            rainbow(strip3)
            print('  - Animation arc-en-ciel sur strip2')
            rainbow(strip2)
            print('  - Animation arc-en-ciel sur strip1')
            rainbow(strip2)
            
            print('  - Application couleur orange sur strip2')
            set_full_strip_color(strip2, Color(255,120,30))
            print('  - Application couleur orange sur strip2')
            set_full_strip_color(strip1, Color(255,120,30))
            
            print('  - Séquence arc-en-ciel sur strip2')
            rainbow(strip2)
            
            print('  - Séquence arc-en-ciel sur strip1')
            rainbow(strip1)
            
            print('> Nettoyage des bandes LED')
            print('  - Effacement strip1')
            colorWipe(strip1, Color(0,0,0), 10)
            print('  - Effacement strip2')
            colorWipe(strip2, Color(0,0,0), 10)
            
            print('> Séquence Theater Chase')
            print('  - Theater Chase blanc sur strip2')
            theaterChase(strip2, Color(127, 127, 127))
            print('  - Theater Chase blanc sur strip1')
            theaterChase(strip1, Color(127, 127, 127))
            
            print('  - Theater Chase rouge sur strip2')
            theaterChase(strip2, Color(127, 0, 0))
            print('  - Theater Chase rouge sur strip1')
            theaterChase(strip1, Color(127, 0, 0))
            
            print('  - Theater Chase bleu sur strip2')
            theaterChase(strip2, Color(0, 0, 127))
            
            print('> Animations arc-en-ciel')
            print('  - Rainbow classique sur strip1')
            rainbow(strip1)
            print('  - Rainbow cycle sur strip1')
            rainbowCycle(strip1)
            print('  - Theater Chase Rainbow sur strip1')
            theaterChaseRainbow(strip1)
            
        print('=== Fin du cycle d\'animations ===\n')
    except KeyboardInterrupt:
        print("Arrêt du programme.")
    finally:
        colorWipe(strip2, Color(0,0,0), 10)
        clear_strip(strip2)
        