import json
from config_helper import ConfigHelper
from system_helper import SystemHelper

class DockerImageHelper:
    ''' Docker Image Helper '''

    system_helper = SystemHelper()

    def pull_latest_images(self):
        dockerImages = ConfigHelper().get_required_docker_images()

        for dockerImage in dockerImages:
            self.system_helper.execute("docker pull {dockerImage}".format(dockerImage=dockerImage))
