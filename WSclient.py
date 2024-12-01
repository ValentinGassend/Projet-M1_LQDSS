
import websocket
import subprocess
import os 
import time
import threading


DetectedObject = False

def on_message(ws, message):
    if message == "python3 laser.py":
        launch_laser() 
    print(f"Exécution de la commande : {message}")
   
   

def on_error(ws, error):
    print("Erreur:", error)

def on_close(ws, close_status_code, close_msg):
    print("Connexion fermée")

def on_open(ws):
    print("Connexion ouverte")
    ws.send("Bonjour, serveur !")
    # send_data_toRoute("rpiLaser","toRoute data")

def launch_laser():
    global DetectedObject  # Indique que nous modifions la variable globale

     # Lancer le processus avec Popen
    process = subprocess.Popen(
        "python3 laser.py",
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    
    # Lire les sorties en temps réel
    try:
        while True:
            output = process.stdout.readline().strip()  # Lire la sortie
            if output:  # Si une ligne est lue
                print(f"Sortie de laser.py : {output}")
                
                # Vérifier si le laser est aligné
                if output == "Laser aligné." and not DetectedObject:
                    DetectedObject = True
                    print("DEBUG: DetectedObject est maintenant", DetectedObject)
                    # Envoi immédiat au serveur
                    send_data_toRoute(ws_rpiLaser, "Laser détecté")
                
                # Réinitialiser DetectedObject si le laser est hors ligne
                elif output != "Laser aligné." and DetectedObject:
                    DetectedObject = False
                    print("DEBUG: DetectedObject est maintenant", DetectedObject)

            if output == "" and process.poll() is not None:
                break  # Terminer si le processus est terminé
    except Exception as e:
        print(f"Erreur dans launch_laser : {e}")
    finally:
        process.terminate()
        print("laser.py terminé.")

def send_data_toRoute(ws, data):
    try:
        ws.send(data)
        print(f"Données envoyées au serveur : {data}")
    except Exception as e:
        print(f"Erreur lors de l'envoi des données : {e}")

def send_data_continuously(data):
    while True:
        try:
            # Exemple de données à envoyer
            ws.send(data)
            print(f"Données envoyées : {data}")
            time.sleep(1)  # Envoi toutes les secondes
        except Exception as e:
            print(f"Erreur lors de l'envoi des données : {e}")
            break

# def send_data(data):
#     ws_rpiLaser.send(data)
#     print(f"Données envoyées : {data}")

def run_websocket(ws):
    """Exécute une instance WebSocket."""
    ws.run_forever()


ws = websocket.WebSocketApp(
    "ws://192.168.1.14:8080/rpiConnect",
    on_open=on_open,
    on_message=on_message,
    on_error=on_error,
    on_close=on_close
)

ws_rpiLaser = websocket.WebSocketApp(
    "ws://192.168.1.14:8080/rpiLaser",
    on_open=on_open,
    on_message=on_message,
    on_error=on_error,
    on_close=on_close
)


thread_connect = threading.Thread(target=run_websocket, args=(ws,))
thread_laser = threading.Thread(target=run_websocket, args=(ws_rpiLaser,))
thread_connect.daemon = True
thread_laser.daemon = True

thread_connect.start()
thread_laser.start()
time.sleep(5)

# send_data("data laser")
# send_data_toRoute(ws_rpiLaser,"data laser")  
# while True:
#     if DetectedObject:
#         print("DEBUG: Envoi de DetectedObject au serveur (True)")
#         send_data_toRoute(ws_rpiLaser,"DetectedObject")  
#     time.sleep(5)
   