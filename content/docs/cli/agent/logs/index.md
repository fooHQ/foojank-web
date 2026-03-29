---
title: foojank agent logs
description: Display all messages in agent's stream. Foojank Client CLI Reference.
---

# agent logs

Display all messages in an agent's stream, showing message ID, subject, and timestamp.

```
$ foojank agent logs [options] <name>
```

## Arguments

| Argument | Description |
|----------|-------------|
| `<name>` | Name of the agent whose logs to display |

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--format` | `string` | Set output format (`table`, `json`) |
| `--server-url` | `string` | Set server URL (**required**) |
| `--server-certificate` | `string` | Set path to server's certificate |
| `--account` | `string` | Set server account (**required**) |
| `--config-dir` | `string` | Set path to a configuration directory |

