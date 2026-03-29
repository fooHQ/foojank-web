---
title: foojank storage remove
description: Remove file from a storage. Foojank Client CLI Reference.
---

# storage remove

Remove one or more files from a storage. Each argument must be a storage path in the format `<storage-name>:<file-path>`. Local paths and directories cannot be removed with this command.

```
$ foojank storage remove [options] <storage>:<file>...
$ foojank storage rm [options] <storage>:<file>...
```


## Arguments

| Argument | Description |
|----------|-------------|
| `<storage>:<file>...` | One or more storage file paths to remove |

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--server-url` | `string` | Set server URL (**required**) |
| `--server-certificate` | `string` | Set path to server's certificate |
| `--account` | `string` | Set server account (**required**) |
| `--config-dir` | `string` | Set path to a configuration directory |

