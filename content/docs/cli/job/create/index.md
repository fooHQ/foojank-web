---
title: foojank job create
description: Create a job. Foojank Client CLI Reference.
---

# job create

Create a new job and assign it to an agent. The command and its arguments are passed as positional arguments after the flags.

```
$ foojank job create [options] <command> [args...]
```

## Arguments

| Argument | Description |
|----------|-------------|
| `<command> [args]` | The command to execute on the agent, followed by optional arguments |

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--agent` | `string` | Assign the job to the specified agent (**required**) |
| `--server-url` | `string` | Set server URL (**required**) |
| `--server-certificate` | `string` | Set path to server's certificate |
| `--account` | `string` | Set server account (**required**) |
| `--config-dir` | `string` | Set path to a configuration directory |

