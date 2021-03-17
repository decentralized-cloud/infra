import json
from os import path


class ConfigHelper:
    ''' Simplify working with the different required configuration files '''

    root_directory_path = path.join(
        path.dirname(__file__), "..")

    config_directory_path = path.join(
        path.dirname(__file__), "..", "config")

    docker_directory_path = path.join(
        path.dirname(__file__), "..", "docker")

    def get_root_directory(self):
        return self.root_directory_path

    def get_config_root_directory(self):
        return self.config_directory_path

    def get_docker_directory(self):
        return self.docker_directory_path

    def get_required_docker_images(self):
        with open(path.join(
                self.config_directory_path, "common", "docker", "images.json")) as f:
            return json.load(f)

    def get_environments(self):
        with open(path.join(
                self.config_directory_path, "common", "edge-cloud", "environments.json")) as f:
            return json.load(f)
