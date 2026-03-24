## Language Implementation Guides

### Configuration File Format

The JSON config file written by `tasks.py` and read by the agent at startup:

```json
{
  "agent_id": "...",
  "server_url": "...",
  "server_certificate": "...",
  "user_jwt": "...",
  "user_key": "...",
  "stream": "...",
  "consumer": "...",
  "inbox_prefix": "...",
  "object_store": "..."
}
```

The `server_certificate` field contains the **contents** of the certificate file (read by `tasks.py` at build time), not a file path. This way the agent binary + `config.json` are self-contained.

### Go

#### Dependencies & Toolchain

Install the Go toolchain via devbox:

```bash
$ devbox add go
```

Initialize a Go module:

```bash
$ go mod init agent
```

The generated Cap'n Proto Go bindings are at `github.com/foohq/foojank-proto/go/agent` (see [foojank-proto repository](https://github.com/fooHQ/foojank-proto/tree/main/go/agent)).

#### Build Script (`tasks.py`)

The build script reads `FJ_*` environment variables provided by the Foojank CLI, writes them into a `config.json` file (embedding the server certificate contents rather than a file path), then invokes the Go compiler for cross-compilation targeting the specified `OS`/`ARCH` with `CGO_ENABLED=0` for a static binary.

```python
#!/usr/bin/env python3

import argparse
import json
import os
import sys
import subprocess


def build():
    fj_vars = {
        "agent_id": os.environ.get("FJ_AGENT_ID", ""),
        "server_url": os.environ.get("FJ_SERVER_URL", ""),
        "user_jwt": os.environ.get("FJ_USER_JWT", ""),
        "user_key": os.environ.get("FJ_USER_KEY", ""),
        "stream": os.environ.get("FJ_STREAM", ""),
        "consumer": os.environ.get("FJ_CONSUMER", ""),
        "inbox_prefix": os.environ.get("FJ_INBOX_PREFIX", ""),
        "object_store": os.environ.get("FJ_OBJECT_STORE", ""),
    }

    cert_path = os.environ.get("FJ_SERVER_CERTIFICATE", "")
    if cert_path and os.path.isfile(cert_path):
        with open(cert_path, "r") as f:
            fj_vars["server_certificate"] = f.read()
    else:
        fj_vars["server_certificate"] = ""

    with open("config.json", "w") as f:
        json.dump(fj_vars, f, indent=2)

    target_os = os.environ.get("OS", "linux")
    target_arch = os.environ.get("ARCH", "amd64")
    target = os.environ.get("TARGET", "agent")
    features = os.environ.get("FEATURES", "")

    env = os.environ.copy()
    env["GOOS"] = target_os
    env["GOARCH"] = target_arch
    env["CGO_ENABLED"] = "0"

    cmd = ["go", "build", "-o", target]
    if features:
        cmd.extend(features.split())
    cmd.append(".")

    result = subprocess.run(cmd, env=env)
    sys.exit(result.returncode)


def test():
    print(sys._getframe().f_code.co_name + ":", "not implemented")
    sys.exit(1)


def lint():
    print(sys._getframe().f_code.co_name + ":", "not implemented")
    sys.exit(1)


if __name__ == "__main__":
    choices = ["build", "test", "lint"]
    parser = argparse.ArgumentParser(description="Run project tasks.")
    parser.add_argument("function", choices=choices, help="The function to run.")
    args = parser.parse_args()
    globals()[args.function]()
```

#### Complete Agent

The complete Go agent implements all protocol functionality in a single file. It loads configuration from `config.json` (matching the schema from the Configuration File Format section), connects to the NATS server using TLS with the embedded server certificate and JWT/nkey authentication, starts a background heartbeat goroutine that publishes `UpdateClientInfo` messages every 30 seconds with the current OS user, hostname, system name, and local IP address, then binds to a durable JetStream consumer to receive `StartWorkerRequest` messages. When a command arrives, the worker ID is extracted from the NATS subject, the process is started with the specified command, arguments, and environment, and stdout/stderr output is streamed back as `UpdateWorkerStdio` messages. On process exit, an `UpdateWorkerStatus` message is published with the exit code. A mutex-protected flag enforces the one-worker-at-a-time constraint — if a second start request arrives while a worker is running, an error response is returned immediately. All Cap'n Proto messages are wrapped in the `Message` union envelope, and all NATS subjects are constructed from the schema-defined constants.

