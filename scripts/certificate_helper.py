import json
from os import path
from os import system


class CertificateHelper:
    ''' Helps genertae local self signed certificate '''

    scripts_directory_path = path.join(
        path.dirname(__file__), "..", "scripts")

    def generate(self):
        system(path.join(self.scripts_directory_path, "generate-certificate.sh"))
