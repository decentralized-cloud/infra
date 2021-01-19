import json
import os
from config_helper import ConfigHelper

class DockerImageHelper:
    ''' Docker Image Helper '''

    def pull_latest_images(self):
        dockerImages = ConfigHelper().get_required_docker_images()

        for dockerImage in dockerImages:
            os.system("docker pull {dockerImage}".format(dockerImage=dockerImage))
