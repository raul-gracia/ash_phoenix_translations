#!/bin/bash
# Version management script for ash_phoenix_translations

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the current version from mix.exs
get_version() {
    grep -o 'version: "[^"]*"' mix.exs | cut -d'"' -f2
}

# Update version in mix.exs
update_mix_version() {
    local new_version=$1
    sed -i.bak "s/version: \"[^\"]*\"/version: \"$new_version\"/" mix.exs
    rm mix.exs.bak
    echo -e "${GREEN}✓${NC} Updated mix.exs to version $new_version"
}

# Update version in README.md
update_readme_version() {
    local new_version=$1
    # Update hex.pm badge
    sed -i.bak "s/{:ash_phoenix_translations, \"~> [^\"]*\"}/{:ash_phoenix_translations, \"~> $new_version\"/" README.md
    # Update installation instructions
    sed -i.bak "s/ash_phoenix_translations [0-9]\+\.[0-9]\+\.[0-9]\+/ash_phoenix_translations $new_version/g" README.md
    rm README.md.bak
    echo -e "${GREEN}✓${NC} Updated README.md to version $new_version"
}

# Update version in CHANGELOG.md
update_changelog() {
    local new_version=$1
    local date=$(date +%Y-%m-%d)
    
    if [ ! -f CHANGELOG.md ]; then
        echo "# Changelog" > CHANGELOG.md
        echo "" >> CHANGELOG.md
    fi
    
    # Check if version already exists
    if grep -q "## \[$new_version\]" CHANGELOG.md; then
        echo -e "${YELLOW}⚠${NC} Version $new_version already exists in CHANGELOG.md"
    else
        # Add new version section at the top (after the title)
        sed -i.bak "2a\\
\\
## [$new_version] - $date\\
\\
### Added\\
\\
### Changed\\
\\
### Fixed\\
\\
### Removed" CHANGELOG.md
        rm CHANGELOG.md.bak
        echo -e "${GREEN}✓${NC} Added version $new_version to CHANGELOG.md"
    fi
}

# Bump version based on semver
bump_version() {
    local version=$1
    local bump_type=$2
    
    IFS='.' read -r major minor patch <<< "$version"
    
    case $bump_type in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            echo -e "${RED}✗${NC} Invalid bump type: $bump_type (use major, minor, or patch)"
            exit 1
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# Sync versions across all files
sync_versions() {
    local version=$1
    update_mix_version "$version"
    update_readme_version "$version"
    update_changelog "$version"
}

# Main command handling
case "${1:-}" in
    get)
        current_version=$(get_version)
        echo "Current version: $current_version"
        ;;
    set)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}✗${NC} Version number required"
            echo "Usage: $0 set <version>"
            exit 1
        fi
        sync_versions "$2"
        echo -e "${GREEN}✓${NC} Version synchronized to $2"
        ;;
    bump)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}✗${NC} Bump type required"
            echo "Usage: $0 bump <major|minor|patch>"
            exit 1
        fi
        current_version=$(get_version)
        new_version=$(bump_version "$current_version" "$2")
        sync_versions "$new_version"
        echo -e "${GREEN}✓${NC} Version bumped from $current_version to $new_version"
        ;;
    sync)
        current_version=$(get_version)
        sync_versions "$current_version"
        echo -e "${GREEN}✓${NC} All files synchronized to version $current_version"
        ;;
    check)
        current_version=$(get_version)
        readme_version=$(grep -o '{:ash_phoenix_translations, "~> [^"]*"' README.md | head -1 | cut -d'"' -f2 | sed 's/~> //')
        
        echo "Checking version consistency..."
        echo "  mix.exs:   $current_version"
        echo "  README.md: $readme_version"
        
        if [ "$current_version" = "$readme_version" ]; then
            echo -e "${GREEN}✓${NC} Versions are synchronized"
        else
            echo -e "${YELLOW}⚠${NC} Version mismatch detected!"
            echo "Run '$0 sync' to synchronize versions"
            exit 1
        fi
        ;;
    *)
        echo "ash_phoenix_translations version management script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  get              Show current version from mix.exs"
        echo "  set <version>    Set specific version across all files"
        echo "  bump <type>      Bump version (major|minor|patch)"
        echo "  sync             Synchronize version from mix.exs to all files"
        echo "  check            Check version consistency across files"
        echo ""
        echo "Examples:"
        echo "  $0 get"
        echo "  $0 set 1.0.0"
        echo "  $0 bump patch"
        echo "  $0 sync"
        echo "  $0 check"
        ;;
esac