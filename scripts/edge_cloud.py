#!/usr/bin/env python3

"""
The module responsible to setup the edge cloud required resources
"""

__author__ = "Morteza Alizadeh"
__version__ = "0.1.0"
__license__ = "AGPL 3.0"

import argparse
import sys
from certificate_helper import CertificateHelper
from docker_images_helper import DockerImageHelper


def main(args):
    """ Main entry point of the Edge Cloud CLI """
    try:
        if args.generate_certificate:
            CertificateHelper().generate()

        if args.pull_latest_images:
            DockerImageHelper().pull_latest_images()

        if args.start and args.stop:
            raise Exception("start and stop cannot be used together")

        if args.deploy_services and args.remove_services:
            raise Exception(
                "deploy_services and remove_services cannot be used together")

        if args.stop and args.deploy_services:
            raise Exception("stop and deploy_services cannot be used together")

    except Exception as exception:
        print(exception)
        sys.exit(1)


if __name__ == "__main__":
    """ This is executed when run from the command line """
    parser = argparse.ArgumentParser(
        description=("Edge Cloud CLI\n" +
                     "Author: {author}\n" +
                     "{version}\n").format(author=__author__, version=__version__), formatter_class=argparse.RawTextHelpFormatter)

    parser.add_argument("--generate_certificate", action="store_true",
                        default=False, help="Generate local self signed certificate")
    parser.add_argument("--pull_latest_images", action="store_true",
                        default=False, help="Pull latest required docker images")
    parser.add_argument("-s", "--start", action="store_true",
                        default=False, help="Start the cluster")
    parser.add_argument("-r", "--stop", action="store_true",
                        default=False, help="Stop the cluster")
    parser.add_argument("--pre-load-images", action="store_true",
                        default=False, help="Preload images after cluster started")
    parser.add_argument("--deploy_services", action="store_true",
                        default=False, help="Deploy Edge Cloud required services")
    parser.add_argument("--remove_services", action="store_true",
                        default=False, help="Remove Edge Cloud required services")
    parser.add_argument("--env", action="store",
                        default="LOCAL_KIND", help="Specify the environment to start the cluster on. Possibles Options are: \n"+"LOCAL_KIND")
    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s (version {version})".format(version=__version__))

    args = parser.parse_args()
    main(args)
