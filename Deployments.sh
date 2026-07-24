az functionapp deployment source config-zip \
  --resource-group az-rg-hodsai-dev-cae-001 \
  --name az-func-hodsai-dev-cae-002 \
  --src ~/HODS-Deployment.zip \
  --build-remote true
