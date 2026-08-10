# Step 6–7 — Telegram & Discord

## Telegram

1. Talk to [@BotFather](https://t.me/BotFather) → `/newbot` → token.
2. Get your user ID via [@userinfobot](https://t.me/userinfobot).
3. `config/.env`: `TELEGRAM_BOT_TOKEN=123:ABC`
4. `config/openclaw.yaml`:

```yaml
channels:
  telegram:
    enabled: true
    allowFrom: ["123456789"]  # your ID only
    allowGroups: []           # DM only first
```

5. `sudo systemctl restart openclaw-gateway && journalctl -u openclaw-gateway -f`
6. DM the bot: `/start` → should reply.

## Discord

1. https://discord.com/developers → New Application → Bot → token → invite to **one private test guild**.
2. `.env`: `DISCORD_BOT_TOKEN=...`
3. `config/openclaw.yaml`:

```yaml
channels:
  discord:
    enabled: true
    allowGuilds: ["<TEST_GUILD_ID>"]
```

Guild ID: Discord → Settings → Advanced → Developer Mode → right-click server → Copy ID.

Keep scopes minimal — one guild until hardened.

Next: [Gmail](07-channels-gmail.md)
