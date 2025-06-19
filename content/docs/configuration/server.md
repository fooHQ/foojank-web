---
title: Server
weight: 1
---

Default server configuration can be generated running a command:

```
$ foojank config generate server --tls-subject-name "example.com" > server.conf
```

The command requires specifying a Subject Name for a TLS certificate, which secures server communication.
This value can be either an IP address or a hostname, but it must match the server’s public IP or hostname to pass TLS certificate verification.

It also generates private keys and JWTs, which the NATS server uses for client authentication.
To prevent unauthorized access to the C2 server, ensure the file remains secure, as its compromise could allow full control over the server.

NATS supports connections over TCP and WebSocket. Currently, WebSocket is the primary connection type, and it is not possible to change this setting.

The resulting file acts as a template for creating client configurations.

```toml{filename=server.conf}
data_dir = '/Users/user/foojank'
log_level = 'info'
no_color = false

[server]
host = '0.0.0.0'
port = 443
operator_jwt = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJqdGkiOiJYSEVUMkFFMlhWQUJSRDVBWExJWTNBTDNLWlM2TFQ1RlY2NDJLRktDTFFPS0hXQ1RPUk1RIiwiaWF0IjoxNzUwMjI1NTE2LCJpc3MiOiJPQ01OWTJBWkhSQU1QTEhWWDRIN0VZUkhVTjZORklIRklER01HU0JNVlJYTDRKVE9QQkFPSTU3TiIsIm5hbWUiOiJPUDVZN2tJSktwdGliU2g2SG1lZ01tUVAiLCJzdWIiOiJPQ01OWTJBWkhSQU1QTEhWWDRIN0VZUkhVTjZORklIRklER01HU0JNVlJYTDRKVE9QQkFPSTU3TiIsIm5hdHMiOnsic2lnbmluZ19rZXlzIjpbIk9DVjVJSUNNSTc0TTYzMkdSWUZXREpLSkpONDZGUVo2UkRCNkpJWDc3U1VWUFFSVlBNSlBINkhSIl0sInR5cGUiOiJvcGVyYXRvciIsInZlcnNpb24iOjJ9fQ.ZdP6OGS5YOfImlx1hCXhsFTfebYm56TFeg7TfI63LrcyPEcVbzC4MK_t-aB7s8q3nMdCHipkdE7ByoS8-lNrAw'
operator_key = 'SOAFDANTH4WCZWFLADDZBB5RNRUGEAWUWUEP4QUD3J6SKL5WJ646MM2LM4'
account_jwt = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJqdGkiOiI0SDY2V0ZRNVFPNVhFTDJXVkdRR0hWTU5UV1E3RzJGWVpKSDZaVTVHSjJHUlROUUZGU0xRIiwiaWF0IjoxNzUwMjI1NTE2LCJpc3MiOiJPQ1Y1SUlDTUk3NE02MzJHUllGV0RKS0pKTjQ2RlFaNlJEQjZKSVg3N1NVVlBRUlZQTUpQSDZIUiIsIm5hbWUiOiJBQzVZN2tJSktwdGliU2g2SG1lZ01tVWkiLCJzdWIiOiJBQURFRjM0RFlYVEFaNVE1UlZTTUoyTEEzM1FBV1BIWEdIUkg1SUxSWFRWU0hMNUZFNkJCWVg1QSIsIm5hdHMiOnsibGltaXRzIjp7InN1YnMiOi0xLCJkYXRhIjotMSwicGF5bG9hZCI6LTEsImltcG9ydHMiOi0xLCJleHBvcnRzIjotMSwid2lsZGNhcmRzIjp0cnVlLCJjb25uIjotMSwibGVhZiI6LTEsIm1lbV9zdG9yYWdlIjotMSwiZGlza19zdG9yYWdlIjotMX0sInNpZ25pbmdfa2V5cyI6WyJBQUZCUlpYVlVQWEdQN1A3SE0yREJYNjU3QlZQWjVPRlZaVDdTRk9BTTI1QTZKRTNCR0tNTEI1QiJdLCJkZWZhdWx0X3Blcm1pc3Npb25zIjp7InB1YiI6e30sInN1YiI6e319LCJhdXRob3JpemF0aW9uIjp7fSwidHlwZSI6ImFjY291bnQiLCJ2ZXJzaW9uIjoyfX0.wROXCZb3HQ4CEpC0-KSPlGxpr1azeWtsRJNx1Qdj6AtY-GBb2M_HCMfqyNJqj01fJ5FCa3D3_5R5R5Xrp-IYCw'
account_key = 'SAABVCV2A3E7KU2DIDCG2UJXX6ERCB7TAEJO6WUU3E5UDKXOO3V4STUGRE'
system_account_jwt = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJqdGkiOiJERjdQQkI1WDZHUFJLVVVBWE9XQUNMVVozR1ZJSlJVRUpCNUtKRU5GUUE1RFg0T1FGT1BBIiwiaWF0IjoxNzUwMjI1NTE2LCJpc3MiOiJPQ1Y1SUlDTUk3NE02MzJHUllGV0RKS0pKTjQ2RlFaNlJEQjZKSVg3N1NVVlBRUlZQTUpQSDZIUiIsIm5hbWUiOiJTWVMiLCJzdWIiOiJBQUc3NENHSUMzQkNLRlE0UVFMUzdZVUtTQkZDRVk0QlFFWkNBNEpCVlFBVTVNUU1aM1ZQV0tTNiIsIm5hdHMiOnsibGltaXRzIjp7InN1YnMiOi0xLCJkYXRhIjotMSwicGF5bG9hZCI6LTEsImltcG9ydHMiOi0xLCJleHBvcnRzIjotMSwid2lsZGNhcmRzIjp0cnVlLCJjb25uIjotMSwibGVhZiI6LTF9LCJzaWduaW5nX2tleXMiOlsiQUJZMlRQV0tZVjVDNk9XUkRIUTNINU5aV0RZSUREM1FGR0VONkhYN0xBNktJNjJRRU5PTzdLR1YiXSwiZGVmYXVsdF9wZXJtaXNzaW9ucyI6eyJwdWIiOnt9LCJzdWIiOnt9fSwiYXV0aG9yaXphdGlvbiI6e30sInR5cGUiOiJhY2NvdW50IiwidmVyc2lvbiI6Mn19.41VwG7Sd2AHJ_gooPDBF-YC4hp8yTgnRfWOk7xScvQFdnjE2DJ2LpQf8XReVtnqzxgc8YoTyi3kGzVC7LQGkBg'
system_account_key = 'SAAI4FG6PKTUFJBQ4UZSJPSZ5K5S7HNUXS3MWQX7Y4572IWJXAC65H4YE4'
tls_certificate = 'MIIBezCCASCgAwIBAgIQCWwdyaQ4mwU2+bDEs9tQhzAKBggqhkjOPQQDAjASMRAwDgYDVQQLEwdBQ01FIENvMB4XDTI1MDYxODA1NDUxNloXDTI2MDYxODA1NDUxNlowEjEQMA4GA1UECxMHQUNNRSBDbzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABB3Mq84UEborMR2SgtHpmEKZ0kpnTlAQzaCFhYRAta7vvjcKShNSTCikj174cjUIPmwbMmp7jyiIfRdbiFpdOmmjWDBWMA4GA1UdDwEB/wQEAwIChDAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBSUXkowWjPQ/SmBYyaw3g3121+yuTAUBgNVHREEDTALgglsb2NhbGhvc3QwCgYIKoZIzj0EAwIDSQAwRgIhAJP1pGfMezdSF/U9b5913rhuZNLcRmztiWP6J8flKt4yAiEAjV2DWoFsY4ucIhud56f4FBiasnlHVUOGTMiNGfsPbSg='
tls_key = 'MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgvLrvSc1NTDYJTHIvLpA6em7ISb5MWnE7Zu8lh9ru+76hRANCAAQdzKvOFBG6KzEdkoLR6ZhCmdJKZ05QEM2ghYWEQLWu7743CkoTUkwopI9e+HI1CD5sGzJqe48oiH0XW4haXTpp'
```

