from os import path
from config_helper import ConfigHelper
from system_helper import SystemHelper


class KindCluster:
    ''' Wraps kind command line '''

    config_directory_path = path.join(
        path.dirname(__file__), "..", "config")
    config_helper = ConfigHelper()
    system_helper = SystemHelper()

    def start(self, preload_images):
        config_file = path.join(
            self.config_directory_path, "local", "kind_config.yaml")
        self.system_helper.execute(
            "kind create cluster --config \"{config_file}\" --wait 5m".format(config_file=config_file))

        if preload_images:
            docker_images = self.config_helper.get_required_docker_images()

            for docker_image in docker_images:
                self.system_helper.execute(
                    "kind load docker-image \"{docker_image}\"".format(docker_image=docker_image))

    def stop(self):
        self.system_helper.execute("kind delete cluster")
