# SSH OTP verification
This project provides for an extra authentication step, using
OTP, on top of standard SSH authentication methods.  It is
primarily developed with the key authentication use case in
mind, but could likely be adapted to password authentication
as well.

The purpose of the project is to add a strong second factor
(beyond private key encryption) to key authentication.  The
primary use case is for high security servers, and/or untrusted
clients (such as laptops) where restricting a key source by IP
address is not practical.

The OTP code is passed to the ssh server via an environment
variable, rather than interactively.  This prevents breaking
of the login conversation for such tools as sftp, scp, rsync,
etc.  This tool is tested and works with all such client software.

## Requirements/Usage
The tool requires that the `oathtool` command is available on
your target ssh server.  If not, you will need to install it.

To make use of the extra verification step, you will need to
configure SSHD on the target system to execute the otp_verify.sh
script for each protected user immediately upon login.  If
using ssh keys for authentication (recommended), you can do so
by associating a forced command with the client key in your
`~.ssh/authorized_keys` file on the server, like so:
```
command="/path/to/otp_verify.sh client1" ssh-rsa <public key>
```
Note that you must pass the identifier of the client as an
argument to this script.  This controls which files are used
for verification in the OTP state directory (see below).

Once fully setup and configured (see below), make use of the
new functionality by prepending the OTP code to your ssh command
from the client, like: `OTP_CODE=123456 ssh someuser@somehost`

## Setup/Configuration
You will first need to create a shared secret to use as a seed for
generating OTP codes.  Something like this should work:
```
dd if=/dev/random bs=1M count=1 status=none | sha256sum | cut -b 1-30
oathtool --totp -v <the code from above>
```
The output from the `oathtool` command above will give you the
base32 encoded secret, this is what gets stored in the secrets
file in your state directory and also put on your prover.

On the target ssh server, you will also need to modify `sshd_config`
to accept the `OTP_CODE` environment variable over the encrypted
connection.  Add a line like the following:
```
AcceptEnv OTP_CODE
```

Also on the target server, you will need to create the state
tracking directory in your homedir.  This directory stores the
shared secrets and the counter files (to prevent code reuse).
You should ensure this directory is appropriately protected from
other users gaining access (e.g. mode 700).  The name of this
directory is `.otp_state` by default, but it can be changed from
within the script.  Directory layout is as follows:
```
.
|->secrets
|  |->client1
|  |->client2
|->counters
|  |->client1
|  |->client2
```

Finally, you will need to modify your ssh client config to send
the `OTP_CODE` variable when connecting to your server.  You can
put something like the following in your `~/.ssh/config`:
```
Host somehost
	HostName somehost.example.com
	SendEnv OTP_CODE
```

## Known Issues
* No known issues at this time
