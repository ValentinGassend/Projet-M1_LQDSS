import machine
import utime
import array
import math

class Microphone:
    def __init__(self, pin_number, sample_rate=10000, sample_duration=0.05, sound_threshold=300):
        self.pin = machine.ADC(machine.Pin(pin_number))
        self.pin.atten(machine.ADC.ATTN_11DB)
        
        self.sample_rate = sample_rate
        self.sample_duration = sample_duration
        self.sound_threshold = sound_threshold
        
        self.num_samples = int(self.sample_rate * self.sample_duration)
        self.last_detection_state = False

    def read_samples(self):
        samples = array.array('H', [0] * self.num_samples)
        for i in range(self.num_samples):
            samples[i] = self.pin.read()
            utime.sleep_us(int(1_000_000 / self.sample_rate))
        return samples

    def analyze_audio(self, samples):
        rms = math.sqrt(sum(sample**2 for sample in samples) / len(samples))
        is_sound_detected = rms > self.sound_threshold
        return {
            'rms': rms,
            'sound_detected': is_sound_detected
        }

class SoundMonitor:
    def __init__(self):
        self.microphones = []

    def add_microphone(self, pin_number, sound_threshold=300):
        mic = Microphone(pin_number, sound_threshold=sound_threshold)
        self.microphones.append(mic)
        return mic

    def run(self, callback=None):
        print("Starting multi-microphone audio detection...")
        while True:
            try:
                for index, mic in enumerate(self.microphones, 1):
                    samples = mic.read_samples()
                    audio_info = mic.analyze_audio(samples)
                    current_detection_state = audio_info['sound_detected']
                    
                    if current_detection_state != mic.last_detection_state:
                        if callback:
                            callback(index, audio_info['rms'], current_detection_state)
                        mic.last_detection_state = current_detection_state
                    
                    print(f"Mic{index} - RMS: {audio_info['rms']:.2f} | State: {'Above' if current_detection_state else 'Below'}")
            
            except Exception as e:
                print(f"Error in main loop: {e}")
            
            utime.sleep(0.1)