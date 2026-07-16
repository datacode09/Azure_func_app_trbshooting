# 1. Does the app have VNet integration configured at all?
az functionapp vnet-integration list \
  --resource-group az-rg-hodsai-dev-cae-001 \
  --name az-func-hodsai-dev-cae-002 \
  -o table

# 2. Is vnetRouteAllEnabled true? (without this, only some traffic routes through the VNet)
az functionapp config show \
  --resource-group az-rg-hodsai-dev-cae-001 \
  --name az-func-hodsai-dev-cae-002 \
  --query "vnetRouteAllEnabled"

# 3. WEBSITE_CONTENTOVERVNET app setting (needed for content/deployment storage traffic to route over VNet)
az functionapp config appsettings list \
  --resource-group az-rg-hodsai-dev-cae-001 \
  --name az-func-hodsai-dev-cae-002 \
  --query "[?name=='WEBSITE_CONTENTOVERVNET']"
There it is: **`vnetRouteAllEnabled: false`**.

That's almost certainly your root cause. Without this set to `true`, the app only routes RFC1918 private-range traffic through the VNet integration by default — it does *not* force all outbound traffic (including the Kudu deployment engine's calls to the storage account) through that subnet. So the Kudu process falls back to public DNS resolution for `azsthodsaidevcae004.blob.core.windows.net`, finds no public record for it (since it only exists in the private zone), and throws exactly the "Name or service not known" error you're seeing.

Fix:

```bash
az functionapp config set \
  --resource-group az-rg-hodsai-dev-cae-001 \
  --name az-func-hodsai-dev-cae-002 \
  --vnet-route-all-enabled true
```

Then check `WEBSITE_CONTENTOVERVNET` too while you're at it — on Flex Consumption it's often not required (Flex handles content storage differently than classic Consumption), but it's worth confirming it isn't set to something that conflicts:

```bash
az functionapp config appsettings list \
  --resource-group az-rg-hodsai-dev-cae-001 \
  --name az-func-hodsai-dev-cae-002 \
  --query "[?name=='WEBSITE_CONTENTOVERVNET']"
```

After setting `vnetRouteAllEnabled` to `true`, give it a minute or two to propagate, then retry the zip deployment:

```bash
az functionapp deployment source config-zip \
  --resource-group az-rg-hodsai-dev-cae-001 \
  --name az-func-hodsai-dev-cae-002 \
  --src HODS-Deployment.zip
```

This is a good, clean find — a single boolean flag explaining a multi-layer DNS mystery. Want me to help draft the note back to Azure Admin/the team documenting this as the root cause, in case others hit it too?
Good — that confirms `WEBSITE_CONTENTOVERVNET` is already set to `"1"` (enabled), so that setting isn't the gap either. That's one more thing ruled out, not a new lead.

Since #1 (forcing the DNS server) hasn't been tried yet, that's the next move — go straight to it:

```bash
az functionapp config appsettings set \
  --resource-group az-rg-hodsai-dev-cae-001 \
  --name az-func-hodsai-dev-cae-002 \
  --settings WEBSITE_DNS_SERVER=168.63.129.16

az functionapp restart \
  --name az-func-hodsai-dev-cae-002 \
  --resource-group az-rg-hodsai-dev-cae-001
```

Wait about 60 seconds after the restart (Flex Consumption cold-start can take a moment to fully cycle), then retry:

```bash
az functionapp deployment source config-zip \
  --resource-group az-rg-hodsai-dev-cae-001 \
  --name az-func-hodsai-dev-cae-002 \
  --src HODS-Deployment.zip
```

If this still fails with the identical error, don't burn more time on config tweaks — go straight to fix **#3** (upload the zip yourself via `az storage blob upload` + SAS URL + `WEBSITE_RUN_FROM_PACKAGE`). That one doesn't depend on Kudu's storage check working at all, so it's the most likely to actually get you deployed today regardless of what's broken underneath. Want the exact commands for that queued up now in case `WEBSITE_DNS_SERVER` doesn't do it?
