# Kubernetes yq & jq Exercises

> **Prerequisites:** Complete Day 6 of `terminal-exercises.md` first — this file assumes you know `jq` filters, `select()`, `map()`, and basic `yq` usage.
>
> **Tools needed:** `yq` (v4.x mikefarah), `jq`, `bat`, `rg`
> ```zsh
> yq --version   # v4.x
> jq --version   # 1.6+
> ```

---

## Sample manifests

Create the sample files once and reuse them throughout:

```zsh
mkdir -p ~/data/k8s

# deployment.yaml — a realistic Deployment
cat > ~/data/k8s/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: production
  labels:
    app: api
    version: "2.4.1"
    team: platform
  annotations:
    deploy-time: "2024-01-15T10:00:00Z"
    owner: platform-team
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: myorg/api:2.4.1
          ports:
            - containerPort: 8080
          env:
            - name: LOG_LEVEL
              value: info
            - name: DB_HOST
              value: postgres.internal
            - name: MAX_CONNECTIONS
              value: "100"
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
        - name: sidecar
          image: myorg/metrics:1.0.2
          ports:
            - containerPort: 9090
          resources:
            requests:
              cpu: "50m"
              memory: "64Mi"
            limits:
              cpu: "200m"
              memory: "128Mi"
EOF

# service.yaml — a Service resource
cat > ~/data/k8s/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: api-server
  namespace: production
  labels:
    app: api
spec:
  selector:
    app: api
  ports:
    - name: http
      port: 80
      targetPort: 8080
    - name: metrics
      port: 9090
      targetPort: 9090
  type: ClusterIP
EOF

# multi.yaml — multiple resources in one file (common in Helm output)
cat > ~/data/k8s/multi.yaml <<'EOF'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: staging
  labels:
    app: frontend
    version: "1.2.0"
spec:
  replicas: 2
  template:
    spec:
      containers:
        - name: frontend
          image: myorg/frontend:1.2.0
          env:
            - name: API_URL
              value: http://api-server
            - name: LOG_LEVEL
              value: info
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker
  namespace: staging
  labels:
    app: worker
    version: "1.2.0"
spec:
  replicas: 1
  template:
    spec:
      containers:
        - name: worker
          image: myorg/worker:1.2.0
          env:
            - name: QUEUE_URL
              value: redis://redis:6379
            - name: LOG_LEVEL
              value: warn
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: staging
data:
  config.json: |
    {"feature_flags": {"dark_mode": true, "beta": false}}
  log_level: info
EOF
```

**Exercise:** Run `bat ~/data/k8s/deployment.yaml` and `bat ~/data/k8s/multi.yaml`. Notice the `---` separators in multi.yaml — yq treats each as a separate document.

---

## K1 — Querying a Single Manifest

```zsh
# Basic field extraction
yq '.metadata.name' ~/data/k8s/deployment.yaml
yq '.spec.replicas' ~/data/k8s/deployment.yaml

# All labels
yq '.metadata.labels' ~/data/k8s/deployment.yaml

# Specific label
yq '.metadata.labels.version' ~/data/k8s/deployment.yaml

# All container names
yq '.spec.template.spec.containers[].name' ~/data/k8s/deployment.yaml

# Specific container by index
yq '.spec.template.spec.containers[0].image' ~/data/k8s/deployment.yaml

# Specific container by name (select())
yq '.spec.template.spec.containers[] | select(.name == "api")' ~/data/k8s/deployment.yaml
yq '.spec.template.spec.containers[] | select(.name == "api") | .image' ~/data/k8s/deployment.yaml

# All env vars for the api container
yq '.spec.template.spec.containers[] | select(.name == "api") | .env[]' ~/data/k8s/deployment.yaml

# Specific env var value
yq '.spec.template.spec.containers[] |
    select(.name == "api") |
    .env[] | select(.name == "LOG_LEVEL") | .value' ~/data/k8s/deployment.yaml

# Resource limits
yq '.spec.template.spec.containers[] | select(.name == "api") | .resources.limits' \
    ~/data/k8s/deployment.yaml

# All port numbers
yq '.spec.template.spec.containers[].ports[].containerPort' ~/data/k8s/deployment.yaml
```

