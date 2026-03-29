---
title: foojank storage
description: Manage storage. Foojank Client CLI Reference.
---

# storage

Manage storage. Storage provides a file-based interface to NATS ObjectStore for payload distribution and data exfiltration. Paths use the format `<storage-name>:<file-path>` to reference remote files.

```
$ foojank storage <command>
```

## Subcommands

| Command | Description |
|---------|-------------|
| [`list`](list/) | List storages or their contents |
| [`copy`](copy/) | Copy files between local filesystem and a storage |
| [`remove`](remove/) | Remove file from a storage |
