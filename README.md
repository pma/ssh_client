# SshClient

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add ssh_client to your list of dependencies in mix.exs:

        def deps do
          [{:ssh_client, "~> 0.0.1"}]
        end

  2. Ensure ssh_client is started before your application:

        def application do
          [applications: [:ssh_client]]
        end

## Running

```iex
iex(1)> {:ok, conn} = SSHClient.start_link 'localhost', 22, [user: 'YOUR_USER', password: 'YOUR_PASS']
iex(2)> {:ok, stdout} = SSHClient.run conn, 'ls /tmp'
```
