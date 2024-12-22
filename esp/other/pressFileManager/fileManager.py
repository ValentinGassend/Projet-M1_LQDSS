import json

class ButtonPressCounter:
    def __init__(self, file_name):
        self.file_name = file_name

    def read_data(self):
        try:
            with open(self.file_name, 'r') as file:
                data = json.load(file)
            return data
        except FileNotFoundError:
            return None

    def write_data(self, data):
        with open(self.file_name, 'w') as file:
            json.dump(data, file)

    def add_button_press(self):
        data = self.read_data()
        if data is None:
            data = {'count': 1}
        else:
            data['count'] += 1
        self.write_data(data)

    def update_button_press(self, count):
        data = self.read_data()
        if data is not None:
            data['count'] = count
            self.write_data(data)

    def delete_button_press(self):
        data = self.read_data()
        if data is not None:
            data['count'] = 0
            self.write_data(data)