```go
package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"os/user"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/foohq/foojank-proto/go/agent"
	capnp "capnproto.org/go/capnp/v3"
	"github.com/nats-io/nats.go"
	"github.com/nats-io/nats.go/jetstream"
	"github.com/nats-io/nkeys"
)

// Subject templates from agent.capnp
const (
	cmdStartWorkerT  = "FJ.AGENT.%s.CMD.WORKER.%s.START"
	evtStartWorkerT  = "FJ.AGENT.%s.EVT.WORKER.%s.START"
	evtWorkerStdoutT = "FJ.AGENT.%s.EVT.WORKER.%s.STDOUT"
	evtWorkerStatusT = "FJ.AGENT.%s.EVT.WORKER.%s.STATUS"
	evtAgentInfoT    = "FJ.AGENT.%s.EVT.INFO"
)

type Config struct {
	AgentID           string `json:"agent_id"`
	ServerURL         string `json:"server_url"`
	ServerCertificate string `json:"server_certificate"`
	UserJWT           string `json:"user_jwt"`
	UserKey           string `json:"user_key"`
	Stream            string `json:"stream"`
	Consumer          string `json:"consumer"`
	InboxPrefix       string `json:"inbox_prefix"`
	ObjectStore       string `json:"object_store"`
}

func loadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read config: %w", err)
	}
	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("parse config: %w", err)
	}
	return &cfg, nil
}

func connect(cfg *Config) (*nats.Conn, error) {
	certPool := x509.NewCertPool()
	if !certPool.AppendCertsFromPEM([]byte(cfg.ServerCertificate)) {
		return nil, fmt.Errorf("failed to parse server certificate")
	}
	tlsConfig := &tls.Config{RootCAs: certPool}

	jwtCB := func() (string, error) { return cfg.UserJWT, nil }
	sigCB := func(nonce []byte) ([]byte, error) {
		kp, err := nkeys.FromSeed([]byte(cfg.UserKey))
		if err != nil {
			return nil, err
		}
		return kp.Sign(nonce)
	}

	return nats.Connect(cfg.ServerURL,
		nats.Secure(tlsConfig),
		nats.UserJWT(jwtCB, sigCB),
		nats.InboxPrefix(cfg.InboxPrefix),
	)
}

func getLocalIP() string {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return "unknown"
	}
	for _, addr := range addrs {
		if ipNet, ok := addr.(*net.IPNet); ok && !ipNet.IP.IsLoopback() && ipNet.IP.To4() != nil {
			return ipNet.IP.String()
		}
	}
	return "unknown"
}

func encodeClientInfo() ([]byte, error) {
	msg, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	if err != nil {
		return nil, err
	}
	envelope, err := agent.NewRootMessage(seg)
	if err != nil {
		return nil, err
	}
	info, err := envelope.Content().NewUpdateClientInfo()
	if err != nil {
		return nil, err
	}
	currentUser, _ := user.Current()
	hostname, _ := os.Hostname()
	info.SetUsername(currentUser.Username)
	info.SetHostname(hostname)
	info.SetSystem(runtime.GOOS)
	info.SetAddress(getLocalIP())
	return msg.Marshal()
}

func encodeStartWorkerResponse(errMsg string) ([]byte, error) {
	msg, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	if err != nil {
		return nil, err
	}
	envelope, err := agent.NewRootMessage(seg)
	if err != nil {
		return nil, err
	}
	resp, err := envelope.Content().NewStartWorkerResponse()
	if err != nil {
		return nil, err
	}
	resp.SetError(errMsg)
	return msg.Marshal()
}

func encodeWorkerStdio(chunk []byte) ([]byte, error) {
	msg, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	if err != nil {
		return nil, err
	}
	envelope, err := agent.NewRootMessage(seg)
	if err != nil {
		return nil, err
	}
	stdio, err := envelope.Content().NewUpdateWorkerStdio()
	if err != nil {
		return nil, err
	}
	stdio.SetData(chunk)
	return msg.Marshal()
}

func encodeWorkerStatus(exitCode int64) ([]byte, error) {
	msg, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	if err != nil {
		return nil, err
	}
	envelope, err := agent.NewRootMessage(seg)
	if err != nil {
		return nil, err
	}
	status, err := envelope.Content().NewUpdateWorkerStatus()
	if err != nil {
		return nil, err
	}
	status.SetStatus(exitCode)
	return msg.Marshal()
}

func extractWorkerID(subject string) string {
	parts := strings.Split(subject, ".")
	if len(parts) >= 6 {
		return parts[5]
	}
	return ""
}

func decodeStartWorkerRequest(data []byte) (command string, args []string, env []string, err error) {
	msg, err := capnp.Unmarshal(data)
	if err != nil {
		return "", nil, nil, err
	}
	envelope, err := agent.ReadRootMessage(msg)
	if err != nil {
		return "", nil, nil, err
	}
	req, err := envelope.Content().StartWorkerRequest()
	if err != nil {
		return "", nil, nil, err
	}
	command, _ = req.Command()

	argsList, _ := req.Args()
	for i := 0; i < argsList.Len(); i++ {
		a, _ := argsList.At(i)
		args = append(args, a)
	}

	envList, _ := req.Env()
	for i := 0; i < envList.Len(); i++ {
		e, _ := envList.At(i)
		env = append(env, e)
	}
	return command, args, env, nil
}

type Agent struct {
	nc      *nats.Conn
	cfg     *Config
	mu      sync.Mutex
	running bool
}

func (a *Agent) startHeartbeat() {
	subject := fmt.Sprintf(evtAgentInfoT, a.cfg.AgentID)
	ticker := time.NewTicker(30 * time.Second)
	go func() {
		if data, err := encodeClientInfo(); err == nil {
			a.nc.Publish(subject, data)
		}
		for range ticker.C {
			data, err := encodeClientInfo()
			if err != nil {
				log.Printf("heartbeat encode error: %v", err)
				continue
			}
			if err := a.nc.Publish(subject, data); err != nil {
				log.Printf("heartbeat publish error: %v", err)
			}
		}
	}()
}

func (a *Agent) handleStartWorker(workerID, command string, args, env []string) {
	a.mu.Lock()
	if a.running {
		a.mu.Unlock()
		data, _ := encodeStartWorkerResponse("a worker is already running")
		a.nc.Publish(fmt.Sprintf(evtStartWorkerT, a.cfg.AgentID, workerID), data)
		return
	}
	a.running = true
	a.mu.Unlock()

	defer func() {
		a.mu.Lock()
		a.running = false
		a.mu.Unlock()
	}()

	cmd := exec.Command(command, args...)
	cmd.Env = env
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		data, _ := encodeStartWorkerResponse(err.Error())
		a.nc.Publish(fmt.Sprintf(evtStartWorkerT, a.cfg.AgentID, workerID), data)
		return
	}
	cmd.Stderr = cmd.Stdout

	if err := cmd.Start(); err != nil {
		data, _ := encodeStartWorkerResponse(err.Error())
		a.nc.Publish(fmt.Sprintf(evtStartWorkerT, a.cfg.AgentID, workerID), data)
		return
	}

	data, _ := encodeStartWorkerResponse("")
	a.nc.Publish(fmt.Sprintf(evtStartWorkerT, a.cfg.AgentID, workerID), data)

	stdoutSubject := fmt.Sprintf(evtWorkerStdoutT, a.cfg.AgentID, workerID)
	buf := make([]byte, 4096)
	for {
		n, readErr := stdout.Read(buf)
		if n > 0 {
			chunk, _ := encodeWorkerStdio(buf[:n])
			a.nc.Publish(stdoutSubject, chunk)
		}
		if readErr != nil {
			break
		}
	}

	var exitCode int64
	if err := cmd.Wait(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = int64(exitErr.ExitCode())
		} else {
			exitCode = -1
		}
	}
	statusData, _ := encodeWorkerStatus(exitCode)
	a.nc.Publish(fmt.Sprintf(evtWorkerStatusT, a.cfg.AgentID, workerID), statusData)
}

func (a *Agent) consumeCommands() error {
	js, err := jetstream.New(a.nc)
	if err != nil {
		return fmt.Errorf("jetstream: %w", err)
	}

	cons, err := js.Consumer(context.Background(), a.cfg.Stream, a.cfg.Consumer)
	if err != nil {
		return fmt.Errorf("consumer: %w", err)
	}

	_, err = cons.Consume(func(msg jetstream.Msg) {
		workerID := extractWorkerID(msg.Subject())
		command, args, env, err := decodeStartWorkerRequest(msg.Data())
		if err != nil {
			log.Printf("decode error: %v", err)
			msg.Nak()
			return
		}
		msg.Ack()
		a.handleStartWorker(workerID, command, args, env)
	})
	return err
}

func main() {
	cfg, err := loadConfig("config.json")
	if err != nil {
		log.Fatal(err)
	}

	nc, err := connect(cfg)
	if err != nil {
		log.Fatal(err)
	}
	defer nc.Close()

	ag := &Agent{nc: nc, cfg: cfg}
	ag.startHeartbeat()

	if err := ag.consumeCommands(); err != nil {
		log.Fatal(err)
	}

	log.Printf("Agent %s running", cfg.AgentID)
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt)
	<-sigCh
	log.Println("Shutting down")
}
```

---

### Java

#### Dependencies & Toolchain

Install the Java toolchain via devbox:

```bash
devbox add jdk
devbox add maven
```

The generated Cap'n Proto Java bindings are at `io.github.foohq.foojank.agent` in the [foojank-proto repository](https://github.com/fooHQ/foojank-proto/tree/main/java/io/github/foohq/foojank/agent).

Add dependencies to `pom.xml`:

```xml
<dependencies>
    <dependency>
        <groupId>org.capnproto</groupId>
        <artifactId>runtime</artifactId>
        <version>0.1.15</version>
    </dependency>
    <dependency>
        <groupId>io.nats</groupId>
        <artifactId>jnats</artifactId>
        <version>2.20.4</version>
    </dependency>
</dependencies>
```

