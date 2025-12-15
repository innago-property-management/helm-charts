# HashiCorp Vault Integration Guide

This guide covers integrating the WebApp Helm chart with HashiCorp Vault for secrets management using the [Bank-Vaults](https://github.com/bank-vaults/bank-vaults) webhook.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Basic Configuration](#basic-configuration)
- [Automatic Role Creation](#automatic-role-creation)
- [Common Patterns](#common-patterns)
- [Advanced Configuration](#advanced-configuration)
- [Troubleshooting](#troubleshooting)

## Overview

### How It Works

The Bank-Vaults mutating webhook intercepts pod creation and:
1. Detects `vault:` prefixed values in environment variables
2. Injects a `vault-env` init container
3. Authenticates to Vault using Kubernetes Service Account
4. Retrieves secrets from Vault paths
5. Replaces `vault:` references with actual secret values
6. Starts your application with decrypted secrets

### Benefits

- **No Vault SDK required** - Works with any application
- **Automatic secret rotation** - Pods get new secrets on restart
- **Kubernetes-native auth** - Uses ServiceAccount tokens
- **Least privilege** - Each app gets its own Vault role and policy

## Prerequisites

### 1. Vault Server

Vault must be running and accessible from your Kubernetes cluster:

```bash
# Verify Vault is accessible
kubectl run vault-test --rm -it --image=vault:1.15 \
  --command -- vault status -address=https://vault.vault.svc:8200
```

### 2. Bank-Vaults Webhook

The vault-secrets-webhook must be installed in your cluster:

```bash
# Check if webhook is running
kubectl get pods -n vault -l app.kubernetes.io/name=vault-secrets-webhook

# Expected output:
# NAME                                     READY   STATUS
# vault-secrets-webhook-xxxxx              1/1     Running
```

### 3. Kubernetes Auth Method

Vault's Kubernetes auth method must be enabled and configured:

```bash
# Enable Kubernetes auth (run once per Vault cluster)
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"
```

### 4. Vault Policies and Roles

Your application needs a Vault policy and role. See [Automatic Role Creation](#automatic-role-creation) for the automated approach.

## Quick Start

### Step 1: Create Vault Secrets

```bash
# Store database credentials
vault kv put secret/production/myapp/database \
  url="postgresql://user:pass@localhost/db" \
  username="appuser" \
  password="supersecret"

# Store API keys
vault kv put secret/production/myapp/api \
  key="your-api-key-here" \
  endpoint="https://api.example.com"
```

### Step 2: Configure Your App

```yaml
# values-vault.yaml
image:
  repository: myregistry.io/my-app
  tag: "1.0.0"

# Vault webhook annotations
podAnnotations:
  vault.security.banzaicloud.io/vault-addr: "https://vault.vault.svc:8200"
  vault.security.banzaicloud.io/vault-role: "myapp-production"
  vault.security.banzaicloud.io/vault-skip-verify: "false"

# Environment variables with Vault references
containerEnvironmentVariables:
  - name: DATABASE_URL
    value: vault:/secret/data/production/myapp/database#url
  - name: DATABASE_USERNAME
    value: vault:/secret/data/production/myapp/database#username
  - name: DATABASE_PASSWORD
    value: vault:/secret/data/production/myapp/database#password
  - name: API_KEY
    value: vault:/secret/data/production/myapp/api#key

# Automatic role creation (if using innago-vault-k8s-role-operator)
innagoVaultK8sRoleOperator:
  use: true
```

### Step 3: Deploy

```bash
helm install myapp ./webapp -f values-vault.yaml
```

The webhook will automatically inject secrets before your application starts.

## Basic Configuration

### Pod Annotations

Configure Vault webhook behavior using pod annotations:

```yaml
podAnnotations:
  # Required: Vault server address
  vault.security.banzaicloud.io/vault-addr: "https://vault.vault.svc:8200"

  # Required: Vault role for this application
  vault.security.banzaicloud.io/vault-role: "myapp-production"

  # Skip TLS verification (NOT recommended for production)
  vault.security.banzaicloud.io/vault-skip-verify: "false"

  # Custom Vault TLS CA certificate (optional)
  vault.security.banzaicloud.io/vault-tls-secret: "vault-tls"

  # Kubernetes auth mount path (optional, default: "kubernetes")
  vault.security.banzaicloud.io/vault-path: "kubernetes"

  # Enable Vault agent for token renewal (optional, usually not needed)
  vault.security.banzaicloud.io/vault-agent: "false"
```

### Vault Reference Syntax

Environment variable values can reference Vault secrets using this syntax:

```
vault:<path>#<key>
```

**Examples:**

```yaml
containerEnvironmentVariables:
  # KV v2 secret (most common)
  - name: PASSWORD
    value: vault:/secret/data/myapp/database#password

  # Multiple fields from same secret
  - name: DB_HOST
    value: vault:/secret/data/myapp/database#host
  - name: DB_PORT
    value: vault:/secret/data/myapp/database#port

  # Different environments
  - name: API_KEY_PROD
    value: vault:/secret/data/production/api#key
  - name: API_KEY_DEV
    value: vault:/secret/data/development/api#key
```

**Important:** For KV v2 secrets (default), the path includes `/data/` after the mount point:
- Vault path: `secret/myapp/database`
- Reference: `vault:/secret/data/myapp/database#password`

## Automatic Role Creation

### Using innago-vault-k8s-role-operator

The `innago-vault-k8s-role-operator` automatically creates Vault roles and policies based on your ServiceAccount:

```yaml
# Enable automatic role creation
innagoVaultK8sRoleOperator:
  use: true
```

**What it creates:**

1. **Vault Policy** - Named `<namespace>-<serviceaccount>`
   - Allows read access to `secret/data/<namespace>/<serviceaccount>/*`

2. **Vault Role** - Named `<namespace>-<serviceaccount>`
   - Bound to your ServiceAccount
   - Uses the policy created above

**Example:**

For release `myapp` in namespace `production`:
- Policy: `production-myapp`
- Role: `production-myapp`
- Secrets path: `secret/data/production/myapp/*`

### Additional Policies

For advanced use cases (dynamic database credentials, cross-namespace secrets):

```yaml
innagoVaultK8sRoleOperator:
  use: true
  additionalPolicies:
    - database-dynamic-credentials
    - shared-api-keys
```

Create these policies in Vault:

```hcl
# database-dynamic-credentials policy
path "database/creds/myapp-role" {
  capabilities = ["read"]
}

# shared-api-keys policy
path "secret/data/shared/api-keys/*" {
  capabilities = ["read"]
}
```

### Manual Role Creation

If not using the operator, create roles manually:

```bash
# 1. Create policy
vault policy write myapp-production - <<EOF
path "secret/data/production/myapp/*" {
  capabilities = ["read"]
}
EOF

# 2. Create role
vault write auth/kubernetes/role/myapp-production \
  bound_service_account_names=myapp \
  bound_service_account_namespaces=production \
  policies=myapp-production \
  ttl=24h
```

## Common Patterns

### Pattern 1: Database Credentials

**Vault setup:**

```bash
vault kv put secret/production/myapp/database \
  host="postgres.example.com" \
  port="5432" \
  database="myapp" \
  username="myapp_user" \
  password="$(openssl rand -base64 32)"
```

**Helm values:**

```yaml
containerEnvironmentVariables:
  - name: ConnectionStrings__DefaultConnection
    value: vault:/secret/data/production/myapp/database#url

# Alternative: Build connection string from parts
  - name: DB_HOST
    value: vault:/secret/data/production/myapp/database#host
  - name: DB_PORT
    value: vault:/secret/data/production/myapp/database#port
  - name: DB_NAME
    value: vault:/secret/data/production/myapp/database#database
  - name: DB_USER
    value: vault:/secret/data/production/myapp/database#username
  - name: DB_PASSWORD
    value: vault:/secret/data/production/myapp/database#password
```

### Pattern 2: API Keys and Tokens

**Vault setup:**

```bash
vault kv put secret/production/myapp/api \
  stripe_key="sk_live_EXAMPLE_REPLACE_ME" \
  sendgrid_key="SG.EXAMPLE_REPLACE_ME" \
  jwt_secret="$(openssl rand -base64 64)"
```

**Helm values:**

```yaml
containerEnvironmentVariables:
  - name: STRIPE_API_KEY
    value: vault:/secret/data/production/myapp/api#stripe_key
  - name: SENDGRID_API_KEY
    value: vault:/secret/data/production/myapp/api#sendgrid_key
  - name: JWT_SECRET
    value: vault:/secret/data/production/myapp/api#jwt_secret
```

### Pattern 3: Dynamic Database Credentials

Use Vault's database secrets engine for automatically rotated credentials:

**Vault setup:**

```bash
# Enable database secrets engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/myapp-db \
  plugin_name=postgresql-database-plugin \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/myapp" \
  allowed_roles="myapp-role" \
  username="vault" \
  password="vaultpass"

# Create role with TTL
vault write database/roles/myapp-role \
  db_name=myapp-db \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"
```

**Helm values:**

```yaml
# Additional policy for dynamic credentials
innagoVaultK8sRoleOperator:
  use: true
  additionalPolicies:
    - database-dynamic-credentials

# Use dynamic credentials
containerEnvironmentVariables:
  - name: DB_USERNAME
    value: vault:/database/creds/myapp-role#username
  - name: DB_PASSWORD
    value: vault:/database/creds/myapp-role#password
```

**Note:** Dynamic credentials are regenerated on each pod restart with a fresh TTL.

### Pattern 4: Multi-Environment Secrets

Use path conventions for environment separation:

**Vault structure:**

```
secret/
  development/
    myapp/
      database
      api
  staging/
    myapp/
      database
      api
  production/
    myapp/
      database
      api
```

**Helm values (parameterized by environment):**

```yaml
# values-template.yaml
containerEnvironmentVariables:
  - name: DATABASE_URL
    value: vault:/secret/data/{{ .Values.environment }}/myapp/database#url
  - name: API_KEY
    value: vault:/secret/data/{{ .Values.environment }}/myapp/api#key

# values-production.yaml
environment: production

# values-staging.yaml
environment: staging
```

### Pattern 5: Migration Job with Vault

Migrations need the same secrets as the main application:

```yaml
migrationJob:
  enabled: true
  image:
    repository: myregistry.io/myapp-migrations
    tag: "1.0.0"

  # Vault annotations (same as main app)
  annotations:
    vault.security.banzaicloud.io/vault-addr: "https://vault.vault.svc:8200"
    vault.security.banzaicloud.io/vault-role: "myapp-production"

  environmentVariables:
    - name: ConnectionStrings__DefaultConnection
      value: vault:/secret/data/production/myapp/database#url
```

## Advanced Configuration

### Custom ServiceAccount

Use a specific ServiceAccount for Vault authentication:

```yaml
serviceAccount:
  create: true
  name: myapp-vault-sa
  annotations:
    # AWS IRSA for cross-cloud Vault access (optional)
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/myapp-vault-role

podAnnotations:
  vault.security.banzaicloud.io/vault-role: "myapp-production"

# Vault role must be bound to this ServiceAccount
# vault write auth/kubernetes/role/myapp-production \
#   bound_service_account_names=myapp-vault-sa \
#   bound_service_account_namespaces=production
```

### Vault Agent for Token Renewal

For long-running pods that need token renewal:

```yaml
podAnnotations:
  vault.security.banzaicloud.io/vault-addr: "https://vault.vault.svc:8200"
  vault.security.banzaicloud.io/vault-role: "myapp-production"
  vault.security.banzaicloud.io/vault-agent: "true"  # Enable agent
  vault.security.banzaicloud.io/vault-agent-configmap: "vault-agent-config"
```

### Multiple Vault Instances

Reference secrets from different Vault clusters:

```yaml
podAnnotations:
  # Primary Vault
  vault.security.banzaicloud.io/vault-addr: "https://vault-primary.vault.svc:8200"
  vault.security.banzaicloud.io/vault-role: "myapp-production"

  # Secondary Vault (requires webhook configuration)
  vault.security.banzaicloud.io/vault-from-path: "vault-secondary:"

containerEnvironmentVariables:
  # From primary Vault
  - name: PRIMARY_SECRET
    value: vault:/secret/data/primary#key

  # From secondary Vault
  - name: SECONDARY_SECRET
    value: vault-secondary:/secret/data/secondary#key
```

### TLS Certificate Validation

For production Vault with custom CA:

```bash
# Create TLS secret with Vault CA certificate
kubectl create secret generic vault-tls \
  --from-file=ca.crt=/path/to/vault-ca.crt \
  --namespace=production
```

```yaml
podAnnotations:
  vault.security.banzaicloud.io/vault-addr: "https://vault.example.com:8200"
  vault.security.banzaicloud.io/vault-role: "myapp-production"
  vault.security.banzaicloud.io/vault-skip-verify: "false"  # Enforce TLS
  vault.security.banzaicloud.io/vault-tls-secret: "vault-tls"
```

## Troubleshooting

### Common Issues

#### 1. "Permission Denied" Errors

**Symptom:**
```
Error: failed to read secret: Error making API request.
URL: GET https://vault:8200/v1/secret/data/myapp/database
Code: 403. Errors: * permission denied
```

**Solutions:**

```bash
# Check if policy allows the path
vault policy read myapp-production

# Verify role configuration
vault read auth/kubernetes/role/myapp-production

# Test policy directly
vault token create -policy=myapp-production
vault login <token>
vault kv get secret/myapp/database
```

#### 2. "Role Not Found" Errors

**Symptom:**
```
Error: failed to login: Error making API request.
Code: 400. Errors: * role "myapp-production" not found
```

**Solutions:**

```bash
# List all Kubernetes roles
vault list auth/kubernetes/role

# Create the role if missing
vault write auth/kubernetes/role/myapp-production \
  bound_service_account_names=myapp \
  bound_service_account_namespaces=production \
  policies=myapp-production \
  ttl=24h
```

#### 3. "Connection Refused" to Vault

**Symptom:**
```
Error: failed to create Vault client: Get "https://vault:8200/v1/sys/health": dial tcp: lookup vault: no such host
```

**Solutions:**

```yaml
# Use full DNS name
podAnnotations:
  vault.security.banzaicloud.io/vault-addr: "https://vault.vault.svc.cluster.local:8200"

# Or use IP address (not recommended)
podAnnotations:
  vault.security.banzaicloud.io/vault-addr: "https://10.0.0.50:8200"
```

#### 4. KV v2 Path Issues

**Symptom:**
```
Error: secret not found at path "secret/myapp/database"
```

**Solution:**

KV v2 requires `/data/` in the path:

```yaml
# ❌ Wrong
containerEnvironmentVariables:
  - name: PASSWORD
    value: vault:/secret/myapp/database#password

# ✅ Correct
containerEnvironmentVariables:
  - name: PASSWORD
    value: vault:/secret/data/myapp/database#password
```

### Debugging Steps

#### 1. Check Pod Events

```bash
kubectl describe pod <pod-name> -n production

# Look for webhook injection events
# Events:
#   Type    Reason   Message
#   ----    ------   -------
#   Normal  Mutated  Mutating webhook "vault.banzaicloud.com" processed pod
```

#### 2. Inspect Vault-Env Init Container

```bash
# Check init container logs
kubectl logs <pod-name> -n production -c vault-env

# Look for authentication success
# Successfully authenticated to Vault
# Token created with policies: [myapp-production]
```

#### 3. Verify ServiceAccount Token

```bash
# Get ServiceAccount token
kubectl exec <pod-name> -n production -- cat /var/run/secrets/kubernetes.io/serviceaccount/token

# Test authentication manually
vault write auth/kubernetes/login \
  role=myapp-production \
  jwt=<token>
```

#### 4. Check Vault Audit Logs

```bash
# Enable audit logging (if not already enabled)
vault audit enable file file_path=/vault/logs/audit.log

# Watch for authentication attempts
tail -f /vault/logs/audit.log | grep myapp-production
```

### Getting Help

If issues persist:

1. **Check webhook logs:**
   ```bash
   kubectl logs -n vault -l app.kubernetes.io/name=vault-secrets-webhook
   ```

2. **Verify Vault health:**
   ```bash
   vault status -address=https://vault.vault.svc:8200
   ```

3. **Test minimal configuration:**
   ```yaml
   # Simplest possible config
   podAnnotations:
     vault.security.banzaicloud.io/vault-addr: "https://vault.vault.svc:8200"
     vault.security.banzaicloud.io/vault-role: "default"

   containerEnvironmentVariables:
     - name: TEST_SECRET
       value: vault:/secret/data/test#value
   ```

## Security Best Practices

1. **Never skip TLS verification in production:**
   ```yaml
   # ❌ Insecure
   vault.security.banzaicloud.io/vault-skip-verify: "true"

   # ✅ Secure
   vault.security.banzaicloud.io/vault-skip-verify: "false"
   vault.security.banzaicloud.io/vault-tls-secret: "vault-tls"
   ```

2. **Use least-privilege policies:**
   ```hcl
   # ✅ Good - specific path
   path "secret/data/production/myapp/*" {
     capabilities = ["read"]
   }

   # ❌ Bad - too broad
   path "secret/data/*" {
     capabilities = ["read", "list"]
   }
   ```

3. **Rotate secrets regularly:**
   ```bash
   # Use dynamic secrets when possible
   vault write database/roles/myapp-role \
     default_ttl="1h" \
     max_ttl="24h"
   ```

4. **Audit secret access:**
   ```bash
   vault audit enable file file_path=/vault/logs/audit.log
   ```

5. **Use namespaces for isolation:**
   ```bash
   # Production secrets
   vault kv put secret/production/myapp/database password=xxx

   # Staging secrets (separate data)
   vault kv put secret/staging/myapp/database password=yyy
   ```

## Additional Resources

- [Bank-Vaults Documentation](https://bank-vaults.dev/)
- [Vault Kubernetes Auth Method](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [Vault KV Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/kv)
- [Vault Database Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/databases)
- [Production Deployment Guide](./PRODUCTION.md) - General production best practices
