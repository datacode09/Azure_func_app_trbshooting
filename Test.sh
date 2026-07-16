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
