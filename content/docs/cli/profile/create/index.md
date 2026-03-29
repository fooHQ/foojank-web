---
title: foojank profile create
description: Create a new profile. Foojank Client CLI Reference.
---

# profile create

Create a new profile with the specified environment variables and source directory.

```
$ foojank profile create [options] <name>
```

## Arguments

| Argument | Description |
|----------|-------------|
| `<name>` | Name for the new profile |

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--os` | `string` | Set OS environment variable |
| `--arch` | `string` | Set ARCH environment variable |
| `--feature` | `string[]` | Set FEATURE environment variable |
| `--set` | `string[]` | Set environment variable, format: `key=value` |
| `--source-dir` | `string` | Set path to a source code directory |
| `--config-dir` | `string` | Set path to a configuration directory |
