import json
from os import path
from system_helper import SystemHelper


class CertificateHelper:
    ''' Helps genertae local self signed certificate '''

    scripts_directory_path = path.join(
        path.dirname(__file__), "..", "scripts")
    system_helper = SystemHelper()

    def generate(self):
        self.system_helper.execute(path.join(self.scripts_directory_path, "generate-certificate.sh"))
