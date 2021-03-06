#!/usr/bin/env python3

"""
The module responsible to setup the edge cloud required resources
"""

__author__ = "Morteza Alizadeh"
__version__ = "0.1.0"
__license__ = "AGPL 3.0"

import argparse
from sys import exit
from os import linesep
from certificate_helper import CertificateHelper
from docker_images_helper import DockerImageHelper
from cluster_helper import ClusterHelper
from istio_helper import IstioHelper
from edge_cloud_helper import EdgeCloudHelper


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
                "deploy-services and remove-services cannot be used together")

        if args.stop and args.deploy_services:
            raise Exception("stop and deploy-services cannot be used together")

        if args.stop and args.deploy_istio_addons:
            raise Exception(
                "stop and deploy-istio-addons cannot be used together")

        cluster_helper = ClusterHelper(args.env, args.filter_environment)

        if args.start:
            cluster_helper.start(args.preload_images)
        elif args.stop:
            cluster_helper.stop()

        if args.deploy_istio_addons:
            IstioHelper().deploy_addons()

        edge_cloud_helper = EdgeCloudHelper(args.env, args.filter_environment)

        if args.deploy_services:
            edge_cloud_helper.deploy_services(args.services)

        if args.remove_services:
            edge_cloud_helper.remove_services(args.services)

    except Exception as exception:
        print(exception)
        exit(1)


if __name__ == "__main__":
    """ This is executed when run from the command line """
    parser = argparse.ArgumentParser(
        description=("Edge Cloud CLI" + linesep +
                     "Author: {author}" + linesep +
                     "{version}").format(author=__author__, version=__version__), formatter_class=argparse.RawTextHelpFormatter)

    parser.add_argument("--generate-certificate", action="store_true",
                        default=False, help="Generate local self signed certificate")
    parser.add_argument("--pull-latest-images", action="store_true",
                        default=False, help="Pull latest required docker images")
    parser.add_argument("-s", "--start", action="store_true",
                        default=False, help="Start the cluster")
    parser.add_argument("-r", "--stop", action="store_true",
                        default=False, help="Stop the cluster")
    parser.add_argument("--preload-images", action="store_true",
                        default=False, help="Preload images after cluster started")
    parser.add_argument("--deploy-services", action="store_true",
                        default=False, help="Deploy Edge Cloud required services")
    parser.add_argument("--remove-services", action="store_true",
                        default=False, help="Remove Edge Cloud required services")
    parser.add_argument("--deploy-istio-addons", action="store_true",
                        default=False, help="Deploy istio addons")
    parser.add_argument("--env", action="store",
                        default="local_kind", help="Specify the deployment environment to start the cluster on. Possibles Options are: " +
                        linesep +
                        "local_kind" +
                        linesep +
                        "local_windows" +
                        linesep +
                        "remote")
    parser.add_argument("--filter-environment", action="store",
                        default="", help="Specify the different environments. Possibles Options are: " +
                        linesep +
                        "dev" +
                        linesep +
                        "test" +
                        linesep +
                        "prod")
    parser.add_argument("--services", nargs="+",
                        default=["user", "project", "edge-cluster", "api-gateway", "console"], help="List of service to deploy or remove")
    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s (version {version})".format(version=__version__))

    args = parser.parse_args()
    main(args)
