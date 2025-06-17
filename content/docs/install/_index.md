---
title: Install Foojank
weight: 1
---

Foojank is available as a pre-compiled binary or as a source code you can build yourself.

{{< tabs items="Linux,macOS,Windows" defaultIndex="0" >}}
{{< tab >}}
```
$ curl https://foojank.com/install.sh | bash
```
{{< /tab >}}
{{< tab >}}
```
$ curl https://foojank.com/install.sh | bash
```
{{< /tab >}}
{{< tab >}}
```
Windows support is currently unavailable, except for the agent, which can run on Windows.
```
{{< /tab >}}
{{< /tabs >}}

## Compiling from source code

To compile from source code, you will need Git and [Devbox](https://www.jetify.com/devbox) installed before you can start.
All Foojank dependencies, including the Go toolchain, are managed by Devbox, which uses Nix to version the dependencies.
Installing Foojank dependencies will not interfere with already installed versions of the same software as Nix uses
isolated environments and thus multiple versions of a software can coexist.

1. Clone the Foojank repository from Github:

```
$ git clone https://github.com/foohq/foojank
$ cd foojank
```

2. Install Foojank dependencies:

```
$ devbox install
```

3. Build Foojank for your current system:

```
$ devbox run build-foojank-prod
```

4. Copy Foojank executable to a system path:

```
$ cp build/foojank /usr/local/bin
```

### Cross-compiling for other platforms

Cross-compilation is controlled by two environment variable - `GOOS` and `GOARCH`. To build Foojank for Linux running on
amd64 architecture you can run build script.

```
$ GOOS=linux GOARCH=amd64 devbox run build-foojank-prod
```

While it may be tempting to build Foojank for Windows, it is not feasible. The issue is that Nix currently does not support Windows.

## Verify the installation

To verify Foojank was installed correctly, try the `foojank` command.

```
$ foojank
```

If Foojank was installed correctly, you should see help output, similar to the following.

```
NAME:
   foojank - A cross-platform command and control (C2) framework

USAGE:
   foojank [global options] [command [command options]]

VERSION:
   0.3.0

COMMANDS:
   agent       Manage agents
   script      Manage scripts
   repository  Manage repositories
   config      Manage configuration files
   server      Manage server

GLOBAL OPTIONS:
   --config string, -c string  set path to a configuration file
   --log-level string          set log level
   --no-color                  disable color output (default: false)
   --help, -h                  show help
   --version, -v               print the version
```