Copy the generated Java bindings from `foojank-proto/java/` into your source tree. The main generated class is `Agent.java` in the `io.github.foohq.foojank.agent` package.

#### Build Script (`tasks.py`)

The build script reads `FJ_*` environment variables, writes `config.json` with embedded certificate contents, then invokes Maven to compile and package the agent as a fat JAR. The resulting JAR is copied to the `TARGET` filename.

```python
#!/usr/bin/env python3

import argparse
import json
import os
import sys
import subprocess


def build():
    fj_vars = {
        "agent_id": os.environ.get("FJ_AGENT_ID", ""),
        "server_url": os.environ.get("FJ_SERVER_URL", ""),
        "user_jwt": os.environ.get("FJ_USER_JWT", ""),
        "user_key": os.environ.get("FJ_USER_KEY", ""),
        "stream": os.environ.get("FJ_STREAM", ""),
        "consumer": os.environ.get("FJ_CONSUMER", ""),
        "inbox_prefix": os.environ.get("FJ_INBOX_PREFIX", ""),
        "object_store": os.environ.get("FJ_OBJECT_STORE", ""),
    }

    cert_path = os.environ.get("FJ_SERVER_CERTIFICATE", "")
    if cert_path and os.path.isfile(cert_path):
        with open(cert_path, "r") as f:
            fj_vars["server_certificate"] = f.read()
    else:
        fj_vars["server_certificate"] = ""

    with open("config.json", "w") as f:
        json.dump(fj_vars, f, indent=2)

    target = os.environ.get("TARGET", "agent.jar")
    features = os.environ.get("FEATURES", "")

    mvn_cmd = ["mvn", "clean", "package", "-q"]
    if features:
        mvn_cmd.extend(features.split())

    result = subprocess.run(mvn_cmd)
    if result.returncode != 0:
        sys.exit(result.returncode)

    import glob, shutil
    jars = glob.glob("target/*-jar-with-dependencies.jar")
    if jars:
        shutil.copy(jars[0], target)

    sys.exit(0)


def test():
    print(sys._getframe().f_code.co_name + ":", "not implemented")
    sys.exit(1)


def lint():
    print(sys._getframe().f_code.co_name + ":", "not implemented")
    sys.exit(1)


if __name__ == "__main__":
    choices = ["build", "test", "lint"]
    parser = argparse.ArgumentParser(description="Run project tasks.")
    parser.add_argument("function", choices=choices, help="The function to run.")
    args = parser.parse_args()
    globals()[args.function]()
```

#### Complete Agent

The complete Java agent implements all protocol functionality in a single class. It loads configuration from `config.json` using Gson, connects to the NATS server using TLS (with the embedded server certificate loaded into a `TrustStore`) and JWT/nkey authentication via the jnats `AuthHandler` interface. A `ScheduledExecutorService` publishes `UpdateClientInfo` heartbeat messages every 30 seconds containing the OS username, hostname, system name, and local IP address. The agent subscribes to the JetStream consumer for `StartWorkerRequest` messages, extracting the worker ID from the NATS subject. On receiving a command, it spawns a `Process` via `ProcessBuilder` with merged stdout/stderr, streams output as `UpdateWorkerStdio` messages, and publishes the exit code as `UpdateWorkerStatus`. An `AtomicBoolean` enforces the one-worker-at-a-time constraint. All Cap'n Proto messages are wrapped in the `Message` union envelope using the generated `Agent.Message.factory`, and all NATS subjects are constructed from the schema-defined constants using `String.format`.

