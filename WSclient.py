
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
            # Lire une ligne de la sortie standard
            output = process.stdout.readline()
            if output == "Laser aligné.":
                DetectedObject = True
            else:
                print("le laser n'a pas changé")
            if output == '' and process.poll() is not None:
                break
            if output:
                print(output, end="")  # Afficher chaque ligne en temps réel
            
        # Lire la sortie d'erreur
        while True:
            error = process.stderr.readline()
            if error == '' and process.poll() is not None:
                break
            if error:
                print(f"Erreur : {error.strip()}", end="\n")
    except KeyboardInterrupt:
            print("Exécution interrompue par l'utilisateur.")
            process.terminate()

def send_data_toRoute(route,data):  
    route.send(data)

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
while True:
    if DetectedObject:
        send_data_toRoute(ws_rpiLaser,DetectedObject)  
    time.sleep(3)
   