import json
from os import path
import sys


class ConfigHelper:
    ''' Simplify working with the different required configuration files '''

    config_directory_path = path.join(
        path.dirname(__file__), "..", "config")

    def get_required_docker_images(self):
        config_file = path.join(
            self.config_directory_path, "common", "docker", "images.json")

        if not path.exists(config_file):
            raise Exception(f'Config file "{config_file}" does not exist')

        with open(config_file) as f:
            return json.load(f)
