import json
from config_helper import ConfigHelper
from system_helper import SystemHelper


class DockerImageHelper:
    ''' Docker Image Helper '''

    system_helper = SystemHelper()
    config_helper = ConfigHelper()

    def pull_latest_images(self):
        docker_images = self.config_helper.get_required_docker_images()

        for docker_image in docker_images:
            self.system_helper.execute(
                "docker pull {docker_image}".format(docker_image=docker_image))
