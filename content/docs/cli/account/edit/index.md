---
title: foojank account edit
description: Edit account. Foojank Client CLI Reference.
---

# account edit

Edit an existing account. Supports linking and unlinking accounts for shared resource access.

```
$ foojank account edit [options] <name>
```

## Arguments

| Argument | Description |
|----------|-------------|
| `<name>` | Name of the account to edit |

## Options

| Option | Type | Description |
|--------|------|-------------|
| `--link-account` | `string[]` | Link the specified account to this account and enable shared access to this account's resources |
| `--accept-link-from` | `string` | Accept a link from the specified account and enable shared access to the specified account's resources |
| `--unlink-account` | `string[]` | Remove the link to the specified account and stop shared access to this account's resources |
| `--remove-link` | `bool` | Remove the existing link and stop shared access to the other account's resources |
