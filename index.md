# Foojank

Foojank is a prototype command-and-control (C2) framework that uses [NATS](https://nats.io) for C2 communications.

Foojank leverages the NATS features to offer:

* Asynchronous or real-time communication with Agents over TCP or WebSockets.
* Server-based storage for file sharing and data exfiltration.
* JWT-based authentication and authorization.
* Full observability.
* Extensibility.

Foojank is currently compatible only with our prototype agent, [Vessel](https://github.com/foohq/vessel). However, we plan to implement support for integrating custom agents into the framework in the future.

### License

Foojank is distributed under the [Apache License Version 2.0](https://github.com/fooHQ/foojank/blob/main/LICENSE).

## Server Installation

The simplest way to install the server is to run the installation script:

```
$ curl -fsSL https://github.com/fooHQ/foojank/releases/latest/download/server.sh | sh
```

The installation script is going to:

* Install the latest NATS server.
* Install nsc utility.
* Install default configuration.

The installation script is not going to generate a TLS certificate, and manual configuration is required. See [Server Configuration](#server-configuration) for more details.

### Systemd

The installation script expects an environment running Systemd and as such will attempt to install a service unit file. [NATS installation](https://docs.nats.io/running-a-nats-service/introduction/installation) guide covers installation of NATS on other operating systems without Systemd.

## Server Configuration

This chapter assumes the installation was performed using the provided installation script.
Installation methods that are not compatible with the installation script may require additional steps that are outside the scope of this guide. Refer to NATS documentation for in-depth information about server configuration.

Quick facts about the configuration:

* Configuration is stored in `/etc/nats-server.conf`.
* Server data are stored in `/opt/nats`.
* Server is listening on `4222/tcp` and `8443/tcp`.
* Server is using JWT-based authentication/authorization.

### Authentication

JWT-based authentication/authorization uses a hierarchy of entities to establish a chain of trust. Each entity is represented by a JWT and a cryptographic key pair.

* **Operators** are responsible for running NATS servers. Operators set limits on what Accounts can do and are responsible for issuing Account JWTs.

* **Accounts** are used as isolation contexts. Accounts are responsible for issuing User JWTs. A User in one Account cannot access resources in other Accounts unless they have been explicitly granted access.

* **Users** are used for authentication with the server. A User limits which subjects are accessible to the client in the context of an Account.

The installation script creates a new Operator and a System account. System account is reserved for operations and monitoring of the server and should not be used for any other purpose. For engagements a new Account should be created and imported to the server.
How to generate a new Account and import it is described in [Account Configuration](#account-configuration).

### TLS Configuration

By default, the server requires a TLS certificate to be configured. The installation script does not generate a TLS certificate, and manual configuration is required.
This guide covers a configuration using a self-signed certificate.

Although NATS is compatible with Automatic Certificate Management Environment (ACME) clients, it requires additional steps that are not covered in this guide. [Reach out](#support) to us if you need help with ACME configuration.

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

## Support

Reach out to us at **hello@foohq.io** if you need help with Foojank. For bugs and feature requests please [open an issue](https://github.com/fooHQ/foojank/issues) or join a [discussion](https://github.com/fooHQ/foojank/discussions) on GitHub.
