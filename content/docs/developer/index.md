---
title: Agent Developer Guide
---
# Agent Developer Guide

## Overview

This is a guide for developers on building custom agents that integrate with the Foojank C2 framework.

Foojank uses NATS as its messaging broker, giving operators asynchronous, low-latency communication with agents over TCP or WebSockets, server-based file storage via NATS ObjectStore, JWT-based authentication, and full observability.

An **agent** is a program that runs on a target machine and communicates with the Foojank **client** over NATS. Commands are received by the agent, executed locally, and results are streamed back to the server. All messages are serialized with [Cap'n Proto](https://capnproto.org/).

By the end of this guide, the reader will have a fully working agent that:

- Connects to a NATS server using JWT authentication.
- Consumes commands from a durable JetStream consumer.
- Starts a process, streams its output, and reports its exit code.
- Publishes periodic heartbeats with host information.

The guide covers the protocol specification, the build system, and example agents in **Go**, **Java**, **C++**, and **Rust**.

## Protocol Specification

All message types and NATS subjects are defined in [`agent.capnp`](https://github.com/fooHQ/foojank-proto/blob/main/schema/agent.capnp).
The schema serves as the single source of truth.

### Subjects

NATS subjects are hierarchical, dot-delimited strings that act as addresses for messages. When a component publishes a message, it publishes to a subject; when a component wants to receive messages, it subscribes to a subject. This publish-subscribe model is the foundation of all communication in Foojank.

Foojank defines a set of subjects scoped to each agent and worker. Every subject begins with `FJ.AGENT.<AgentID>`, ensuring that all traffic for a given agent lives under its own namespace. Within that namespace, subjects are split into two categories:

- **Command subjects** (`CMD`) carry instructions from the client to the agent, such as requests to start or stop a process or to write data to its stdin.
- **Event subjects** (`EVT`) carry information from the agent back to the client, such as process output, status updates, and heartbeats.

Worker-level subjects include a `<WorkerID>` segment so that multiple workers can run concurrently without their messages overlapping. The agent info subject operates at the agent level and does not reference a specific worker.

The table below lists every subject used by the Foojank framework.

| Subject | Description | Direction |
|---|---|---|
| `FJ.AGENT.<AgentID>.CMD.WORKER.<WorkerID>.START` | Request the agent to start a new worker process. | Client → Agent |
| `FJ.AGENT.<AgentID>.CMD.WORKER.<WorkerID>.STOP` | Request the agent to stop a running worker process. | Client → Agent |
| `FJ.AGENT.<AgentID>.CMD.WORKER.<WorkerID>.STDIN` | Send stdin data to a running worker process. | Client → Agent |
| `FJ.AGENT.<AgentID>.EVT.WORKER.<WorkerID>.START` | Report the result of a start worker request. | Agent → Client |
| `FJ.AGENT.<AgentID>.EVT.WORKER.<WorkerID>.STOP` | Report the result of a stop worker request. | Agent → Client |
| `FJ.AGENT.<AgentID>.EVT.WORKER.<WorkerID>.STATUS` | Report a worker's exit code or status change. | Agent → Client |
| `FJ.AGENT.<AgentID>.EVT.WORKER.<WorkerID>.STDOUT` | Stream stdout/stderr output from a worker process. | Agent → Client |
| `FJ.AGENT.<AgentID>.EVT.INFO` | Publish periodic agent heartbeats with host information. | Agent → Client |

### Streams and Consumers

Standard NATS publish-subscribe is fire-and-forget: if no subscriber is listening when a message arrives, the message is lost. [JetStream](https://docs.nats.io/nats-concepts/jetstream) adds persistence on top of NATS. A **stream** captures messages published to a set of subjects and stores them on the server. A **consumer** is a stateful view into a stream that tracks which messages have been delivered and acknowledged, allowing clients to process messages reliably and resume where they left off after a disconnect.

Foojank assigns each agent its own stream and consumer, scoped to the agent's subject namespace. The stream captures every message published to the agent's subjects — both command and event. This means the server retains a complete, ordered history of all interactions for that agent.

The agent's **durable consumer** is configured with subject filters that match only the command (`CMD`) subjects listed in the [Subjects](#subjects) table. As a result, when the agent pulls messages from its consumer, it receives only inbound instructions from the client. Event subjects are still stored in the stream, but they are excluded from the agent's consumer filters and are instead consumed directly by the client. This design ensures the agent never re-processes its own outbound messages and that the client can independently read agent output at its own pace.

### Message Envelope

All protocol messages are wrapped in the `Message` type, which contains a `content` union.

When encoding: a `Message` is created, the appropriate union variant is set, and the result is serialized.

When decoding: the data is deserialized into a `Message`, and the `content` union is checked to determine the variant.

### Message Types

#### StartWorkerRequest

Sent by a client to an agent to start a new worker process.

| Field | Type | Description |
|---|---|---|
| `command` | Text | Path to the executable to run. |
| `args` | List(Text) | Command-line arguments. |
| `env` | List(Text) | Environment variables in `KEY=VALUE` form. |

#### StartWorkerResponse

Sent by an agent in response to a `StartWorkerRequest`.

| Field | Type | Description |
|---|---|---|
| `error` | Text | Error description, or empty string on success. |

#### StopWorkerRequest

Sent by a client to an agent to stop a running worker process. This message has no fields.

#### StopWorkerResponse

Sent by an agent in response to a `StopWorkerRequest`.

| Field | Type | Description |
|---|---|---|
| `error` | Text | Error description, or empty string on success. |

#### UpdateWorkerStdio

Sent by a client when writing to a worker's stdin and by an agent when streaming stdout.

| Field | Type | Description |
|---|---|---|
| `data` | Data | Raw bytes. |

#### UpdateWorkerStatus

Sent by an agent to notify the client of a change in worker status.

| Field | Type | Description |
|---|---|---|
| `status` | Int64 | Exit code of the worker process. |

#### UpdateClientInfo

Sent by an agent to identify itself to a client.

| Field | Type | Description |
|---|---|---|
| `username` | Text | Operating system username of the agent. |
| `hostname` | Text | Name of the machine where the agent is running. |
| `system` | Text | Operating system name (e.g., `linux`, `darwin`, `windows`). |
| `address` | Text | Public address of the agent. |

### Agent Workflow

The following sequence describes the interaction between client and agent during a worker's lifecycle. All messages are wrapped in the `Message` envelope described in [Message Envelope](#message-envelope). Refer to the [Subjects](#subjects) table for the full subject strings used in each step.

#### Starting a Worker

1. The **client** generates a WorkerID and publishes a `StartWorkerRequest` to the worker's start command subject. It then subscribes to the worker's event subjects to receive responses.
2. The **agent** consumes the request from its durable consumer and extracts the WorkerID from the subject.
3. The **agent** starts the specified command with the provided arguments and environment variables.
4. The **agent** publishes a `StartWorkerResponse` to the worker's start event subject. If the command could not be started, the `error` field contains a description of the failure.
5. The **client** consumes the response. If the `error` field is non-empty, the worker failed to start and the client handles the error. Otherwise, it proceeds to consume output.

#### Streaming Output and Input

6. As the process runs, the **agent** publishes its stdout/stderr as `UpdateWorkerStdio` messages to the worker's stdout event subject.
7. The **client** consumes these messages and presents the output to the operator.
8. The **client** can optionally write to the process's stdin by publishing `UpdateWorkerStdio` messages to the worker's stdin command subject. The agent forwards the data to the running process.

#### Stopping a Worker

9. The **client** can optionally terminate the process early by publishing a `StopWorkerRequest` to the worker's stop command subject. The agent stops the process and responds with a `StopWorkerResponse` on the worker's stop event subject.
10. When the process exits — whether naturally or because it was stopped — the **agent** publishes an `UpdateWorkerStatus` with the exit code to the worker's status event subject.
11. The **client** consumes the status update, completing the worker lifecycle.

#### Heartbeat

Independently of any worker lifecycle, the agent periodically publishes an `UpdateClientInfo` message to its info event subject. The message contains the current OS user, hostname, one IP address, and the operating system name. The client subscribes to this subject to track agent availability and host information.

### Authentication

Foojank uses NATS JWT authentication to control access to the messaging server. In this model, identity and permissions are carried inside signed JSON Web Tokens rather than being stored on the server. The server only needs to trust the signing key — it does not maintain a user database.

NATS JWT authentication is organized around three levels: **operators**, **accounts**, and **users**. An operator is the root of trust and signs account keys. An account is an isolated security boundary — subjects, streams, and consumers in one account are invisible to another. A user belongs to a single account and can only access resources permitted by that account's configuration.

Each agent is placed in a specific account, selected with the `--account` flag or the `account` configuration option at build time. This means all agents built under the same account share a security boundary, while agents in different accounts are fully isolated from one another.

When an agent is built, Foojank generates a new user nkey and signs a JWT for it using the account key. The resulting JWT restricts the user to the agent's own subject namespace (`FJ.AGENT.<AgentID>.>`), so the agent can only publish and subscribe to subjects scoped to its own ID. The JWT and the user nkey seed are embedded into the agent at build time and passed as environment variables (`FJ_USER_JWT` and `FJ_USER_KEY`) during the build process. At runtime, the agent presents these credentials when connecting to the NATS server.

## Build System

Agents are compiled using Foojank's CLI:

```bash
$ foojank build --source-dir ./agent-template
```

The CLI invokes a devbox script called `"build"`. Agent configuration is passed to the script as environment variables:

| Variable | Description |
|---|---|
| `OS` | Target operating system |
| `ARCH` | Target architecture |
| `TARGET` | Target filename |
| `FEATURES` | Additional compiler flags |
| `FJ_AGENT_ID` | Agent ID (public user nkey) |
| `FJ_SERVER_URL` | C2 server URL |
| `FJ_SERVER_CERTIFICATE` | Path to server TLS certificate file |
| `FJ_USER_JWT` | NATS user JWT |
| `FJ_USER_KEY` | NATS user nkey seed |
| `FJ_STREAM` | JetStream stream name assigned to the agent |
| `FJ_CONSUMER` | NATS durable consumer name |
| `FJ_INBOX_PREFIX` | NATS inbox prefix assigned to the agent |
| `FJ_OBJECT_STORE` | NATS ObjectStore name assigned to the agent |

### Build Profiles

Build profiles allow custom configuration to be passed to the agent at build time. A profile is selected with the `--profile` flag:

```bash
$ foojank build --source-dir ./agent-template --profile vessel-linux-amd64
```

Profiles are defined in a `profiles.json` file in the agent template directory, from where they can be imported by operators. Each key is a profile name, and its value is an object with an `environment` map. Every entry in `environment` has a `value` (required) and an optional `description`. The environment variables defined by the profile are passed to the devbox build script **in addition to** the standard variables listed above. Profile variables can be used to override `OS` and `ARCH`.

Example `profiles.json`:

```json
{
  "vessel-linux-amd64": {
    "environment": {
      "OS": {
        "value": "linux"
      },
      "ARCH": {
        "value": "amd64"
      },
      "VESSEL_AWAIT_MESSAGES_DURATION": {
        "value": "15s",
        "description": "Duration to wait for messages before disconnecting from the server."
      },
      "VESSEL_IDLE_DURATION": {
        "value": "45s",
        "description": "Duration to wait before reconnecting to the server."
      },
      "VESSEL_IDLE_JITTER": {
        "value": "12s",
        "description": "Jitter to add to the idle duration."
      }
    }
  }
}
```

In this example, the profile sets the target to Linux/amd64 and passes three agent-specific timing variables. The `tasks.py` build function receives these as additional environment variables.

## Development Environment Setup

1. The agent template is cloned from the repository:

```bash
$ git clone https://github.com/foohq/agent-template
```

2. The language toolchain is installed using **devbox** — specific `devbox add` commands are provided in each language section below.

3. Code dependencies are installed using each language's native package manager — specific commands are provided in each language section.