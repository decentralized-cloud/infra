from os import system


class SystemHelper:
    ''' Wraps functions available to us through standard Python system package '''

    def execute(self, command):
        print("Executing command: \"{command}\"".format(command=command))
        exit_code = system(command)
        print("Finished executing command with exit code {exit_code} : \"{command}\"".format(
            command=command, exit_code=exit_code))

        return exit_code
