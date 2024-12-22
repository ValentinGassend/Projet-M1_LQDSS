from btn.btn import Button

my_button = Button(23)
button_status = False

while True:
    if not button_status:
        button_status = my_button.check_status(2)  # Délai de 2 secondes
    else:
        print("Appui long détecté")
        # Effectuer les actions souhaitées pour l'appui long
        # ...
        button_status = False