```java
package io.github.foohq.foojank.agent;

import io.github.foohq.foojank.Agent;
import org.capnproto.*;

import io.nats.client.*;
import io.nats.client.api.*;

import javax.net.ssl.*;
import java.io.*;
import java.net.InetAddress;
import java.nio.channels.Channels;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

import com.google.gson.Gson;

public class FoojankAgent {

    // Subject templates from agent.capnp
    static final String CMD_START_WORKER_T = "FJ.AGENT.%s.CMD.WORKER.%s.START";
    static final String EVT_START_WORKER_T = "FJ.AGENT.%s.EVT.WORKER.%s.START";
    static final String EVT_WORKER_STDOUT_T = "FJ.AGENT.%s.EVT.WORKER.%s.STDOUT";
    static final String EVT_WORKER_STATUS_T = "FJ.AGENT.%s.EVT.WORKER.%s.STATUS";
    static final String EVT_AGENT_INFO_T = "FJ.AGENT.%s.EVT.INFO";

    static class Config {
        String agent_id;
        String server_url;
        String server_certificate;
        String user_jwt;
        String user_key;
        String stream;
        String consumer;
        String inbox_prefix;
        String object_store;

        static Config load(String path) throws Exception {
            return new Gson().fromJson(Files.readString(Path.of(path)), Config.class);
        }
    }

    record StartRequest(String command, String[] args, String[] env) {}

    private final Config cfg;
    private final Connection nc;
    private final AtomicBoolean workerRunning = new AtomicBoolean(false);

    public FoojankAgent(Config cfg, Connection nc) {
        this.cfg = cfg;
        this.nc = nc;
    }

    static Connection connect(Config cfg) throws Exception {
        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        X509Certificate cert = (X509Certificate) cf.generateCertificate(
            new ByteArrayInputStream(cfg.server_certificate.getBytes()));
        KeyStore trustStore = KeyStore.getInstance(KeyStore.getDefaultType());
        trustStore.load(null, null);
        trustStore.setCertificateEntry("server", cert);
        TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        tmf.init(trustStore);
        SSLContext sslCtx = SSLContext.getInstance("TLS");
        sslCtx.init(null, tmf.getTrustManagers(), null);

        Options opts = new Options.Builder()
            .server(cfg.server_url)
            .sslContext(sslCtx)
            .authHandler(new AuthHandler() {
                public char[] getID() { return null; }
                public byte[] sign(byte[] nonce) {
                    try {
                        io.nats.client.support.NKey nkey =
                            io.nats.client.support.NKey.fromSeed(cfg.user_key.toCharArray());
                        return nkey.sign(nonce);
                    } catch (Exception e) { throw new RuntimeException(e); }
                }
                public char[] getJWT() { return cfg.user_jwt.toCharArray(); }
            })
            .inboxPrefix(cfg.inbox_prefix)
            .build();

        return Nats.connect(opts);
    }

    static String extractWorkerID(String subject) {
        String[] parts = subject.split("\\.");
        return parts.length >= 6 ? parts[5] : "";
    }

    byte[] encodeClientInfo() throws Exception {
        MessageBuilder message = new MessageBuilder();
        Agent.Message.Builder envelope = message.initRoot(Agent.Message.factory);
        Agent.UpdateClientInfo.Builder info = envelope.getContent().initUpdateClientInfo();
        info.setUsername(new org.capnproto.Text.Reader(System.getProperty("user.name")));
        info.setHostname(new org.capnproto.Text.Reader(InetAddress.getLocalHost().getHostName()));
        info.setSystem(new org.capnproto.Text.Reader(System.getProperty("os.name").toLowerCase()));
        info.setAddress(new org.capnproto.Text.Reader(InetAddress.getLocalHost().getHostAddress()));
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        Serialize.write(Channels.newChannel(baos), message);
        return baos.toByteArray();
    }

    byte[] encodeStartWorkerResponse(String error) throws Exception {
        MessageBuilder message = new MessageBuilder();
        Agent.Message.Builder envelope = message.initRoot(Agent.Message.factory);
        Agent.StartWorkerResponse.Builder resp = envelope.getContent().initStartWorkerResponse();
        resp.setError(new org.capnproto.Text.Reader(error));
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        Serialize.write(Channels.newChannel(baos), message);
        return baos.toByteArray();
    }

    byte[] encodeWorkerStdio(byte[] chunk) throws Exception {
        MessageBuilder message = new MessageBuilder();
        Agent.Message.Builder envelope = message.initRoot(Agent.Message.factory);
        Agent.UpdateWorkerStdio.Builder stdio = envelope.getContent().initUpdateWorkerStdio();
        stdio.setData(new org.capnproto.Data.Reader(chunk, 0, chunk.length));
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        Serialize.write(Channels.newChannel(baos), message);
        return baos.toByteArray();
    }

    byte[] encodeWorkerStatus(long exitCode) throws Exception {
        MessageBuilder message = new MessageBuilder();
        Agent.Message.Builder envelope = message.initRoot(Agent.Message.factory);
        Agent.UpdateWorkerStatus.Builder status = envelope.getContent().initUpdateWorkerStatus();
        status.setStatus(exitCode);
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        Serialize.write(Channels.newChannel(baos), message);
        return baos.toByteArray();
    }

    StartRequest decodeStartWorkerRequest(byte[] data) throws Exception {
        MessageReader reader = Serialize.read(
            Channels.newChannel(new ByteArrayInputStream(data)));
        Agent.Message.Reader envelope = reader.getRoot(Agent.Message.factory);
        Agent.StartWorkerRequest.Reader req = envelope.getContent().getStartWorkerRequest();

        String command = req.getCommand().toString();
        org.capnproto.TextList.Reader argsList = req.getArgs();
        String[] args = new String[argsList.size()];
        for (int i = 0; i < argsList.size(); i++) args[i] = argsList.get(i).toString();

        org.capnproto.TextList.Reader envList = req.getEnv();
        String[] env = new String[envList.size()];
        for (int i = 0; i < envList.size(); i++) env[i] = envList.get(i).toString();

        return new StartRequest(command, args, env);
    }

    void startHeartbeat() {
        String subject = String.format(EVT_AGENT_INFO_T, cfg.agent_id);
        ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();
        scheduler.scheduleAtFixedRate(() -> {
            try {
                nc.publish(subject, encodeClientInfo());
            } catch (Exception e) {
                System.err.println("heartbeat error: " + e.getMessage());
            }
        }, 0, 30, TimeUnit.SECONDS);
    }

    void handleStartWorker(String workerID, StartRequest req) {
        if (!workerRunning.compareAndSet(false, true)) {
            try {
                nc.publish(String.format(EVT_START_WORKER_T, cfg.agent_id, workerID),
                    encodeStartWorkerResponse("a worker is already running"));
            } catch (Exception e) { e.printStackTrace(); }
            return;
        }

        try {
            List<String> cmdList = new ArrayList<>();
            cmdList.add(req.command());
            cmdList.addAll(Arrays.asList(req.args()));

            ProcessBuilder pb = new ProcessBuilder(cmdList);
            pb.environment().clear();
            for (String envVar : req.env()) {
                String[] kv = envVar.split("=", 2);
                if (kv.length == 2) pb.environment().put(kv[0], kv[1]);
            }
            pb.redirectErrorStream(true);

            Process process;
            try {
                process = pb.start();
            } catch (Exception e) {
                nc.publish(String.format(EVT_START_WORKER_T, cfg.agent_id, workerID),
                    encodeStartWorkerResponse(e.getMessage()));
                return;
            }

            nc.publish(String.format(EVT_START_WORKER_T, cfg.agent_id, workerID),
                encodeStartWorkerResponse(""));

            String stdoutSubject = String.format(EVT_WORKER_STDOUT_T, cfg.agent_id, workerID);
            InputStream stdout = process.getInputStream();
            byte[] buf = new byte[4096];
            int bytesRead;
            while ((bytesRead = stdout.read(buf)) != -1) {
                byte[] chunk = Arrays.copyOf(buf, bytesRead);
                nc.publish(stdoutSubject, encodeWorkerStdio(chunk));
            }

            int exitCode = process.waitFor();
            nc.publish(String.format(EVT_WORKER_STATUS_T, cfg.agent_id, workerID),
                encodeWorkerStatus(exitCode));
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            workerRunning.set(false);
        }
    }

    void consumeCommands() throws Exception {
        JetStream js = nc.jetStream();
        PushSubscribeOptions pso = PushSubscribeOptions.builder()
            .stream(cfg.stream)
            .durable(cfg.consumer)
            .build();

        String subscribeSubject = String.format(CMD_START_WORKER_T, cfg.agent_id, "*");
        Dispatcher dispatcher = nc.createDispatcher();
        js.subscribe(subscribeSubject, dispatcher, msg -> {
            try {
                String workerID = extractWorkerID(msg.getSubject());
                StartRequest req = decodeStartWorkerRequest(msg.getData());
                msg.ack();
                handleStartWorker(workerID, req);
            } catch (Exception e) {
                System.err.println("decode error: " + e.getMessage());
                msg.nak();
            }
        }, false, pso);
    }

    public static void main(String[] args) throws Exception {
        Config cfg = Config.load("config.json");
        Connection nc = connect(cfg);
        FoojankAgent agent = new FoojankAgent(cfg, nc);

        agent.startHeartbeat();
        agent.consumeCommands();

        System.out.printf("Agent %s running%n", cfg.agent_id);
        Thread.currentThread().join();
    }
}
```

---

### C++

#### Dependencies & Toolchain

Install the C++ toolchain and Cap'n Proto via devbox:

```bash
devbox add gcc
devbox add cmake
devbox add capnproto
devbox add pkg-config
```

Install code dependencies. The NATS C client and Cap'n Proto library can be managed with vcpkg or system packages:

```bash
# With vcpkg
vcpkg install capnproto nats-c nlohmann-json
```

Alternatively, install `cnats` from source or your system package manager.

The generated Cap'n Proto C++ bindings are at `cpp/agent.capnp.h` and `cpp/agent.capnp.c++` in the [foojank-proto repository](https://github.com/fooHQ/foojank-proto/tree/main/cpp).

#### Build Script (`tasks.py`)

The build script reads `FJ_*` environment variables, writes `config.json` with embedded certificate contents, then invokes CMake to configure and build the agent. The resulting binary is copied to the `TARGET` filename.

