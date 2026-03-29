---
title: foojank job list
description: List jobs. Foojank Client CLI Reference.
---

# job list

List all jobs or filter by agent. Displays job ID, agent name, command, status, and timestamps.

```
$ foojank job list [options]
$ foojank job ls [options]
```


## Options

| Option | Type | Description |
|--------|------|-------------|
| `--agent` | `string` | Filter jobs by agent |
| `--format` | `string` | Set output format (`table`, `json`) |
| `--server-url` | `string` | Set server URL (**required**) |
| `--server-certificate` | `string` | Set path to server's certificate |
| `--account` | `string` | Set server account (**required**) |
| `--config-dir` | `string` | Set path to a configuration directory |

