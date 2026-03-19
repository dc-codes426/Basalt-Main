# Basalt

Hardened fork of [vultisig/vultiserver](https://github.com/vultisig/vultiserver). TSS server for keygen, keysign, and reshare operations using the GG20 threshold protocol.

## Architecture

Basalt runs as a set of containers:

- **basalt-vultiserver** - Modified version of the open-source vultiserver
- **redis** - Session and state storage required by vultiserver

## License

Proprietary.