```python
#!/usr/bin/env python3

import argparse
import json
import os
import sys
import subprocess


def build():
    fj_vars = {
        "agent_id": os.environ.get("FJ_AGENT_ID", ""),
        "server_url": os.environ.get("FJ_SERVER_URL", ""),
        "user_jwt": os.environ.get("FJ_USER_JWT", ""),
        "user_key": os.environ.get("FJ_USER_KEY", ""),
        "stream": os.environ.get("FJ_STREAM", ""),
        "consumer": os.environ.get("FJ_CONSUMER", ""),
        "inbox_prefix": os.environ.get("FJ_INBOX_PREFIX", ""),
        "object_store": os.environ.get("FJ_OBJECT_STORE", ""),
    }

    cert_path = os.environ.get("FJ_SERVER_CERTIFICATE", "")
    if cert_path and os.path.isfile(cert_path):
        with open(cert_path, "r") as f:
            fj_vars["server_certificate"] = f.read()
    else:
        fj_vars["server_certificate"] = ""

    with open("config.json", "w") as f:
        json.dump(fj_vars, f, indent=2)

    target = os.environ.get("TARGET", "agent")
    features = os.environ.get("FEATURES", "")

    cmake_cmd = ["cmake", "-B", "build", "-DCMAKE_BUILD_TYPE=Release"]
    if features:
        cmake_cmd.extend(features.split())

    result = subprocess.run(cmake_cmd)
    if result.returncode != 0:
        sys.exit(result.returncode)

    result = subprocess.run(["cmake", "--build", "build", "--config", "Release"])
    if result.returncode != 0:
        sys.exit(result.returncode)

    import shutil
    shutil.copy("build/agent", target)
    sys.exit(0)


def test():
    print(sys._getframe().f_code.co_name + ":", "not implemented")
    sys.exit(1)


def lint():
    print(sys._getframe().f_code.co_name + ":", "not implemented")
    sys.exit(1)


if __name__ == "__main__":
    choices = ["build", "test", "lint"]
    parser = argparse.ArgumentParser(description="Run project tasks.")
    parser.add_argument("function", choices=choices, help="The function to run.")
    args = parser.parse_args()
    globals()[args.function]()
```

#### Complete Agent

The complete C++ agent implements all protocol functionality in a single source file. It loads configuration from `config.json` using nlohmann/json, connects to NATS using the C client library with TLS (writing the embedded certificate to a temporary file for the NATS C API) and JWT/nkey authentication via `natsOptions_SetUserCredentialsFromMemory`. A detached thread publishes `UpdateClientInfo` heartbeat messages every 30 seconds, populating username from `getpwuid`, hostname from `gethostname`, system from `uname`, and address from the first non-loopback IPv4 interface. The agent subscribes to a JetStream consumer for `StartWorkerRequest` messages, extracting the worker ID by splitting the NATS subject on `.`. On receiving a command, the agent uses `fork`/`execve` to start the process with redirected stdout/stderr through a pipe, streams output as `UpdateWorkerStdio` messages, and publishes the exit code via `UpdateWorkerStatus` after `waitpid`. An `std::atomic<bool>` enforces the one-worker-at-a-time constraint. All Cap'n Proto messages are wrapped in the `Message` union envelope, serialized with `capnp::messageToFlatArray`, and all NATS subjects are constructed from the schema-defined constants using `snprintf`.

