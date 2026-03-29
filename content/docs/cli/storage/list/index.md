---
title: foojank storage list
description: List storages or their contents. Foojank Client CLI Reference.
---

# storage list

List all available storages, or list the contents of a specific storage path. Without arguments, shows all storages with their name, size, and description. With a path argument, lists files and directories at that location.

```
$ foojank storage list [options] [storage:<file> ...]
$ foojank storage ls [options] [storage:<file> ...]
```


## Arguments

| Argument | Description |
|----------|-------------|
| `[storage:<file> ...]` | Optional storage paths to list. If omitted, all storages are listed. When a path contains no `:` separator, it is treated as a storage name and the root directory is listed. |

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--format` | `string` | Set output format (`table`, `json`) |
| `--server-url` | `string` | Set server URL (**required**) |
| `--server-certificate` | `string` | Set path to server's certificate |
| `--account` | `string` | Set server account (**required**) |
| `--config-dir` | `string` | Set path to a configuration directory |

