---
title: foojank job logs
description: Print job's output log. Foojank Client CLI Reference.
---

# job logs

Print the stdout output log of a job.

```
$ foojank job logs [options] <job-id>
```

## Arguments

| Argument | Description |
|----------|-------------|
| `<job-id>` | The ID of the job whose output to display |

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--server-url` | `string` | Set server URL (**required**) |
| `--server-certificate` | `string` | Set path to server's certificate |
| `--account` | `string` | Set server account (**required**) |
| `--config-dir` | `string` | Set path to a configuration directory |

