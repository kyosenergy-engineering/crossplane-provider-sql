# Publishing Crossplane Provider SQL to GitHub Container Registry (GHCR)

This guide explains how to build and publish this Crossplane provider package to your GitHub Container Registry (ghcr.io) for testing purposes.

## Prerequisites

1. **Docker** - Ensure Docker is installed and running
2. **Crossplane CLI (`up`)** - Required for building and pushing xpkg packages
3. **GitHub Personal Access Token (PAT)** with `write:packages` and `read:packages` permissions
4. **Make** and **Go 1.18+** installed

## Step 1: Install the Crossplane CLI

If you don't have the Crossplane CLI (`up`) installed, you can install it:

```bash
# Install via the official script
curl -sL "https://cli.upbound.io" | sh

# Or download directly from GitHub releases
# https://github.com/upbound/up/releases
```

Alternatively, the Makefile will download it for you when you run build commands.

## Step 2: Authenticate with GitHub Container Registry

Before pushing packages, authenticate Docker with GHCR:

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

Replace:
- `YOUR_GITHUB_USERNAME` with your GitHub username
- `$GITHUB_TOKEN` should contain your GitHub Personal Access Token

## Step 3: Update the Registry Configuration

You need to override the default registry settings to point to your GHCR. You can do this by setting environment variables:

```bash
# Set your organization/username
export XPKG_REG_ORGS="ghcr.io/kyosenergy-engineering"
export XPKG_REG_ORGS_NO_PROMOTE="ghcr.io/kyosenergy-engineering"
```

Or you can modify the Makefile temporarily. In `Makefile`, update lines 50-53:

```makefile
# Change from:
XPKG_REG_ORGS ?= xpkg.upbound.io/crossplane-contrib
XPKG_REG_ORGS_NO_PROMOTE ?= xpkg.upbound.io/crossplane-contrib

# To:
XPKG_REG_ORGS ?= ghcr.io/kyosenergy-engineering
XPKG_REG_ORGS_NO_PROMOTE ?= ghcr.io/kyosenergy-engineering
```

## Step 4: Build the Package

Build the provider package for your platform:

```bash
# Build for all supported platforms (recommended)
make build.all
```

**Note:** You must run `make build.all` (not just `make build`) to properly build the provider binaries, Docker images, and Crossplane packages.

This will:
1. Build the Go binaries
2. Build the Docker images
3. Create the Crossplane package (.xpkg file)

The package will be created in `_output/xpkg/<platform>/provider-sql-<VERSION>.xpkg`

## Step 5: Push the Package to GHCR

Now you can push the package to GHCR manually:

```bash
# Set the version you want to publish (or use the auto-generated one)
export VERSION=$(make version)

# Push the package using the up CLI directly
up xpkg push \
  --package _output/xpkg/linux_amd64/provider-sql-${VERSION}.xpkg \
  ghcr.io/kyosenergy-engineering/provider-sql:${VERSION}
```

Or if you've updated the Makefile registry settings, you can use:

```bash
# This will publish to the registry specified in XPKG_REG_ORGS
make publish
```

## Step 6: Tag Additional Versions (Optional)

You might want to tag your package with additional tags like `latest` or custom tags:

```bash
# Tag as latest
docker buildx imagetools create \
  -t ghcr.io/kyosenergy-engineering/provider-sql:latest \
  ghcr.io/kyosenergy-engineering/provider-sql:${VERSION}

# Or use the up CLI
up xpkg push \
  --package _output/xpkg/linux_amd64/provider-sql-${VERSION}.xpkg \
  ghcr.io/kyosenergy-engineering/provider-sql:latest
```

## Step 7: Verify the Package

You can verify the package was pushed successfully:

```bash
# List packages in your GHCR
# Visit: https://github.com/orgs/kyosenergy-engineering/packages

# Or pull the package to test
up xpkg pull ghcr.io/kyosenergy-engineering/provider-sql:${VERSION}
```

## Step 8: Use the Package in Crossplane

To use your published package in a Crossplane installation:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-sql
spec:
  package: ghcr.io/kyosenergy-engineering/provider-sql:${VERSION}
```

Apply this to your Kubernetes cluster with Crossplane installed:

```bash
kubectl apply -f provider.yaml
```

## Quick Reference Commands

Here's a summary of commands for the full workflow:

```bash
# 1. Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# 2. Set registry (use env vars or edit Makefile)
export XPKG_REG_ORGS="ghcr.io/kyosenergy-engineering"
export XPKG_REG_ORGS_NO_PROMOTE="ghcr.io/kyosenergy-engineering"

# 3. Build everything
make build.all

# 4. Get the version
export VERSION=$(make version)

# 5. Push to GHCR
up xpkg push \
  --package _output/xpkg/linux_amd64/provider-sql-${VERSION}.xpkg \
  ghcr.io/kyosenergy-engineering/provider-sql:${VERSION}

# 6. (Optional) Tag as latest
up xpkg push \
  --package _output/xpkg/linux_amd64/provider-sql-${VERSION}.xpkg \
  ghcr.io/kyosenergy-engineering/provider-sql:latest
```

## Multi-Platform Builds (Advanced)

If you need to build for multiple platforms (amd64 and arm64):

```bash
# Build all platforms
make build.all

# Push multi-platform package
up xpkg push \
  --package _output/xpkg/linux_amd64/provider-sql-${VERSION}.xpkg \
  --package _output/xpkg/linux_arm64/provider-sql-${VERSION}.xpkg \
  ghcr.io/kyosenergy-engineering/provider-sql:${VERSION}
```

## Troubleshooting

### Issue: `up` command not found
- Install the Crossplane CLI as described in Step 1, or let Make download it: `make build.init`

### Issue: Authentication failed
- Ensure your GitHub token has `write:packages` and `read:packages` permissions
- Re-run the docker login command

### Issue: Package not visible in GHCR
- Check if the package visibility is set to public in GitHub package settings
- Visit: https://github.com/orgs/kyosenergy-engineering/packages

### Issue: Build fails
- Ensure you've initialized submodules: `make submodules`
- Clean and rebuild: `make clean && make build`

## Notes

- The package will be private by default in GHCR. You can change visibility in the GitHub web UI under Package Settings.
- Make sure your organization/repository has permissions configured correctly for package publishing.
- The default build creates packages for `linux_amd64` and `linux_arm64` platforms.
- Version is auto-generated based on git tags and commits. You can override with `VERSION=v1.0.0-custom make build`.

## References

- [Crossplane Package Documentation](https://docs.crossplane.io/latest/concepts/packages/)
- [GitHub Container Registry Documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Upbound CLI Documentation](https://docs.upbound.io/cli/)
