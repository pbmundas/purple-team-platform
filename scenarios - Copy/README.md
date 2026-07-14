# Authorized lab exercises

Run only against `linux-victim` in this isolated Docker lab.

```sh
docker compose exec kali nmap -sV linux-victim
docker compose exec kali sh -c 'for p in 80 22 443; do nc -zv linux-victim $p; done'
```

Review Suricata data in Wazuh Discover with `data.location:/var/log/suricata/eve.json`.
