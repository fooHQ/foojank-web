---
title: foojank profile list
description: List profiles or their details. Foojank Client CLI Reference.
---

# profile list

List all profiles or display details of a specific profile. Without arguments, shows all profiles with their source directory, OS, architecture, and features. With a name argument, shows the profile's full environment variable listing.

```
$ foojank profile list [options] [name]
$ foojank profile ls [options] [name]
```


## Arguments

| Argument | Description |
|----------|-------------|
| `[name]` | Optional name of a specific profile to inspect |

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--format` | `string` | Set output format (`table`, `json`) |
| `--config-dir` | `string` | Set path to a configuration directory |
