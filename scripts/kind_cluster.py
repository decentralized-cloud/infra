from os import path
from system_helper import SystemHelper

class KindCluster:
    ''' Wraps kind command line '''

    config_directory_path = path.join(
        path.dirname(__file__), "..", "config")
    system_helper = SystemHelper()

    def start(self, preload_images):
        config_file = path.join(self.config_directory_path, "local", "kind_config.yaml")
        self.system_helper.execute("kind create cluster --config \"{config_file}\" --wait 5m".format(config_file=config_file))

    def stop(self):
        self.system_helper.execute("kind delete cluster")
