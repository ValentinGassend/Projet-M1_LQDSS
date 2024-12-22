import json

class AppointmentManager:
    def __init__(self, file_name):
        self.file_name = file_name
        self.appointments = self.load_appointments()

    def load_appointments(self):
        try:
            with open(self.file_name, 'r') as file:
                appointments = json.load(file)
                return appointments
        except FileNotFoundError:
            return []

    def check_appointment(self, target_date):
        target_date_parts = target_date.split(' ')
        target_date_parts = target_date_parts[0].split('-') + target_date_parts[1].split(':')
        target_date_parts = list(map(int, target_date_parts))

        for appointment in self.appointments:
            appointment_date_parts = appointment['date'].split(' ')
            appointment_date_parts = appointment_date_parts[0].split('-') + appointment_date_parts[1].split(':')
            appointment_date_parts = list(map(int, appointment_date_parts))

            if appointment_date_parts == target_date_parts:
                return True

        return False