```cpp
#include <capnp/message.h>
#include <capnp/serialize.h>
#include "agent.capnp.h"

#include <nats/nats.h>
#include <nlohmann/json.hpp>

#include <atomic>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#include <arpa/inet.h>
#include <ifaddrs.h>
#include <pwd.h>
#include <signal.h>
#include <sys/utsname.h>
#include <sys/wait.h>
#include <unistd.h>

// Subject templates from agent.capnp
static const char* CMD_START_WORKER_T  = "FJ.AGENT.%s.CMD.WORKER.%s.START";
static const char* EVT_START_WORKER_T  = "FJ.AGENT.%s.EVT.WORKER.%s.START";
static const char* EVT_WORKER_STDOUT_T = "FJ.AGENT.%s.EVT.WORKER.%s.STDOUT";
static const char* EVT_WORKER_STATUS_T = "FJ.AGENT.%s.EVT.WORKER.%s.STATUS";
static const char* EVT_AGENT_INFO_T    = "FJ.AGENT.%s.EVT.INFO";

struct Config {
    std::string agent_id;
    std::string server_url;
    std::string server_certificate;
    std::string user_jwt;
    std::string user_key;
    std::string stream;
    std::string consumer;
    std::string inbox_prefix;
    std::string object_store;
};

Config loadConfig(const std::string& path) {
    std::ifstream file(path);
    nlohmann::json j;
    file >> j;
    return Config{
        .agent_id           = j["agent_id"],
        .server_url         = j["server_url"],
        .server_certificate = j["server_certificate"],
        .user_jwt           = j["user_jwt"],
        .user_key           = j["user_key"],
        .stream             = j["stream"],
        .consumer           = j["consumer"],
        .inbox_prefix       = j["inbox_prefix"],
        .object_store       = j["object_store"],
    };
}

struct StartRequest {
    std::string command;
    std::vector<std::string> args;
    std::vector<std::string> env;
};

static std::atomic<bool> workerRunning{false};

std::string getLocalIP() {
    struct ifaddrs* addrs;
    if (getifaddrs(&addrs) != 0) return "unknown";
    for (auto* addr = addrs; addr; addr = addr->ifa_next) {
        if (addr->ifa_addr && addr->ifa_addr->sa_family == AF_INET) {
            char buf[INET_ADDRSTRLEN];
            auto* sin = reinterpret_cast<struct sockaddr_in*>(addr->ifa_addr);
            if (ntohl(sin->sin_addr.s_addr) != INADDR_LOOPBACK) {
                inet_ntop(AF_INET, &sin->sin_addr, buf, sizeof(buf));
                freeifaddrs(addrs);
                return std::string(buf);
            }
        }
    }
    freeifaddrs(addrs);
    return "unknown";
}

std::string extractWorkerID(const char* subject) {
    std::vector<std::string> parts;
    std::stringstream ss(subject);
    std::string token;
    while (std::getline(ss, token, '.')) parts.push_back(token);
    return parts.size() >= 6 ? parts[5] : "";
}

void publishWords(natsConnection* nc, const char* subject, kj::Array<capnp::word>& words) {
    auto bytes = words.asBytes();
    natsConnection_Publish(nc, subject, bytes.begin(), bytes.size());
}

kj::Array<capnp::word> encodeClientInfo() {
    capnp::MallocMessageBuilder message;
    auto envelope = message.initRoot<Message>();
    auto info = envelope.getContent().initUpdateClientInfo();

    struct passwd* pw = getpwuid(getuid());
    char hostname[256];
    gethostname(hostname, sizeof(hostname));
    struct utsname uname_data;
    uname(&uname_data);

    info.setUsername(pw ? pw->pw_name : "unknown");
    info.setHostname(hostname);
    info.setSystem(uname_data.sysname);
    info.setAddress(getLocalIP().c_str());

    return capnp::messageToFlatArray(message);
}

kj::Array<capnp::word> encodeStartWorkerResponse(const std::string& error) {
    capnp::MallocMessageBuilder message;
    auto envelope = message.initRoot<Message>();
    auto resp = envelope.getContent().initStartWorkerResponse();
    resp.setError(error.c_str());
    return capnp::messageToFlatArray(message);
}

kj::Array<capnp::word> encodeWorkerStdio(const uint8_t* chunk, size_t len) {
    capnp::MallocMessageBuilder message;
    auto envelope = message.initRoot<Message>();
    auto stdio = envelope.getContent().initUpdateWorkerStdio();
    stdio.setData(kj::arrayPtr(chunk, len));
    return capnp::messageToFlatArray(message);
}

kj::Array<capnp::word> encodeWorkerStatus(int64_t exitCode) {
    capnp::MallocMessageBuilder message;
    auto envelope = message.initRoot<Message>();
    auto status = envelope.getContent().initUpdateWorkerStatus();
    status.setStatus(exitCode);
    return capnp::messageToFlatArray(message);
}

StartRequest decodeStartWorkerRequest(const void* data, int dataLen) {
    kj::ArrayPtr<const capnp::word> words(
        reinterpret_cast<const capnp::word*>(data),
        dataLen / sizeof(capnp::word));
    capnp::FlatArrayMessageReader reader(words);
    auto envelope = reader.getRoot<Message>();
    auto req = envelope.getContent().getStartWorkerRequest();

    StartRequest result;
    result.command = req.getCommand();
    for (auto arg : req.getArgs()) result.args.push_back(arg);
    for (auto env : req.getEnv()) result.env.push_back(env);
    return result;
}

natsConnection* connectToServer(const Config& cfg) {
    natsOptions* opts = nullptr;
    natsConnection* nc = nullptr;

    natsOptions_Create(&opts);
    natsOptions_SetURL(opts, cfg.server_url.c_str());

    std::string certFile = "/tmp/fj_server.crt";
    std::ofstream certOut(certFile);
    certOut << cfg.server_certificate;
    certOut.close();
    natsOptions_SetCATrustedCertificates(opts, certFile.c_str());

    natsOptions_SetUserCredentialsFromMemory(opts,
        cfg.user_jwt.c_str(), cfg.user_key.c_str());
    natsOptions_SetInboxPrefix(opts, cfg.inbox_prefix.c_str());

    natsStatus status = natsConnection_Connect(&nc, opts);
    natsOptions_Destroy(opts);
    if (status != NATS_OK) {
        throw std::runtime_error(std::string("NATS connect failed: ") + natsStatus_GetText(status));
    }
    return nc;
}

void handleStartWorker(natsConnection* nc, const Config& cfg,
                       const std::string& workerID, const StartRequest& req) {
    bool expected = false;
    if (!workerRunning.compare_exchange_strong(expected, true)) {
        char subj[256];
        snprintf(subj, sizeof(subj), EVT_START_WORKER_T, cfg.agent_id.c_str(), workerID.c_str());
        auto words = encodeStartWorkerResponse("a worker is already running");
        publishWords(nc, subj, words);
        return;
    }

    int pipefd[2];
    pipe(pipefd);

    pid_t pid = fork();
    if (pid < 0) {
        char subj[256];
        snprintf(subj, sizeof(subj), EVT_START_WORKER_T, cfg.agent_id.c_str(), workerID.c_str());
        auto words = encodeStartWorkerResponse("fork failed");
        publishWords(nc, subj, words);
        workerRunning.store(false);
        return;
    }

    if (pid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);
        close(pipefd[1]);

        std::vector<const char*> argv;
        argv.push_back(req.command.c_str());
        for (const auto& arg : req.args) argv.push_back(arg.c_str());
        argv.push_back(nullptr);

        std::vector<const char*> envp;
        for (const auto& e : req.env) envp.push_back(e.c_str());
        envp.push_back(nullptr);

        execve(req.command.c_str(), const_cast<char**>(argv.data()),
               const_cast<char**>(envp.data()));
        _exit(127);
    }

    close(pipefd[1]);

    char startSubj[256];
    snprintf(startSubj, sizeof(startSubj), EVT_START_WORKER_T,
             cfg.agent_id.c_str(), workerID.c_str());
    auto startWords = encodeStartWorkerResponse("");
    publishWords(nc, startSubj, startWords);

    char stdoutSubj[256];
    snprintf(stdoutSubj, sizeof(stdoutSubj), EVT_WORKER_STDOUT_T,
             cfg.agent_id.c_str(), workerID.c_str());

    uint8_t buf[4096];
    ssize_t bytesRead;
    while ((bytesRead = read(pipefd[0], buf, sizeof(buf))) > 0) {
        auto words = encodeWorkerStdio(buf, bytesRead);
        publishWords(nc, stdoutSubj, words);
    }
    close(pipefd[0]);

    int wstatus;
    waitpid(pid, &wstatus, 0);
    int64_t exitCode = WIFEXITED(wstatus) ? WEXITSTATUS(wstatus) : -1;

    char statusSubj[256];
    snprintf(statusSubj, sizeof(statusSubj), EVT_WORKER_STATUS_T,
             cfg.agent_id.c_str(), workerID.c_str());
    auto statusWords = encodeWorkerStatus(exitCode);
    publishWords(nc, statusSubj, statusWords);

    workerRunning.store(false);
}

static void onMessage(natsConnection* nc, natsSubscription* sub, natsMsg* msg, void* closure) {
    Config* cfg = static_cast<Config*>(closure);
    std::string workerID = extractWorkerID(natsMsg_GetSubject(msg));
    try {
        StartRequest req = decodeStartWorkerRequest(natsMsg_GetData(msg), natsMsg_GetDataLength(msg));
        handleStartWorker(nc, *cfg, workerID, req);
    } catch (const std::exception& e) {
        std::cerr << "decode error: " << e.what() << std::endl;
    }
    natsMsg_Destroy(msg);
}

void startHeartbeat(natsConnection* nc, const Config& cfg) {
    std::thread([nc, &cfg]() {
        char subject[256];
        snprintf(subject, sizeof(subject), EVT_AGENT_INFO_T, cfg.agent_id.c_str());
        while (true) {
            auto words = encodeClientInfo();
            auto bytes = words.asBytes();
            natsConnection_Publish(nc, subject, bytes.begin(), bytes.size());
            std::this_thread::sleep_for(std::chrono::seconds(30));
        }
    }).detach();
}

int main() {
    Config cfg = loadConfig("config.json");
    natsConnection* nc = connectToServer(cfg);

    startHeartbeat(nc, cfg);

    jsCtx* js = nullptr;
    natsConnection_JetStream(&js, nc, nullptr);

    char subscribeSubject[256];
    snprintf(subscribeSubject, sizeof(subscribeSubject), CMD_START_WORKER_T,
             cfg.agent_id.c_str(), "*");

    jsSubOptions so;
    jsSubOptions_Init(&so);
    so.Stream = cfg.stream.c_str();
    so.Consumer = cfg.consumer.c_str();

    natsSubscription* sub = nullptr;
    js_Subscribe(&sub, js, subscribeSubject, onMessage, &cfg, nullptr, &so, nullptr);

    std::cout << "Agent " << cfg.agent_id << " running" << std::endl;

    sigset_t waitSet;
    sigemptyset(&waitSet);
    sigaddset(&waitSet, SIGINT);
    sigaddset(&waitSet, SIGTERM);
    int sig;
    sigwait(&waitSet, &sig);

    natsSubscription_Destroy(sub);
    jsCtx_Destroy(js);
    natsConnection_Destroy(nc);
    return 0;
}
```

---

### Rust

#### Dependencies & Toolchain

Install the Rust toolchain via devbox:

```bash
devbox add rustup
rustup default stable
```

