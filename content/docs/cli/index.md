---
title: Foojank Client CLI Reference
description: Command-line reference for the Foojank client.
---
# Foojank Client CLI Reference

Foojank is controlled using a command-line client.
```
$ foojank [global options] [command [command options]]
```

## Commands

| Command | Description |
|---------|-------------|
| [`account`](account/) | Manage accounts |
| [`agent`](agent/) | Manage agents |
| [`config`](config/) | Manage configuration |
| [`job`](job/) | Manage jobs |
| [`profile`](profile/) | Manage profiles |
| [`storage`](storage/) | Manage storage |

## Global Options

| Option | Description |
|--------|-------------|
| `--no-color` | Disable color output |
| `--help`, `-h` | Show help |
| `--version`, `-v` | Print the version |

## Configuration

The Foojank client uses a directory-based configuration system. A configuration directory contains a `config.json` file with persistent settings and an optional `profiles.json` file with build profiles.

### Configuration Directory Discovery

When a command runs, Foojank locates the configuration directory using the following logic:

1. **Explicit path via `--config-dir`** — If the `--config-dir` flag is provided, Foojank uses that path directly.

2. **Automatic search** — If `--config-dir` is not set, Foojank searches for an existing configuration directory starting from the current working directory and walking up through each parent directory until one is found or the filesystem root is reached.

3. **Fallback** — If no configuration directory is found during the search, the behavior depends on the command. Commands that require server connectivity will fail with a configuration error. Commands that can operate without a configuration file fall back to using only the values provided via command-line flags.

### Initializing a Configuration Directory

Before using Foojank, you must initialize a configuration directory:

```
$ foojank config init
```

This creates the configuration directory structure in the current working directory (or in the path specified by `--config-dir`). If the directory has already been initialized, running `init` again will reinitialize it without removing existing settings.

### Configuration Options

The configuration file supports the following options:

| Option | Type | Description |
|--------|------|-------------|
| `server-url` | `string` | Server URL |
| `server-certificate` | `string` | Path to server's certificate |
| `account` | `string` | Account for server authentication |
| `format` | `string` | Output format: `table` or `json` |
| `no-color` | `bool` | Disable color output |

Options can be set and unset using [`config edit`](config/edit/):

```
$ foojank config edit --set server-url=wss://c2.example.com
$ foojank config edit --set account=my-account
$ foojank config edit --unset format
```

To view the current configuration, use [`config list`](config/list/):

```
$ foojank config list
```

### Configuration Precedence

When a command executes, the final effective configuration is assembled from multiple sources. Sources listed later take precedence over earlier ones:

1. **Configuration file** — Values stored in `config.json` within the discovered configuration directory are loaded first.

2. **Command-line flags** — Any flags passed directly on the command line override the corresponding values from the configuration file.

This means you can set baseline values in the configuration file (such as `server-url` and `account`) and override them on a per-invocation basis using flags. For example, if `config.json` contains `server-url` set to `wss://c2.example.com`, running the following command will use a different server for that invocation only:

```
$ foojank agent list --server-url wss://other-server.example.com
```
