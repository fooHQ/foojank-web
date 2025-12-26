Foojank is a command-and-control (C2) framework that uses [NATS](https://nats.io) for C2 communications.

Foojank leverages the NATS features to offer:

* Synchronous or asynchronous communication with Agents over TCP or WebSockets.
* Server-based storage for file sharing and data exfiltration.
* Full observability.
* Extensibility.

Foojank is distributed under the [Apache License Version 2.0](https://github.com/fooHQ/foojank/blob/main/LICENSE).

## Server Installation

The simplest way to install the server is to run the installation script:

```
$ curl -fsSL https://github.com/fooHQ/foojank/releases/latest/download/server.sh | sh
```

The installation script is going to install:

* The latest [nats-server](https://github.com/nats-io/nats-server).
* The default nats-server configuration.
* The latest [nsc](https://github.com/nats-io/nsc) utility.

The installation script is not going to generate a TLS certificate, and manual configuration is required. See [Server Configuration](#server-configuration) for more details.

**Systemd**

The installation script expects an environment running Systemd, and as such it will attempt to install a service unit file. [NATS installation](https://docs.nats.io/running-a-nats-service/introduction/installation) guide covers installation of NATS on other operating systems without Systemd.

## Server Configuration

This chapter assumes that the installation has been done using the installation script.
Installation methods that are not compatible with the installation script may require additional steps that are not documented here.
Refer to [NATS documentation](https://docs.nats.io/running-a-nats-service/configuration) for in-depth information about server configuration.

Quick facts about the default configuration:

* Configuration is stored in `/etc/nats-server.conf`.
* Server data are stored in `/opt/nats`.
* Server is running as `nats` user.
* Server is listening on `4222/tcp` and `8443/tcp`.

### Authentication

NATS server uses JWT-based authentication and authorization. JWT-based authentication/authorization uses a hierarchy of entities to establish a chain of trust. Each entity is represented by a JWT and a cryptographic key pair used to create signatures or verify them.

* **Operators** are responsible for running NATS servers. Operators set limits on what Accounts can do and are responsible for issuing Account JWTs.

* **Accounts** are used as isolation contexts. Accounts are responsible for issuing User JWTs. A User in one Account cannot access resources in other Accounts unless they have been explicitly granted access.

* **Users** are used for authentication with the server. A User limits which subjects are accessible to the client in the context of an Account.

The installation script creates a new Operator and a System account. System account is reserved for operations and monitoring of the server and should not be used for any other purpose. For engagements a new Account should be created and imported to the server.
How to generate a new Account and import it is described in [Account Configuration](#account-configuration).

### TLS Configuration

By default, the server requires a TLS certificate to be configured. The installation script does not generate a TLS certificate, and manual configuration is required.
This guide covers a configuration using a self-signed certificate.

Although NATS is compatible with Automatic Certificate Management Environment (ACME) clients, it requires additional steps that are not covered in this guide. [Reach out](#support) if you need help with ACME configuration.

To create a new self-signed certificate, create a file `san.cnf` with the following configuration:

```
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = 167.172.161.148

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = 167.172.161.148
DNS.1 = example.com
```

Replace the IP address and DNS name with the IP address and DNS name of the server. Use `openssl` to generate a self-signed certificate and a private key:

```
$ openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout private.key -out certificate.crt -config san.cnf -extensions v3_req
```

Copy the certificate and private key to any directory and make sure they are readable by the `nats` user:

```
# cp certificate.crt private.key /opt/nats/
# chown nats:nats /etc/nats/certificate.crt /opt/nats/private.key
```

Edit the server configuration to use the certificate and the key. TLS should be enabled for both the TCP and the WebSocket ports:

```
tls {
    cert_file: "/opt/nats/certificate.crt"
    key_file: "/opt/nats/private.key"
}
```

Restart the server to apply the changes:

```
# systemctl restart nats-server
```

## Client Installation

It is recommended to install the client on the end devices and not on the server. This way, Accounts and User keys are not exposed to the server.

To install the client, run the installation script:

```
$ curl -fsSL https://github.com/fooHQ/foojank/releases/latest/download/client.sh | sh
```

The installation script is going to install:

* The latest version of Foojank client.
* Nix package manager.
* The latest version of [Devbox](https://www.jetify.com/devbox).

Devbox is used to manage dependencies and to interact with Agent development environments.
Devbox is built with the Nix package manager which installs packages in the Nix store. Installed Nix packages do
not conflict with already installed software, and multiple versions of the same package can be installed at the same time.
**Unfortunately, Nix is not compatible with Windows at this time, which makes the client incompatible with Windows as well.**

Once the installation is complete, run `foojank` to start the client:

```
$ foojank
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

## Client Configuration

Foojank configuration is managed using the `config` command. To create an initial configuration, run:

```
$ foojank config init
```

The command will create a hidden directory `.foojank` in the current directory. The directory contains JSON configuration files.
The files should not be modified manually. Instead, use the `config edit` command.

For instance, the following command will set the server URL to `nats://127.0.0.1`:

```
$ foojank config edit --set server_url=nats://127.0.0.1
```

To unset a configuration option, use the `--unset` flag:

```
$ foojank config edit --unset server_url
```

To view all available configuration options and their values, run:

```
$ foojank config list
┌────────────────────┬──────────────────┬───────────────────────────────────┐
│       OPTION       │      VALUE       │            DESCRIPTION            │
├────────────────────┼──────────────────┼───────────────────────────────────┤
│ server_url         │ nats://127.0.0.1 │ Server URL                        │
│ server_certificate │                  │ Path to server's certificate      │
│ account            │                  │ Account for server authentication │
│ format             │ table            │ Output format: table or json      │
│ no_color           │ false            │ Color output                      │
└────────────────────┴──────────────────┴───────────────────────────────────┘
```

## Support

Reach us at **hello@foohq.io** if you need help with Foojank. For bugs and feature requests, please [open an issue](https://github.com/fooHQ/foojank/issues) or join a [discussion](https://github.com/fooHQ/foojank/discussions) on GitHub.