Add dependencies to `Cargo.toml`:

```bash
cargo add capnp@0.25
cargo add foojank --git https://github.com/foohq/foojank-proto --path rust
cargo add async-nats
cargo add nkeys
cargo add tokio --features full
cargo add serde --features derive
cargo add serde_json
```

The generated Cap'n Proto Rust bindings are in the `foojank` crate at `rust/` in the [foojank-proto repository](https://github.com/fooHQ/foojank-proto/tree/main/rust). The schema module is `foojank::agent_capnp`.

#### Build Script (`tasks.py`)

The build script reads `FJ_*` environment variables, writes `config.json` with embedded certificate contents, maps the `OS`/`ARCH` pair to a Rust target triple, then invokes `cargo build --release --target <triple>`. The resulting binary is copied to the `TARGET` filename.

```python
#!/usr/bin/env python3

import argparse
import json
import os
import sys
import subprocess


def build():
    fj_vars = {
        "agent_id": os.environ.get("FJ_AGENT_ID", ""),
        "server_url": os.environ.get("FJ_SERVER_URL", ""),
        "user_jwt": os.environ.get("FJ_USER_JWT", ""),
        "user_key": os.environ.get("FJ_USER_KEY", ""),
        "stream": os.environ.get("FJ_STREAM", ""),
        "consumer": os.environ.get("FJ_CONSUMER", ""),
        "inbox_prefix": os.environ.get("FJ_INBOX_PREFIX", ""),
        "object_store": os.environ.get("FJ_OBJECT_STORE", ""),
    }

    cert_path = os.environ.get("FJ_SERVER_CERTIFICATE", "")
    if cert_path and os.path.isfile(cert_path):
        with open(cert_path, "r") as f:
            fj_vars["server_certificate"] = f.read()
    else:
        fj_vars["server_certificate"] = ""

    with open("config.json", "w") as f:
        json.dump(fj_vars, f, indent=2)

    target_os = os.environ.get("OS", "linux")
    target_arch = os.environ.get("ARCH", "amd64")
    target = os.environ.get("TARGET", "agent")
    features = os.environ.get("FEATURES", "")

    rust_targets = {
        ("linux", "amd64"): "x86_64-unknown-linux-gnu",
        ("linux", "arm64"): "aarch64-unknown-linux-gnu",
        ("darwin", "amd64"): "x86_64-apple-darwin",
        ("darwin", "arm64"): "aarch64-apple-darwin",
        ("windows", "amd64"): "x86_64-pc-windows-msvc",
    }
    rust_target = rust_targets.get((target_os, target_arch), "x86_64-unknown-linux-gnu")

    cmd = ["cargo", "build", "--release", "--target", rust_target]
    if features:
        cmd.extend(features.split())

    result = subprocess.run(cmd)
    if result.returncode != 0:
        sys.exit(result.returncode)

    import shutil
    binary_name = "agent"
    if target_os == "windows":
        binary_name += ".exe"
    src = f"target/{rust_target}/release/{binary_name}"
    shutil.copy(src, target)
    sys.exit(0)


def test():
    print(sys._getframe().f_code.co_name + ":", "not implemented")
    sys.exit(1)


def lint():
    print(sys._getframe().f_code.co_name + ":", "not implemented")
    sys.exit(1)


if __name__ == "__main__":
    choices = ["build", "test", "lint"]
    parser = argparse.ArgumentParser(description="Run project tasks.")
    parser.add_argument("function", choices=choices, help="The function to run.")
    args = parser.parse_args()
    globals()[args.function]()
```

#### Complete Agent

The complete Rust agent implements all protocol functionality in a single `main.rs` using `tokio` for async I/O. It loads configuration from `config.json` using serde, connects to the NATS server using `async-nats` with TLS (parsing the embedded PEM certificate into a `rustls` root certificate store) and JWT/nkey authentication via the `nkeys` crate's `KeyPair::from_seed` and `sign`. A spawned tokio task publishes `UpdateClientInfo` heartbeat messages every 30 seconds, populating username and hostname from the `whoami` crate, system from `std::env::consts::OS`, and address from the `local_ip_address` crate. The agent binds to a JetStream pull consumer and iterates over incoming messages, extracting the worker ID from the NATS subject by splitting on `.`. On receiving a `StartWorkerRequest`, it spawns the process via `tokio::process::Command` with piped stdout/stderr, streams output as `UpdateWorkerStdio` messages, and publishes the exit code as `UpdateWorkerStatus`. An `Arc<Mutex<bool>>` enforces the one-worker-at-a-time constraint. All Cap'n Proto messages are wrapped in the `Message` union envelope via `foojank::agent_capnp::message`, and all NATS subjects are constructed from the schema-defined constants using string replacement.