**Exercise:** From `deployment.yaml`, print the readiness probe path and port for the `api` container.

---

## K2 — Querying Multi-Resource Files

```zsh
# All document kinds
yq '.kind' ~/data/k8s/multi.yaml

# All resource names
yq '.metadata.name' ~/data/k8s/multi.yaml

# Select only Deployments
yq 'select(.kind == "Deployment")' ~/data/k8s/multi.yaml

# All Deployment names
yq 'select(.kind == "Deployment") | .metadata.name' ~/data/k8s/multi.yaml

# Select by name
yq 'select(.metadata.name == "worker")' ~/data/k8s/multi.yaml

# All images across all Deployments
yq 'select(.kind == "Deployment") |
    .spec.template.spec.containers[].image' ~/data/k8s/multi.yaml

# Env vars for a specific deployment
yq 'select(.metadata.name == "frontend") |
    .spec.template.spec.containers[0].env[]' ~/data/k8s/multi.yaml

# ConfigMap data keys
yq 'select(.kind == "ConfigMap") | .data | keys' ~/data/k8s/multi.yaml

# Summary: name + kind + replica count (null for non-Deployments)
yq '{name: .metadata.name, kind: .kind, replicas: .spec.replicas}' ~/data/k8s/multi.yaml
```

**Exercise:** List every image used across all Deployments in `multi.yaml`, one per line (raw output, no quotes).

---

## K3 — Patching Manifests In-Place

`yq -i` rewrites the file cleanly. In multi-doc files, use `select()` to scope changes to specific resources.

```zsh
# Always work on a copy
cp ~/data/k8s/deployment.yaml /tmp/deploy-patch.yaml

# Scale replicas
yq -i '.spec.replicas = 5' /tmp/deploy-patch.yaml
yq '.spec.replicas' /tmp/deploy-patch.yaml            # verify

# Update a label
yq -i '.metadata.labels.version = "2.5.0"' /tmp/deploy-patch.yaml

# Add an annotation
yq -i '.metadata.annotations.reviewed-by = "ci-bot"' /tmp/deploy-patch.yaml

# Update an env var value (using update operator |=)
yq -i '(.spec.template.spec.containers[] | select(.name == "api") |
        .env[] | select(.name == "LOG_LEVEL")).value = "debug"' /tmp/deploy-patch.yaml

# Add a new env var to a specific container
yq -i '.spec.template.spec.containers[] |= (select(.name == "api") |=
        .env += [{"name": "ENVIRONMENT", "value": "staging"}])' /tmp/deploy-patch.yaml

# Update resource limit
yq -i '(.spec.template.spec.containers[] | select(.name == "api") |
        .resources.limits.cpu) = "2000m"' /tmp/deploy-patch.yaml

# Delete an annotation
yq -i 'del(.metadata.annotations.deploy-time)' /tmp/deploy-patch.yaml

# See all changes at once
diff ~/data/k8s/deployment.yaml /tmp/deploy-patch.yaml
```

**Exercise:** On a copy of `deployment.yaml`: bump replicas to 4, set `LOG_LEVEL=warn` for the api container, add annotation `patched-by: ops-team`, and increase the api container memory limit to `2Gi`.

---

## K4 — Bumping Image Tags

Image tag updates are one of the most common CI/CD automation tasks. The `|=` operator reads and rewrites the current value.

```zsh
cp ~/data/k8s/deployment.yaml /tmp/deploy-bump.yaml

# Bump one container's image
yq -i '(.spec.template.spec.containers[] | select(.name == "api") | .image) =
        "myorg/api:2.5.0"' /tmp/deploy-bump.yaml

# Bump all containers to a new tag using sub() — replaces the tag portion
yq -i '.spec.template.spec.containers[].image |= sub(":.*$"; ":3.0.0")' /tmp/deploy-bump.yaml

# Verify
yq '.spec.template.spec.containers[].image' /tmp/deploy-bump.yaml

# Bump all images in a multi-resource file (scoped to Deployments)
cp ~/data/k8s/multi.yaml /tmp/multi-bump.yaml
yq -i '(select(.kind == "Deployment") |
        .spec.template.spec.containers[].image) |= sub(":.*$"; ":2.0.0")' /tmp/multi-bump.yaml
yq 'select(.kind == "Deployment") | .spec.template.spec.containers[].image' /tmp/multi-bump.yaml

# Use a shell variable for the tag
NEW_TAG="2.6.0"
yq -i --arg tag "$NEW_TAG" \
    '(.spec.template.spec.containers[] | select(.name == "api") | .image) |=
     sub(":.*$"; ":" + $tag)' /tmp/deploy-bump.yaml
```

