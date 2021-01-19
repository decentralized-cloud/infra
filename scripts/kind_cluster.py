from os import path
from os import system


class KindCluster:
    ''' Wraps kind command line '''

    config_directory_path = path.join(
        path.dirname(__file__), "..", "config")

    def start(self, preload_images):
        config_file = path.join(self.config_directory_path, "local", "kind_config.yaml")
        system("kind create cluster --config \"{config_file}\" --wait 5m".format(config_file=config_file))

    def stop(self):
        system("kind delete cluster")
