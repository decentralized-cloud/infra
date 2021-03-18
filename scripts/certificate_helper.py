import json
from os import path
from os import makedirs
from system_helper import SystemHelper
from config_helper import ConfigHelper


class CertificateHelper:
    ''' Helps genertae local self signed certificate '''

    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def generate(self):
        root_directory_path = self.config_helper.get_root_directory()
        certificate_directory = self.config_helper.get_certificates_directory()
        docker_directory = path.join(root_directory_path, "docker")

        if not path.exists(certificate_directory):
            makedirs(certificate_directory)

        dockerfile_path = path.join(
            docker_directory, "Dockerfile.generate-certificate")

        self.system_helper.execute("docker build -f \"{dockerfile_path}\" -t generate-certificate \"{build_context}\"".format(
            dockerfile_path=dockerfile_path, build_context=root_directory_path))

        self.system_helper.execute(
            "docker create --name extract-generate-certificate generate-certificate")

        ca_key_filepath = path.join(certificate_directory, "ca.key")
        ca_crt_filepath = path.join(certificate_directory, "ca.crt")

        self.system_helper.execute(
            "docker cp extract-generate-certificate:/src/certificates/ca.key \"{ca_key_filepath}\"".format(ca_key_filepath=ca_key_filepath))

        self.system_helper.execute(
            "docker cp extract-generate-certificate:/src/certificates/ca.crt \"{ca_crt_filepath}\"".format(ca_crt_filepath=ca_crt_filepath))

        self.system_helper.execute("docker rm extract-generate-certificate")
