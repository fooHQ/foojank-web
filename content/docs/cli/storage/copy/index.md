---
title: foojank storage copy
description: Copy files between local filesystem and a storage or vice versa. Foojank Client CLI Reference.
---

# storage copy

Copy files between the local filesystem and a remote storage. Exactly one of the source or destination must be a storage path (prefixed with a storage name and `:`), and the other must be a local path.

Copying between two local paths or two storage paths is not supported.

If the destination is a directory (trailing `/`), the source filename is preserved.

```
$ foojank storage copy [options] [storage:]<file> [storage:]<destination-path>
$ foojank storage cp [options] [storage:]<file> [storage:]<destination-path>
```


## Arguments

The command takes exactly two positional arguments: a source and a destination. Prefix a path with `<storage-name>:` to indicate a remote storage path. Unprefixed paths are treated as local filesystem paths.

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--server-url` | `string` | Set server URL (**required**) |
| `--server-certificate` | `string` | Set path to server's certificate |
| `--account` | `string` | Set server account (**required**) |
| `--config-dir` | `string` | Set path to a configuration directory |

