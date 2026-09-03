# Minecraft server 1.21.11 (vanilla) — for mc.walawe.fun

> **Author:** antinormies &lt;antiableofnormiesable@gmail.com&gt;

A self-contained vanilla Minecraft **Java Edition 1.21.11** server that runs on
your VPS behind the Cloudflare Tunnel you already set up.

## What's in this folder

| File | Purpose |
|---|---|
| `server.jar` | Official vanilla 1.21.11 server jar (SHA-1 verified against Mojang) |
| `jre/` | Portable Java 21 runtime (Temurin). No install needed — but see "Java" below |
| `server.properties` | Server config (port, MOTD, online-mode, players, difficulty…) |
| `eula.txt` | `eula=true` — **this accepts Mojang's EULA; only run the server if you agree** |
| `start.sh` | Launcher: uses `jre/` if present, else system Java; G1GC flags; `MC_RAM=…` to override memory |
| `stop.sh` | Graceful stop (only for the tmux run mode) |
| `minecraft.service` | systemd unit (recommended way to run on a VPS) |
| `cloudflared-config-snippet.yml` | Ingress rule to add to your tunnel |

## 1. Copy this folder to the VPS

From your local machine:

```bash
rsync -av ~/Downloads/minecraft-server/ user@YOUR_VPS_IP:/opt/minecraft-server/
# or: scp -r ~/Downloads/minecraft-server user@YOUR_VPS_IP:/opt/minecraft-server
```

Then on the VPS:

```bash
cd /opt/minecraft-server
chmod +x start.sh stop.sh
```

### Java

`start.sh` first tries the bundled `./jre` (portable, no root needed). If you'd
rather use the system package instead of the ~200 MB bundled runtime, remove
the `jre/` folder and:

```bash
sudo apt update && sudo apt install -y openjdk-21-jre-headless
java -version   # must report 21
```

## 2. Start the server

**Option A — systemd (recommended, survives reboots/SSH disconnects):**

```bash
sudo nano /etc/systemd/system/minecraft.service   # fix paths if not /opt/minecraft-server
sudo cp minecraft.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now minecraft
journalctl -u minecraft -f      # watch it boot
```

**Option B — tmux (quick manual run):**

```bash
tmux new -s mc ./start.sh       # detach with Ctrl+B then D
./stop.sh                       # graceful save & stop
```

Note: under systemd the server has **no console input**, so you can't type `/op player` etc.
To run server commands (op, whitelist, give…) either enable RCON (`enable-rcon=true` +
`rcon.password=…` in `server.properties`, then use an RCON client like `mcrcon`), or use
the tmux method below.

First boot takes a minute. Success looks like:

```
[Server thread/INFO]: Done (6.531s)! For help, type "help"
```

## 3. Point your Cloudflare Tunnel at it (mc.walawe.fun)

Your tunnel is already running on the VPS. Add one TCP route to it.

**In the dashboard** (easiest — works for dashboard-managed tunnels):
1. Go to **Cloudflare dashboard → Networking → Tunnels** and click your tunnel.
2. **Routes → Add route → Published application**.
3. Set:
   - **Hostname**: `mc` + select `walawe.fun`  → `mc.walawe.fun`
   - **Service type / URL**: `tcp://localhost:25565` (TCP, localhost:25565)
4. Save. Cloudflare auto-creates the proxied DNS record.

**Via config file** (if your tunnel uses a local `config.yml` instead of the
dashboard) — see `cloudflared-config-snippet.yml`, then:

```bash
cloudflared tunnel route dns YOUR_TUNNEL_NAME mc.walawe.fun
sudo systemctl restart cloudflared
```

Then from the VPS itself, verify the tunnel can reach the game port:

```bash
curl -s -m 5 http://localhost:25565/ | head -c 200   # returns binary "MC|" ping data
```

## 4. Players connect (this part matters!)

Cloudflare Tunnel does **not** forward raw TCP to normal game clients — it only
speaks to other `cloudflared` instances. So every player needs one of these:

**Per player — run once (then it stays open):**
```bash
cloudflared access tcp --hostname mc.walawe.fun --url localhost:25565
```
Then in Minecraft → Multiplayer → add server → address **`localhost:25565`**.

**Or — the nicer route for friends: the Modflared mod.**
Everyone installs [Modflared](https://modrinth.com/mod/modflared) (Fabric/Forge,
works with most launchers) plus a TXT DNS record so it auto-tunnels:

```
Type: TXT | Name: mc | Content: cloudflared-route=mc.walawe.fun
```
Then friends just type `mc.walawe.fun` in the server list — no terminal needed.

## 5. Notes & troubleshooting

- **Accounts**: `online-mode=true` means only paid accounts can join. If any
  player uses a cracked/TLauncher-style client, set `online-mode=false` **and**
  `enforce-secure-profile=false` in `server.properties`, then restart. (Only do
  this for a private friend server.)
- **Port**: nothing needs to be opened in the VPS firewall — cloudflared dials
  out to Cloudflare on port 7844 (your existing tunnel already proves egress
  works).
- **Restart after config edits**: `sudo systemctl restart minecraft` (or
  `./stop.sh` + `./start.sh`).
- **Backups**: stop the server (`sudo systemctl stop minecraft`) and copy the
  `world/` folder, or use a cron job that does `tar czf backups/world-$(date +%F).tar.gz world`.
- **Same-version clients only**: everyone must run **1.21.11** — newer clients
  can't join an older server.
- Server list shows "can't connect"? Confirm the route shows **Healthy** on the
  tunnel page, the game server is running, and the player's `cloudflared access
  tcp` session is still active.