**Exercise:** Bump all images in `multi.yaml` that belong to `myorg/*` to tag `1.3.0` without touching images from other registries.

---

## K5 — Auditing with yq + jq

Convert to JSON first (`yq -o=json`), then use the full power of `jq`'s aggregation functions.

```zsh
# List all images with their deployment name (multi.yaml)
yq -o=json '[.]' ~/data/k8s/multi.yaml | jq -r '
  .[] | select(.kind == "Deployment") |
  .metadata.name as $name |
  .spec.template.spec.containers[] |
  "\($name): \(.image)"'

# Check which containers are missing resource limits
yq -o=json '.' ~/data/k8s/deployment.yaml | jq '
  .spec.template.spec.containers[] |
  {name, has_limits: (.resources.limits != null)}'

# Audit env vars across all deployments in multi.yaml
yq -o=json '[.]' ~/data/k8s/multi.yaml | jq -r '
  .[] | select(.kind == "Deployment") |
  .metadata.name as $deploy |
  .spec.template.spec.containers[] |
  .env[]? |
  "\($deploy) | \(.name)=\(.value)"'

# Find all deployments with LOG_LEVEL not set to "warn" or "error"
yq -o=json '[.]' ~/data/k8s/multi.yaml | jq -r '
  .[] | select(.kind == "Deployment") |
  .metadata.name as $name |
  .spec.template.spec.containers[].env[]? |
  select(.name == "LOG_LEVEL" and (.value != "warn" and .value != "error")) |
  "\($name): LOG_LEVEL=\(.value) — consider raising"'

# Summarise all Deployments: name, replicas, image list
yq -o=json '[.]' ~/data/k8s/multi.yaml | jq '
  [.[] | select(.kind == "Deployment") | {
    name: .metadata.name,
    replicas: .spec.replicas,
    images: [.spec.template.spec.containers[].image]
  }]'
```

**Exercise:** Across `multi.yaml`, find all containers that do not define any resource requests. Print `deployment/container` pairs.

---

## K6 — Generating Shell Exports from Manifests

A common ops pattern: extract env vars from a manifest and source them locally for debugging.

```zsh
# Extract env vars from a deployment as shell exports
yq -o=json '.spec.template.spec.containers[] | select(.name == "api") | .env[]' \
    ~/data/k8s/deployment.yaml | \
    jq -r '"export " + .name + "=" + .value'

# Write to a file and source it
yq -o=json '.spec.template.spec.containers[] | select(.name == "api") | .env[]' \
    ~/data/k8s/deployment.yaml | \
    jq -r '"export " + .name + "=" + .value' > /tmp/api-env.sh

cat /tmp/api-env.sh
source /tmp/api-env.sh
echo $LOG_LEVEL       # should print: info

# Extract ConfigMap data as exports (multi.yaml)
yq -o=json 'select(.kind == "ConfigMap") | .data' ~/data/k8s/multi.yaml | \
    jq -r 'to_entries[] | select(.value | type == "string" and (contains("\n") | not)) |
           "export " + (.key | ascii_upcase) + "=" + .value'

# Generate a .env file (no 'export' prefix — for docker run --env-file)
yq -o=json '.spec.template.spec.containers[] | select(.name == "api") | .env[]' \
    ~/data/k8s/deployment.yaml | \
    jq -r '.name + "=" + .value' > /tmp/api.env

cat /tmp/api.env
```

