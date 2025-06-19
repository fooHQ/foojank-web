---
title: Client
weight: 2
---

Client configuration can be generated running a command:

```
$ foojank config generate client server.conf > client.conf
```

The command requires a server configuration file as an argument to extract the account JWT, account key, and server's TLS certificate.
JWTs and keys must be consistent with the server’s configuration to ensure successful authentication.

It generates a new user key and JWT, signed with the server's account key. The client uses this user JWT and key to authenticate with the server.

The account key is retained in the client configuration, as it is required to sign user JWTs for agents. To prevent compromise of the C2 server, the configuration file must remain secure, as a stolen account key could be used to take full control.

```toml{filename=client.conf}
data_dir = '/Users/user/foojank'
log_level = 'info'
no_color = false

[client]
server = ['wss://localhost']
user_jwt = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJqdGkiOiJCQ1E0UlUzQkZIMlBaNlROQ1RBR0VZWUJLSUpEWDUyNDNYNlNQMkVETVdNVVgyVFpRT1dBIiwiaWF0IjoxNzUwMjI1NTIyLCJpc3MiOiJBQUZCUlpYVlVQWEdQN1A3SE0yREJYNjU3QlZQWjVPRlZaVDdTRk9BTTI1QTZKRTNCR0tNTEI1QiIsIm5hbWUiOiJNR25CYXhhZE1Ua01kNlh5bTVBMkcxbGgiLCJzdWIiOiJVQ1FFUjRWNlhBSDVVU1RBR0JHREdKTjZBVUpZRzdaVlZEQldZVTdLQ0Y0RlJXTFhYTkRURlhZNiIsIm5hdHMiOnsicHViIjp7fSwic3ViIjp7fSwic3VicyI6LTEsImRhdGEiOi0xLCJwYXlsb2FkIjotMSwiaXNzdWVyX2FjY291bnQiOiJBQURFRjM0RFlYVEFaNVE1UlZTTUoyTEEzM1FBV1BIWEdIUkg1SUxSWFRWU0hMNUZFNkJCWVg1QSIsInR5cGUiOiJ1c2VyIiwidmVyc2lvbiI6Mn19.oS6jp0W7WBGDfjOuUsowSM2bXoK6c3_Xfsy989NvFEBaE1ildQ8sxrUXK54h1FOrgWfvPjXHBjnrhkPhudcjDw'
user_key = 'SUAKFBWZUOAWA5HWGKCT3TPOWDD2S4SLZPNUCYBK2OZPQ7OKSJGHQZU264'
account_jwt = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJlZDI1NTE5LW5rZXkifQ.eyJqdGkiOiI0SDY2V0ZRNVFPNVhFTDJXVkdRR0hWTU5UV1E3RzJGWVpKSDZaVTVHSjJHUlROUUZGU0xRIiwiaWF0IjoxNzUwMjI1NTE2LCJpc3MiOiJPQ1Y1SUlDTUk3NE02MzJHUllGV0RKS0pKTjQ2RlFaNlJEQjZKSVg3N1NVVlBRUlZQTUpQSDZIUiIsIm5hbWUiOiJBQzVZN2tJSktwdGliU2g2SG1lZ01tVWkiLCJzdWIiOiJBQURFRjM0RFlYVEFaNVE1UlZTTUoyTEEzM1FBV1BIWEdIUkg1SUxSWFRWU0hMNUZFNkJCWVg1QSIsIm5hdHMiOnsibGltaXRzIjp7InN1YnMiOi0xLCJkYXRhIjotMSwicGF5bG9hZCI6LTEsImltcG9ydHMiOi0xLCJleHBvcnRzIjotMSwid2lsZGNhcmRzIjp0cnVlLCJjb25uIjotMSwibGVhZiI6LTEsIm1lbV9zdG9yYWdlIjotMSwiZGlza19zdG9yYWdlIjotMX0sInNpZ25pbmdfa2V5cyI6WyJBQUZCUlpYVlVQWEdQN1A3SE0yREJYNjU3QlZQWjVPRlZaVDdTRk9BTTI1QTZKRTNCR0tNTEI1QiJdLCJkZWZhdWx0X3Blcm1pc3Npb25zIjp7InB1YiI6e30sInN1YiI6e319LCJhdXRob3JpemF0aW9uIjp7fSwidHlwZSI6ImFjY291bnQiLCJ2ZXJzaW9uIjoyfX0.wROXCZb3HQ4CEpC0-KSPlGxpr1azeWtsRJNx1Qdj6AtY-GBb2M_HCMfqyNJqj01fJ5FCa3D3_5R5R5Xrp-IYCw'
account_key = 'SAABVCV2A3E7KU2DIDCG2UJXX6ERCB7TAEJO6WUU3E5UDKXOO3V4STUGRE'
tls_ca_certificate = 'MIIBezCCASCgAwIBAgIQCWwdyaQ4mwU2+bDEs9tQhzAKBggqhkjOPQQDAjASMRAwDgYDVQQLEwdBQ01FIENvMB4XDTI1MDYxODA1NDUxNloXDTI2MDYxODA1NDUxNlowEjEQMA4GA1UECxMHQUNNRSBDbzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABB3Mq84UEborMR2SgtHpmEKZ0kpnTlAQzaCFhYRAta7vvjcKShNSTCikj174cjUIPmwbMmp7jyiIfRdbiFpdOmmjWDBWMA4GA1UdDwEB/wQEAwIChDAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBSUXkowWjPQ/SmBYyaw3g3121+yuTAUBgNVHREEDTALgglsb2NhbGhvc3QwCgYIKoZIzj0EAwIDSQAwRgIhAJP1pGfMezdSF/U9b5913rhuZNLcRmztiWP6J8flKt4yAiEAjV2DWoFsY4ucIhud56f4FBiasnlHVUOGTMiNGfsPbSg='
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

- `[client]` Section:
    - `server` (array of strings):
        - **Description**: A list of server WebSocket URLs the client connects to.
        - **Default**: `['wss://localhost']`
        - **Notes**: Use `wss://` for secure WebSocket connections over TLS.
    - `user_jwt` (string):
        - **Description**: The JWT for NATS server user used for [authentication](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/auth_intro/jwt).
        - **Default**: A base64-encoded JWT string.
        - **Description**: The JWT for user-level authentication in NATS.
    - `user_key` (string):
        - **Description**: The private key associated with the `user_jwt`.
        - **Default**: A base64-encoded [Nkey](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/auth_intro/nkey_auth).
    - `account_jwt` (string):
        - **Description**: The JWT for NATS server account used for [authentication](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/auth_intro/jwt).
        - **Default**: A base64-encoded JWT string.
    - `account_key` (string):
        - **Description**: The private key associated with the `account_jwt`.
        - **Default**: A base64-encoded [Nkey](https://docs.nats.io/running-a-nats-service/configuration/securing_nats/auth_intro/nkey_auth).
    - `tls_ca_certificate` (string):
        - **Description**: The CA certificate used to verify the server’s TLS certificate.
        - **Default**: A base64-encoded certificate.
