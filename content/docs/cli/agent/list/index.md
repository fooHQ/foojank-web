---
title: foojank agent list
description: List agents. Foojank Client CLI Reference.
---

# agent list

List all agents configured on the server for the current `--account`, showing their name, user/host, system, address, and last-seen time.

```
$ foojank agent list [options]
$ foojank agent ls [options]
```

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--format` | `string` | Set output format (`table`, `json`) |
| `--server-url` | `string` | Set server URL (**required**) |
| `--server-certificate` | `string` | Set path to server's certificate |
| `--account` | `string` | Set server account (**required**) |
| `--config-dir` | `string` | Set path to a configuration directory |

