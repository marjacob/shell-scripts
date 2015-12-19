If you've written service files for systemd you've probably experienced that some applications return unexpected (non-zero) exit codes, even when terminating successfully. I had to deal with this when I wrote the service file for this blog which is running on Node.js.

>`SIGTERM` and `SIGINT` have default handlers on non-Windows platforms that resets the terminal mode before exiting with code `128 + signal number`. If one of these signals has a listener installed, its default behaviour will be removed (node will no longer exit).

By default, when killed with `SIGTERM`, Node.js exits with the status code 143. That is `128 + SIGTERM`. This is expected behavior but it causes the following annoying error message in the system journal.

	Unit example.service entered failed state.

The solution is to explicitly define the expected exit code in the service file with the `SuccessExitStatus` option under the `[Service]` section. 

	[Service]
	SuccessExitStatus=143

# Sources
- [Node.js v5.2.0 Documentation](https://nodejs.org/api/process.html)
- [Sylvain Leroux on StackOverflow](http://stackoverflow.com/a/25136737)
