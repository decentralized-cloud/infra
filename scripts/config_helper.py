import json
from os import path


class ConfigHelper:
    ''' Simplify working with the different required configuration files '''

    config_directory_path = path.join(
        path.dirname(__file__), "..", "config")

    def get_config_root_Directory(self):
        return self.config_directory_path

    def get_required_docker_images(self):
        with open(path.join(
                self.config_directory_path, "common", "docker", "images.json")) as f:
            return json.load(f)