```rust
use async_nats::jetstream::{self, consumer::PullConsumer};
use capnp::message::{Builder, ReaderOptions};
use capnp::serialize;
use foojank::agent_capnp::message;
use futures::StreamExt;
use nkeys::KeyPair;
use serde::Deserialize;
use std::io::Cursor;
use std::process::Stdio;
use std::sync::Arc;
use tokio::io::AsyncReadExt;
use tokio::process::Command;
use tokio::sync::Mutex;
use tokio::time::{self, Duration};

// Subject templates from agent.capnp
const CMD_START_WORKER_T: &str = "FJ.AGENT.%s.CMD.WORKER.%s.START";
const EVT_START_WORKER_T: &str = "FJ.AGENT.%s.EVT.WORKER.%s.START";
const EVT_WORKER_STDOUT_T: &str = "FJ.AGENT.%s.EVT.WORKER.%s.STDOUT";
const EVT_WORKER_STATUS_T: &str = "FJ.AGENT.%s.EVT.WORKER.%s.STATUS";
const EVT_AGENT_INFO_T: &str = "FJ.AGENT.%s.EVT.INFO";

#[derive(Deserialize, Clone)]
struct Config {
    agent_id: String,
    server_url: String,
    server_certificate: String,
    user_jwt: String,
    user_key: String,
    stream: String,
    consumer: String,
    inbox_prefix: String,
    object_store: String,
}

struct StartRequest {
    command: String,
    args: Vec<String>,
    env: Vec<String>,
}

fn load_config(path: &str) -> Result<Config, Box<dyn std::error::Error>> {
    let data = std::fs::read_to_string(path)?;
    Ok(serde_json::from_str(&data)?)
}

async fn connect(cfg: &Config) -> Result<async_nats::Client, Box<dyn std::error::Error>> {
    let certs = rustls_pemfile::certs(&mut cfg.server_certificate.as_bytes())
        .collect::<Result<Vec<_>, _>>()?;
    let mut root_store = rustls::RootCertStore::empty();
    for cert in certs {
        root_store.add(cert)?;
    }
    let tls_config = rustls::ClientConfig::builder()
        .with_root_certificates(root_store)
        .with_no_client_auth();

    let jwt = cfg.user_jwt.clone();
    let seed = cfg.user_key.clone();

    let client = async_nats::ConnectOptions::new()
        .tls_client_config(tls_config)
        .jwt(jwt, move |nonce| {
            let seed = seed.clone();
            async move {
                let kp = KeyPair::from_seed(&seed)
                    .map_err(|e| async_nats::AuthError::new(e.to_string()))?;
                kp.sign(nonce.as_bytes())
                    .map_err(|e| async_nats::AuthError::new(e.to_string()))
            }
        })
        .custom_inbox_prefix(&cfg.inbox_prefix)
        .connect(&cfg.server_url)
        .await?;

    Ok(client)
}

fn extract_worker_id(subject: &str) -> &str {
    let parts: Vec<&str> = subject.split('.').collect();
    if parts.len() >= 6 { parts[5] } else { "" }
}

fn format_subject(template: &str, agent_id: &str, worker_id: &str) -> String {
    template.replacen("%s", agent_id, 1).replacen("%s", worker_id, 1)
}

fn format_subject_single(template: &str, agent_id: &str) -> String {
    template.replacen("%s", agent_id, 1)
}

fn encode_client_info() -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    let mut builder = Builder::new_default();
    {
        let envelope = builder.init_root::<message::Builder>();
        let mut info = envelope.get_content().init_update_client_info();
        let username = whoami::username();
        let hostname = whoami::fallible::hostname().unwrap_or_else(|_| "unknown".into());
        let system = std::env::consts::OS;
        let address = local_ip_address::local_ip()
            .map(|ip| ip.to_string())
            .unwrap_or_else(|_| "unknown".into());
        info.set_username(&username);
        info.set_hostname(&hostname);
        info.set_system(system);
        info.set_address(&address);
    }
    let mut buf = Vec::new();
    serialize::write_message(&mut buf, &builder)?;
    Ok(buf)
}

fn encode_start_worker_response(error: &str) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    let mut builder = Builder::new_default();
    {
        let envelope = builder.init_root::<message::Builder>();
        let mut resp = envelope.get_content().init_start_worker_response();
        resp.set_error(error);
    }
    let mut buf = Vec::new();
    serialize::write_message(&mut buf, &builder)?;
    Ok(buf)
}

fn encode_worker_stdio(chunk: &[u8]) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    let mut builder = Builder::new_default();
    {
        let envelope = builder.init_root::<message::Builder>();
        let mut stdio = envelope.get_content().init_update_worker_stdio();
        stdio.set_data(chunk);
    }
    let mut buf = Vec::new();
    serialize::write_message(&mut buf, &builder)?;
    Ok(buf)
}

fn encode_worker_status(exit_code: i64) -> Result<Vec<u8>, Box<dyn std::error::Error>> {
    let mut builder = Builder::new_default();
    {
        let envelope = builder.init_root::<message::Builder>();
        let mut status = envelope.get_content().init_update_worker_status();
        status.set_status(exit_code);
    }
    let mut buf = Vec::new();
    serialize::write_message(&mut buf, &builder)?;
    Ok(buf)
}

fn decode_start_worker_request(data: &[u8]) -> Result<StartRequest, Box<dyn std::error::Error>> {
    let reader = serialize::read_message(&mut Cursor::new(data), ReaderOptions::new())?;
    let envelope = reader.get_root::<message::Reader>()?;
    let req = envelope.get_content().get_start_worker_request()?;

    let command = req.get_command()?.to_str()?.to_string();

    let args_list = req.get_args()?;
    let mut args = Vec::new();
    for i in 0..args_list.len() {
        args.push(args_list.get(i)?.to_str()?.to_string());
    }

    let env_list = req.get_env()?;
    let mut env = Vec::new();
    for i in 0..env_list.len() {
        env.push(env_list.get(i)?.to_str()?.to_string());
    }

    Ok(StartRequest { command, args, env })
}

async fn handle_start_worker(
    client: &async_nats::Client,
    agent_id: &str,
    worker_id: &str,
    req: StartRequest,
    running: Arc<Mutex<bool>>,
) {
    {
        let mut guard = running.lock().await;
        if *guard {
            if let Ok(data) = encode_start_worker_response("a worker is already running") {
                let subject = format_subject(EVT_START_WORKER_T, agent_id, worker_id);
                let _ = client.publish(subject, data.into()).await;
            }
            return;
        }
        *guard = true;
    }

    let result: Result<(), Box<dyn std::error::Error + Send + Sync>> = async {
        let mut child = match Command::new(&req.command)
            .args(&req.args)
            .envs(req.env.iter().filter_map(|e| {
                let mut parts = e.splitn(2, '=');
                Some((parts.next()?, parts.next()?))
            }))
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
        {
            Ok(child) => {
                let data = encode_start_worker_response("")?;
                let subject = format_subject(EVT_START_WORKER_T, agent_id, worker_id);
                client.publish(subject, data.into()).await?;
                child
            }
            Err(e) => {
                let data = encode_start_worker_response(&e.to_string())?;
                let subject = format_subject(EVT_START_WORKER_T, agent_id, worker_id);
                client.publish(subject, data.into()).await?;
                return Ok(());
            }
        };

        let stdout_subject = format_subject(EVT_WORKER_STDOUT_T, agent_id, worker_id);
        if let Some(mut stdout) = child.stdout.take() {
            let mut buf = vec![0u8; 4096];
            loop {
                match stdout.read(&mut buf).await {
                    Ok(0) => break,
                    Ok(n) => {
                        if let Ok(data) = encode_worker_stdio(&buf[..n]) {
                            let _ = client.publish(stdout_subject.clone(), data.into()).await;
                        }
                    }
                    Err(_) => break,
                }
            }
        }

        let status = child.wait().await?;
        let exit_code = status.code().map(|c| c as i64).unwrap_or(-1);
        let data = encode_worker_status(exit_code)?;
        let subject = format_subject(EVT_WORKER_STATUS_T, agent_id, worker_id);
        client.publish(subject, data.into()).await?;

        Ok(())
    }
    .await;

    if let Err(e) = result {
        eprintln!("worker error: {}", e);
    }

    let mut guard = running.lock().await;
    *guard = false;
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cfg = load_config("config.json")?;
    let client = connect(&cfg).await?;

    // Start heartbeat
    let hb_client = client.clone();
    let hb_agent_id = cfg.agent_id.clone();
    tokio::spawn(async move {
        let subject = format_subject_single(EVT_AGENT_INFO_T, &hb_agent_id);
        let mut interval = time::interval(Duration::from_secs(30));
        loop {
            interval.tick().await;
            if let Ok(data) = encode_client_info() {
                let _ = hb_client.publish(subject.clone(), data.into()).await;
            }
        }
    });

    // JetStream consumer
    let js = jetstream::new(client.clone());
    let stream = js.get_stream(&cfg.stream).await?;
    let consumer: PullConsumer = stream.get_consumer(&cfg.consumer).await?;

    let running = Arc::new(Mutex::new(false));

    println!("Agent {} running", cfg.agent_id);

    let mut messages = consumer.messages().await?;
    while let Some(Ok(msg)) = messages.next().await {
        let worker_id = extract_worker_id(&msg.subject).to_string();
        match decode_start_worker_request(&msg.payload) {
            Ok(req) => {
                let _ = msg.ack().await;
                handle_start_worker(&client, &cfg.agent_id, &worker_id, req, running.clone()).await;
            }
            Err(e) => {
                eprintln!("decode error: {}", e);
            }
        }
    }

    Ok(())
}
```
