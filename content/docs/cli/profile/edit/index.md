---
title: foojank profile edit
description: Edit a profile. Foojank Client CLI Reference.
---

# profile edit

Edit an existing profile. Supports renaming, changing variables, and unsetting variables.

```
$ foojank profile edit [options] <name>
```

## Arguments

| Argument | Description |
|----------|-------------|
| `<name>` | Name of the profile to edit |

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--name` | `string` | Set new name (renames the profile) |
| `--os` | `string` | Set OS environment variable |
| `--arch` | `string` | Set ARCH environment variable |
| `--feature` | `string[]` | Set FEATURE environment variable |
| `--set` | `string[]` | Set environment variable, format: `key=value` |
| `--unset` | `string[]` | Unset environment variable, format: `key` |
| `--source-dir` | `string` | Set path to a source code directory |
| `--config-dir` | `string` | Set path to a configuration directory |
