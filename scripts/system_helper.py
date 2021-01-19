from os import system


class SystemHelper:
    ''' Wraps kind command line '''

    def execute(self, command):
        print("Executing command: \"{command}\"".format(command=command))
        exit_code = system(command)
        print("Finished executing command with exit code {exit_code} : \"{command}\"".format(command=command, exit_code=exit_code))