## Configuration Options

- `data_dir` (string):
    - **Description**: Specifies the directory where the server stores its data. Ensure the directory exists and is writable by the server process.
    - **Default**: `$HOME/foojank`

- `log_level` (string):
    - **Description**: Sets the verbosity of server logs. Common values include `debug`, `info`, `warn`, `error`. This option currently have no effect.
    - **Default**: `info`

- `no_color` (boolean):
    - **Description**: Disables colored output in logs if set to `true`. This option currently have no effect.
    - **Default**: `false`

- `[server]` Section:
    - `host` (string):
        - **Description**: The IP address or hostname the server binds to.
        - **Default**: `0.0.0.0`
    - `port` (integer):
        - **Description**: The port the server listens on for incoming connections.
        - **Default**: `443`
    - `operator_jwt` (string):
        - **Description**: The JWT for NATS server operator used for [authentication](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/auth_intro/jwt).
        - **Default**: A base64-encoded JWT string.
    - `operator_key` (string):
        - **Description**: The private key associated with the `operator_jwt`.
        - **Default**: A base64-encoded [Nkey](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/auth_intro/nkey_auth).
    - `account_jwt` (string):
        - **Description**: The JWT for NATS server account used for [authentication](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/auth_intro/jwt).
        - **Default**: A base64-encoded JWT string.
    - `account_key` (string):
        - **Description**: The private key associated with the `account_jwt`.
        - **Default**: A base64-encoded [Nkey](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/auth_intro/nkey_auth).
    - `system_account_jwt` (string):
        - **Description**: The JWT for the system account, used for internal NATS operations.
        - **Default**: A base64-encoded JWT string.
    - `system_account_key` (string):
        - **Description**: The private key associated with the `system_account_jwt`.
        - **Default**: A base64-encoded [Nkey](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/auth_intro/nkey_auth).
    - `tls_certificate` (string):
        - **Description**: A self-signed TLS certificate for securing server connections.
        - **Default**: A base64-encoded certificate.
    - `tls_key` (string):
        - **Description**: The private key for the TLS certificate `tls_certificate`.
        - **Default**: A base64-encoded key.