**Exercise:** Extract every env var from every container in `multi.yaml`'s Deployments. Write them all to `/tmp/all-env.sh` as `export` lines, prefixed with the deployment name (e.g. `export FRONTEND_LOG_LEVEL=info`).

---

## K7 — Format Conversion for kubectl and CI

```zsh
# Apply a modified manifest without saving to disk (process substitution)
# (prints what would be applied — remove the echo to actually apply)
echo "kubectl apply -f -" '<' "<(yq '.' ~/data/k8s/deployment.yaml)"

# Convert to JSON for kubectl (some tools prefer JSON)
yq -o=json '.' ~/data/k8s/deployment.yaml > /tmp/deployment.json
bat /tmp/deployment.json

# Validate: confirm replicas > 0
yq '.spec.replicas > 0' ~/data/k8s/deployment.yaml    # true/false

# Validate: all containers have resource limits defined
yq -o=json '.' ~/data/k8s/deployment.yaml | \
    jq 'all(.spec.template.spec.containers[]; .resources.limits != null)'

# Generate a Markdown summary table of all resources in multi.yaml
yq -o=json '[.]' ~/data/k8s/multi.yaml | \
    jq -r '["Kind","Name","Namespace"], (.[] | [.kind, .metadata.name, .metadata.namespace]) | @tsv' | \
    column -t -s $'\t'

# Extract all image references for a container scan (e.g. Trivy input)
yq -o=json '[.]' ~/data/k8s/multi.yaml | \
    jq -r '.[] | select(.kind == "Deployment") |
           .spec.template.spec.containers[].image' | sort -u

# Diff two versions of a manifest
# (simulate: bump one field in a copy, then diff the YAML)
cp ~/data/k8s/deployment.yaml /tmp/deploy-v2.yaml
yq -i '.spec.replicas = 10' /tmp/deploy-v2.yaml
diff <(yq '.' ~/data/k8s/deployment.yaml) <(yq '.' /tmp/deploy-v2.yaml)
```

**Exercise:** From `multi.yaml`, extract all unique image names (no duplicates, no tags — just `registry/name`) and write them to `/tmp/images.txt`, one per line.

---

## Kubernetes Checkpoint

- [ ] Extracted nested values from a Deployment (container image, env var, resource limits)
- [ ] Filtered resources in a multi-doc file with `select(.kind == "...")`
- [ ] Bumped image tags with `|= sub(":.*$"; ":new-tag")` across all containers
- [ ] Added and removed env vars from a specific container in-place
- [ ] Piped `yq -o=json` into `jq` for multi-deployment audits
- [ ] Generated a shell env file from a Deployment's env section
- [ ] Built a Markdown resource summary table from a multi-resource YAML

---

## yq Kubernetes Patterns Quick Reference

| Task | Command |
|------|---------|
| Get replicas | `yq '.spec.replicas' deploy.yaml` |
| Get container image | `yq '.spec.template.spec.containers[] \| select(.name=="X") \| .image' deploy.yaml` |
| Get env var value | `yq '... \| .env[] \| select(.name=="X") \| .value' deploy.yaml` |
| Set replicas | `yq -i '.spec.replicas = N' deploy.yaml` |
| Set env var | `yq -i '(...env[] \| select(.name=="X")).value = "Y"' deploy.yaml` |
| Add env var | `yq -i '(.spec.template.spec.containers[0].env) += [{"name":"X","value":"Y"}]' deploy.yaml` |
| Bump image tag | `yq -i '.spec.template.spec.containers[].image \|= sub(":.*$"; ":TAG")' deploy.yaml` |
| Add annotation | `yq -i '.metadata.annotations.key = "val"' deploy.yaml` |
| Delete field | `yq -i 'del(.metadata.annotations.key)' deploy.yaml` |
| Select by kind | `yq 'select(.kind == "Deployment")' multi.yaml` |
| List all images | `yq '.spec.template.spec.containers[].image' deploy.yaml` |
| YAML → JSON | `yq -o=json '.' deploy.yaml` |
| Multi-doc → JSON array | `yq -o=json '[.]' multi.yaml` |
| Validate field exists | `yq '.spec.replicas != null' deploy.yaml` |
