---
title: foojank config edit
description: Edit configuration. Foojank Client CLI Reference.
---

# config edit

Edit configuration options. At least one `--set` or `--unset` flag must be provided.

```
$ foojank config edit [options]
```

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--set` | `string[]` | Set configuration option, format: `key=value` |
| `--unset` | `string[]` | Unset configuration option, format: `key` |
| `--config-dir` | `string` | Set path to a configuration directory |

## Available Configuration Options

| Option | Description |
|--------|-------------|
| `server-url` | Server URL |
| `server-certificate` | Path to server's certificate |
| `account` | Account for server authentication |
| `format` | Output format: `table` or `json` |
| `no-color` | Color output |
