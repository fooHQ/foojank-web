Foojank is an open-source command-and-control (C2) framework built on NATS, designed for ethical hackers conducting red
team and purple team engagements. It provides a scalable, observable, and extensible C2 platform for adversary
simulation and security testing.

Foojank is distributed under the [Apache License Version 2.0](https://github.com/fooHQ/foojank/blob/main/LICENSE).

**Features**

* Customizable C2 transport over TCP and WebSockets.
* Built-in file storage for payload distribution and data exfiltration.
* Extensible support for custom and third-party agents.
* Observability, including visibility into agent activity and C2 messaging.

## Quick Start

This section walks you through a minimal, local setup of Foojank.

### Install the server

```
$ curl -fsSL https://github.com/fooHQ/foojank/releases/latest/download/server.sh | bash
```

At the end of the installation, the script reports whether the server started successfully. Review the output carefully
and resolve any reported errors before continuing.


### Install the client

Download and run the client installation script:

```
$ curl -fsSL https://github.com/fooHQ/foojank/releases/latest/download/client.sh | bash
```

Verify that the client was installed correctly by running:

```
$ foojank
```

If successful, the command prints usage information similar to the following:

```
NAME:
   foojank - Command and control framework

USAGE:
   foojank [global options] [command [command options]]

VERSION:
   0.4.2

COMMANDS:
   account  Manage accounts
   agent    Manage agents
   config   Manage configuration
   job      Manage jobs
   profile  Manage profiles
   storage  Manage storage

GLOBAL OPTIONS:
   --no-color     disable color output
   --help, -h     show help
   --version, -v  print the version
```

### Create and configure an Account

Create a new Account:

```
$ foojank account create
```

Export the Account JWT to a file:

```
$ foojank account export eminent_oryx > /tmp/account.jwt
```

Import the Account JWT into `nsc`:

```
$ nsc import account --file /tmp/account.jwt
```

Successful import results in output similar to the following:

```
[WARN] validation resulted in: self-signed account JWTs shouldn't contain operator limits
[ OK ] account eminent_oryx was successfully imported
1 job succeeded - 1 have warnings
```

Push the Account to the server:

```
$ nsc push --account eminent_oryx -u nats://127.0.0.1
```

A successful push confirms that the Account is now available to the NATS server:

```
[ OK ] push to nats-server "nats://127.0.0.1" using system account "SYS":
       [ OK ] push eminent_oryx to nats-server with nats account resolver:
              [ OK ] pushed "eminent_oryx" to nats-server NBCLO6VIMZSMCLEZH4WS6TYIRUSSFGCFALSWMKTEZT6RXISIH22DF52P: jwt updated
              [ OK ] pushed to a total of 1 nats-server
```

### Initialize client configuration

Initialize client configuration in the current directory (or specify a different directory using `--config-dir`):

```
$ foojank config init
```

Set the server URL and the Account:

```
$ foojank config edit --set server_url=nats://127.0.0.1 --set account=eminent_oryx
```

Verify the configuration by listing Agents:

```
$ foojank agent list
```

Since no Agents are running yet, the list will be empty.

### Build an Agent

Clone a repository containing an Agent development environment, such as [Vessel](https://github.com/foohq/vessel):

```
$ git clone https://github.com/fooHQ/vessel
```

Import predefined Agent profiles:

```
$ foojank profile import ./vessel/profiles.json
```

List available profiles:

```
$ foojank profile list
```

Select a profile and build an Agent. To enable development features, add `--feature dev`:

```
$ foojank agent build --profile vessel-linux-amd64 --feature dev
```

### Run the Agent

Start the Agent binary:

```
./immune-heron
```

Once started, the Agent connects to the server.

Verify that the Agent is connected:

```
$ foojank agent list
```

The Agent should now appear in the output, confirming a successful connection.
At this point, the Agent is ready to receive commands.

## Support

If you need help with Foojank, contact us at **hello@foohq.io**.

For bugs and feature requests, please [open an issue](https://github.com/fooHQ/foojank/issues) or start a [discussion](https://github.com/fooHQ/foojank/discussions) on GitHub.