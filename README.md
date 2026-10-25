# brickadia-server

Working notes and config for a Brickadia dedicated server stood up on a
network-restricted Linux host (a molab GPU sandbox) and exposed to players over a
UDP tunnel.

Server build: **`Release-EA3-CL-16374`**, Steam app **3017590**, depots
`1006` / `3017592`.

## What was actually hard

Not the server. Two host constraints:

1. **SteamCMD cannot run.** `steamcmd_linux.tar.gz` ships only a 32-bit
   `linux32/steamcmd` binary. The host kernel is gVisor
   (`4.19.0-gvisor`), which has no IA32 emulation, so it dies immediately:

   ```
   ./steamcmd.sh: line 37: /opt/steamcmd/linux32/steamcmd: cannot execute binary file: Exec format error
   ```

   Installing `lib32gcc-s1` does not help — it is a kernel capability, not a
   userspace one. The depot was fetched with **DepotDownloader 3.4.0**
   (self-contained .NET, x86-64) instead, logging in anonymously.

2. **The host has no inbound path.** It sits behind NAT with a rotating egress
   IP (three consecutive `GET /` returned `.194`, `.244`, `.241`). A UDP probe
   from outside never arrived, so no port forward is even theoretically possible
   — there is no stable address to forward to. Players therefore reach the
   server through a **playit.gg UDP tunnel**, which works because it is
   outbound-only from this side.

## Reproduce

```bash
# 1. fetch the dedicated server (anonymous; no Steam account needed)
./download.sh /opt/brickadia

# 2. start it (token from the environment; never commit it)
export BRICKADIA_TOKEN='<base64 token from brickadia.com>'
./start.sh /opt/brickadia

# 3. expose UDP 7777
#    playit agent, then in the dashboard: Add tunnel -> Custom -> UDP
#    local 127.0.0.1 : 7777, port count 1, proxy protocol None
/opt/playit --secret "$PLAYIT_SECRET"
```

Pinned versions live in `download.sh` and `manifests.txt` so a rebuild is
byte-identical to what was tested.

## Launch

```
BrickadiaServer-Linux-Shipping -log -port=7777 -token=<base64>
```

- `-token` is a **server hosting token** generated at brickadia.com. It is
  checked against Brickadia's `BRAuthSubsystem`, which resolves the account:
  `Found token on command line` -> `Logged in as olliez3434`. The session is
  cached under `Saved/Auth2/`, so later runs work without the flag — but the
  flag is harmless and keeps the account explicit.
- `HOME` must point somewhere writable; the server keeps its world, roles and
  auth cache under `$HOME/.config/Epic/Brickadia/Saved/`.
- `LD_LIBRARY_PATH` must include `Brickadia/Binaries/Linux`, otherwise
  `libEOSSDK-Linux-Shipping.so` is not found.

## Verified state

| item | value |
|---|---|
| process | `BrickadiaServer-Linux-Shipping`, 564 MiB RSS |
| listen | `0.0.0.0:7777/udp` (single socket; no separate query port) |
| world | `/Game/Maps/Plate/Plate`, first boot wrote `Saved/Server/RoleSetup2.json` |
| token | accepted, account `olliez3434` |
| tunnel | playit agent connected, `tunnel_count=1` |

End-to-end proof — packets sent from outside the host reached the game server:

```
LogNet: NotifyAcceptingConnection accepted from: 127.67.239.169:53854
LogNet: NotifyAcceptingConnection accepted aggregation: 127.0.0.1:51676 (5), 127.67.239.169:53854 (5)
```

Any datagram produces a `NotifyAcceptingConnection` line, which makes this a
usable liveness check without a game client.

## Known issues

**EOS socket subsystem does not load.** The build mounts the `SocketSubsystemEOS`
plugin but never loads the module, so networking falls back to plain UDP:

```
LogOnline: Warning: OSS: TryLoadSubsystemAndSetDefault: LoadSubsystemModule([NULL]) failed
LogSockets: Warning: Unable to load SocketSubsystem module EOS
LogNet: Warning: CreateNetDriver: driver class '/Script/SocketSubsystemEOS.NetDriverEOS' is unavailable,
          using fallback '/Script/OnlineSubsystemUtils.IpNetDriver'
```

The server still authenticates and still posts itself to the server browser
(`LogServerList: Posting server.` every 60s), but what it advertises is its
internal NAT address, so the browser entry is not joinable. **Players must use
Join Game -> Connect Manually** with the tunnel address. Fixing this would
require the missing EOS module, which is not present in the shipped depot (no
`Plugins/` tree, no `SocketSubsystemEOS.so`), so it is a build limitation, not
a config error.

**The host is ephemeral.** The server, world, playit agent and tunnel all die
with the sandbox session. `server/` here is a snapshot of the per-host state
(roles, settings) for restoring onto a durable box; the 738 MiB depot itself is
deliberately not committed.

**No console.** Launched detached with stdin closed, so admin commands
(`BR.World.SaveAs`, `BR.Server.Name`) cannot be issued. Run it under a FIFO or
an interactive session if that is needed.

## Never commit

- `Saved/Auth2/{SessionToken,OfflinePayload,OfflineSignature}.bin` — account auth.
- the server hosting token (in `.gitignore`; `start.sh` reads `BRICKADIA_TOKEN`).
- the playit agent secret (`~/.config/playit_gg/playit.toml`).
