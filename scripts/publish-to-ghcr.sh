#!/bin/bash
set -e

# Script to build and publish crossplane-provider-sql to GitHub Container Registry (GHCR)
# Usage: ./scripts/publish-to-ghcr.sh [VERSION] [REGISTRY]

echo "================================================"
echo "Crossplane Provider SQL - GHCR Publishing Script"
echo "================================================"
echo ""

# Configuration
GITHUB_ORG="${GITHUB_ORG:-kyosenergy-engineering}"
REGISTRY="${1:-ghcr.io/${GITHUB_ORG}}"
PACKAGE_NAME="provider-sql"
PLATFORMS="${PLATFORMS:-linux_amd64}"

echo "Configuration:"
echo "  Registry: ${REGISTRY}"
echo "  Package: ${PACKAGE_NAME}"
echo "  Platforms: ${PLATFORMS}"
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "Error: docker is not installed or not in PATH"
    exit 1
fi
echo "  ✓ Docker found"

if ! command -v make &> /dev/null; then
    echo "Error: make is not installed or not in PATH"
    exit 1
fi
echo "  ✓ Make found"

if ! command -v up &> /dev/null; then
    echo "Warning: 'up' CLI not found. Installing via make..."
    make build.init
fi

# Check if up is available after potential installation
if ! command -v up &> /dev/null && ! [ -f ".work/tools/$(uname -s)_$(uname -m)/up" ]; then
    echo "Error: Crossplane CLI 'up' is not available"
    echo "Please install it manually: curl -sL 'https://cli.upbound.io' | sh"
    exit 1
fi
echo "  ✓ Crossplane CLI (up) found"

# Check Docker login
if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running"
    exit 1
fi
echo "  ✓ Docker daemon running"

echo ""
echo "Checking GHCR authentication..."
if ! docker pull ghcr.io/crossplane/crossplane:latest &> /dev/null; then
    echo "Warning: May not be authenticated to GHCR"
    echo ""
    echo "To authenticate, run:"
    echo "  echo \$GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "  ✓ GHCR authentication working"
fi

echo ""
echo "Building the provider package..."
echo "This may take several minutes..."
echo ""

# Export registry settings
export XPKG_REG_ORGS="${REGISTRY}"
export XPKG_REG_ORGS_NO_PROMOTE="${REGISTRY}"

# Build
if make build.all; then
    echo ""
    echo "  ✓ Build successful"
else
    echo ""
    echo "Error: Build failed"
    exit 1
fi

echo ""
echo "Looking for built packages..."

# Find the package file(s) that were actually built
PACKAGE_FILES=()
VERSION=""
for platform in ${PLATFORMS}; do
    # Find any .xpkg files in the platform directory
    pkg_file=$(find "_output/xpkg/${platform}" -name "${PACKAGE_NAME}-*.xpkg" 2>/dev/null | head -1)
    if [ -n "${pkg_file}" ] && [ -f "${pkg_file}" ]; then
        PACKAGE_FILES+=("--package ${pkg_file}")
        echo "  ✓ Found: ${pkg_file}"
        
        # Extract version from the first package file found
        if [ -z "${VERSION}" ]; then
            VERSION=$(basename "${pkg_file}" | sed "s/${PACKAGE_NAME}-\(.*\)\.xpkg/\1/")
            echo "  ℹ Detected version: ${VERSION}"
        fi
    else
        echo "  ⚠ No package found in _output/xpkg/${platform}/"
    fi
done

if [ ${#PACKAGE_FILES[@]} -eq 0 ]; then
    echo ""
    echo "Error: No package files found in _output/xpkg/"
    echo "Build may have failed or packages are in an unexpected location."
    echo ""
    echo "Searched for: _output/xpkg/<platform>/${PACKAGE_NAME}-*.xpkg"
    exit 1
fi

echo ""
echo "Pushing package to ${REGISTRY}/${PACKAGE_NAME}:${VERSION}..."

# Determine which up command to use
UP_CMD="up"
if ! command -v up &> /dev/null; then
    UP_CMD=".work/tools/$(uname -s)_$(uname -m)/up"
fi

# Push the package
if ${UP_CMD} xpkg push ${PACKAGE_FILES[@]} ${REGISTRY}/${PACKAGE_NAME}:${VERSION}; then
    echo ""
    echo "  ✓ Package pushed successfully!"
else
    echo ""
    echo "Error: Failed to push package"
    exit 1
fi

echo ""
echo "================================================"
echo "Success! Package published to:"
echo "  ${REGISTRY}/${PACKAGE_NAME}:${VERSION}"
echo ""
echo "To use this package in Crossplane:"
echo ""
echo "  apiVersion: pkg.crossplane.io/v1"
echo "  kind: Provider"
echo "  metadata:"
echo "    name: provider-sql"
echo "  spec:"
echo "    package: ${REGISTRY}/${PACKAGE_NAME}:${VERSION}"
echo ""
echo "To tag as 'latest':"
echo "  ${UP_CMD} xpkg push \\"
echo "    ${PACKAGE_FILES[0]##--package } \\"
echo "    ${REGISTRY}/${PACKAGE_NAME}:latest"
echo ""
echo "View your package at:"
echo "  https://github.com/orgs/${GITHUB_ORG}/packages"
echo "================================================"
