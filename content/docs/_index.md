---
title: Documentation
---

Welcome to Foojank documentation!

## What is Foojank?

Foojank is a command-and-control (C2) framework written in Go, designed for red and purple team engagements across GNU/Linux, Windows, and macOS.
Foojank's agent includes a built-in [Risor](https://risor.io) scripting engine, enabling extensibility through custom scripts. Operators can enhance functionality by adding Risor
modules, which scripts leverage to implement high-level commands, such as file exfiltration or system reconnaissance.
Foojank uses [NATS](https://nats.io) as its C2 server for robust, scalable, and secure communication.

## Features

- **Malleable Scripting Engine**: Foojank's agent, **Vessel**, integrates the [Risor](https://risor.io) scripting engine, enabling operators to execute custom scripts filelessly within the agent's runtime context. For example, a Risor script can enumerate running processes or exfiltrate data without deploying additional binaries, ensuring stealth in red/purple team operations.

- **Robust Backend**: Foojank's C2 server leverages [NATS](https://nats.io), a high-performance message broker supporting Request-Reply communication, stream-like data access, and persistent consumers. It enables secure, real-time agent-client communication over WebSocket and uses NATS ObjectStore for shared storage. For instance, operators can perform data exfiltration or distribute payloads via the ObjectStore.

- **Virtual Filesystems**: Foojank provides a filesystem-like API to streamline interaction with protocols and resources like SSH, SMB, NATS, and Windows Registry. This allows operators to, for example, access a remote SMB share as if it were a local directory, simplifying data transfer in complex environments.

- **Simple and Local-First Design**: Foojank uses a single, Docker-inspired command-line tool with a minimal command set for ease of use. Its Local-First workflows prioritize local execution, making it intuitive to extend the framework. For example, operators can test scripts locally before deploying them to remote agents.

- **Built in Go**: Written in Go, Foojank benefits from Go's simplicity, fast compilation, and cross-platform support, ensuring seamless deployment across GNU/Linux, Windows, and macOS. Statically linked binaries eliminate runtime dependency issues, enabling rapid setup in diverse environments.

- **Self-Contained Dependencies**: Foojank manages dependencies with [Devbox](https://www.jetify.com/devbox), using Nix to version dependencies. This allows multiple software versions to coexist without conflicts or OS modifications.


## License

This software is distributed under the Apache License Version 2.0 found in the [LICENSE](https://github.com/fooHQ/foojank/blob/main/LICENSE) file.
