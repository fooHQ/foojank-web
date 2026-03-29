---
title: foojank agent remove
description: Remove agent resources from the server. Foojank Client CLI Reference.
---

# agent remove

Remove an agent and its associated resources from the server.

```
$ foojank agent remove [options] <name>
$ foojank agent rm [options] <name>
```


## Arguments

| Argument | Description |
|----------|-------------|
| `<name>` | Name of the agent to remove |

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--server-url` | `string` | Set server URL (**required**) |
| `--server-certificate` | `string` | Set path to server's certificate |
| `--account` | `string` | Set server account (**required**) |
| `--config-dir` | `string` | Set path to a configuration directory |

