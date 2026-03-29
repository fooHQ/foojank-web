---
title: foojank profile import
description: Import profiles from a file. Foojank Client CLI Reference.
---

# profile import

Import profiles from an external file into the local configuration. The source directory is automatically set to the directory containing the import file.

```
$ foojank profile import [options] <file>
```

## Arguments

| Argument | Description |
|----------|-------------|
| `<file>` | Path to the profiles file to import |

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--config-dir` | `string` | Set path to a configuration directory |
