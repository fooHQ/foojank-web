---
title: foojank agent build
description: Build an agent and create resources on the server. Foojank Client CLI Reference.
---

# agent build

Build an agent binary and register it on the server. The build process generates agent credentials, compiles the agent source code, and registers the agent with the C2 server. A random agent name is assigned automatically.

```
$ foojank agent build [options]
```

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--profile` | `string` | Set profile |
| `--os` | `string` | Set target operating system |
| `--arch` | `string` | Set target architecture |
| `--feature` | `string[]` | Enable build features |
| `--server` | `string` | Set agent's server URL |
| `--certificate` | `string` | Set path to agent's server certificate |
| `--output`, `-o` | `string` | Set path to an output file |
| `--source-dir` | `string` | Set path to a source code directory |
| `--set` | `string[]` | Set environment variable, format: `key=value` |
| `--unset` | `string[]` | Unset environment variable, format: `key` |
| `--server-url` | `string` | Set server URL (**required**) |
| `--server-certificate` | `string` | Set path to server's certificate |
| `--account` | `string` | Set server account (**required**) |
| `--config-dir` | `string` | Set path to a configuration directory |

## Configuration Precedence

The build command assembles its final configuration from three sources. Each source takes precedence over the one before it:

1. **Defaults** — Internal defaults are set automatically, including a generated agent ID, the current OS and architecture, a working-directory-based output path, and the server connection details from the configuration file.

2. **Profile file** — If `--profile` is specified, the named profile is loaded from the configuration directory. Profile values (such as `os`, `arch`, `source-dir`, and `features`) override the defaults.

3. **Command-line flags** — Flags passed directly on the command line (`--os`, `--arch`, `--output`, `--server`, `--certificate`, `--feature`, `--source-dir`, `--set`) override both defaults and profile values.

After merging, any variables named by `--unset` are removed from the final configuration.

For example, if a profile named `linux-amd64` sets `os=linux` and `arch=amd64`, you can override just the architecture for a single build:

```
$ foojank agent build --profile linux-amd64 --arch arm64
```
