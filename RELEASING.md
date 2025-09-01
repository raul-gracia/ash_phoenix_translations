# Release Process

This document describes the release process for ash_phoenix_translations.

## Table of Contents

- [Overview](#overview)
- [Release Types](#release-types)
- [Pre-Release Process](#pre-release-process)
- [Production Release Process](#production-release-process)
- [Version Management](#version-management)
- [Changelog Management](#changelog-management)
- [Troubleshooting](#troubleshooting)

## Overview

The release process is largely automated through GitHub Actions workflows. There are three main workflows:

1. **CI Workflow** (`ci.yml`) - Runs on every push and PR, ensures code quality
2. **Pre-Release Workflow** (`prerelease.yml`) - Creates alpha/beta/rc releases for testing
3. **Release Workflow** (`release.yml`) - Creates production releases and publishes to Hex

## Release Types

### Production Releases

Production releases follow semantic versioning (MAJOR.MINOR.PATCH):

- **Major** (1.0.0 → 2.0.0): Breaking changes
- **Minor** (1.0.0 → 1.1.0): New features, backward compatible
- **Patch** (1.0.0 → 1.0.1): Bug fixes, backward compatible

### Pre-Releases

Pre-releases are for testing and validation:

- **Alpha** (1.0.0-alpha.1): Early testing, may be unstable
- **Beta** (1.0.0-beta.1): Feature complete, testing for bugs
- **RC** (1.0.0-rc.1): Release candidate, final testing

## Pre-Release Process

### Creating a Pre-Release

1. **Ensure CI is passing** on the main branch
2. **Go to Actions** → **Pre-Release workflow**
3. **Click "Run workflow"** and select:
   - Pre-release type (alpha/beta/rc)
   - Version increment (major/minor/patch)
4. **Workflow will automatically**:
   - Calculate the next pre-release version
   - Update version in all files
   - Run tests
   - Create a GitHub pre-release
   - Publish to Hex with pre-release tag

### Pre-Release Versioning

- First alpha: `1.0.0-alpha.1`
- Next alpha: `1.0.0-alpha.2`
- First beta after alpha: `1.0.0-beta.1`
- RC after beta: `1.0.0-rc.1`

## Production Release Process

### Prerequisites

Before creating a production release:

1. **All tests must pass** in CI
2. **Changelog must be updated** with release notes
3. **Version must be synchronized** across all files
4. **Security checks must pass** (Credo, Sobelow)

### Step-by-Step Release

#### 1. Prepare the Release

```bash
# Update version in mix.exs
mix ash_phoenix_translations.version set 1.0.0

# Or use the shell script
./scripts/version.sh set 1.0.0

# Verify version synchronization
mix ash_phoenix_translations.version check
```

#### 2. Update Changelog

```bash
# Parse commits since last release
./scripts/changelog.sh parse v0.9.0

# Review unreleased changes
./scripts/changelog.sh show

# Generate and commit changelog
./scripts/changelog.sh release 1.0.0
```

#### 3. Commit and Tag

```bash
# Commit version and changelog updates
git add mix.exs README.md CHANGELOG.md
git commit -m "Release v1.0.0"

# Create and push tag
git tag v1.0.0
git push origin main
git push origin v1.0.0
```

#### 4. Monitor Release

The release workflow will automatically:

1. **Validate** version consistency
2. **Run** full test suite
3. **Build** documentation
4. **Create** GitHub release with changelog
5. **Publish** to Hex.pm
6. **Publish** docs to HexDocs
7. **Prepare** next development version

### Manual Release (Alternative)

If you prefer to trigger the release manually:

1. **Go to Actions** → **Release workflow**
2. **Click "Run workflow"**
3. **Enter version** (e.g., 1.0.0)
4. **Select if pre-release** (usually false for production)

## Version Management

### Using Mix Task

```bash
# Show current version
mix ash_phoenix_translations.version get

# Set specific version
mix ash_phoenix_translations.version set 1.2.3

# Bump version
mix ash_phoenix_translations.version bump patch  # 1.0.0 → 1.0.1
mix ash_phoenix_translations.version bump minor  # 1.0.0 → 1.1.0
mix ash_phoenix_translations.version bump major  # 1.0.0 → 2.0.0

# Synchronize version across files
mix ash_phoenix_translations.version sync

# Check version consistency
mix ash_phoenix_translations.version check
```

### Using Shell Script

```bash
# Same commands available
./scripts/version.sh get
./scripts/version.sh set 1.2.3
./scripts/version.sh bump patch
./scripts/version.sh sync
./scripts/version.sh check
```

## Changelog Management

### Conventional Commits

We follow conventional commits for automatic changelog generation:

```
feat(scope): Add new feature
fix(scope): Fix bug
docs(scope): Update documentation
refactor(scope): Refactor code
test(scope): Add tests
chore(scope): Maintenance tasks
```

### Manual Changelog Entries

```bash
# Add entry manually
./scripts/changelog.sh add feat translations "Add GraphQL support" 123

# Parse commits automatically
./scripts/changelog.sh parse v0.9.0 HEAD

# Show unreleased changes
./scripts/changelog.sh show

# Generate changelog for version
./scripts/changelog.sh generate 1.0.0

# Update CHANGELOG.md and clear unreleased
./scripts/changelog.sh release 1.0.0
```

### Changelog Format

```markdown
## [1.0.0] - 2024-01-15

### Added
- New feature descriptions

### Changed
- Modified functionality

### Fixed
- Bug fixes

### Breaking Changes
- Breaking change descriptions
```

## Troubleshooting

### Version Mismatch

If the release fails due to version mismatch:

```bash
# Synchronize all versions
mix ash_phoenix_translations.version sync

# Verify synchronization
mix ash_phoenix_translations.version check
```

### Failed Tests

If tests fail during release:

1. **Fix the issues** in a new PR
2. **Merge to main** after review
3. **Restart the release** process

### Hex Publishing Issues

If Hex publishing fails:

1. **Verify HEX_API_KEY** secret is set in GitHub
2. **Check package metadata** in mix.exs
3. **Ensure no naming conflicts** on Hex.pm
4. **Try manual publishing** as fallback:

```bash
mix hex.publish
```

### Rollback a Release

If a release needs to be rolled back:

1. **Delete the GitHub release**
2. **Yank from Hex** (within 1 hour):
   ```bash
   mix hex.publish --revert 1.0.0
   ```
3. **Create a patch release** with the fix

## Best Practices

1. **Always create pre-releases** for major changes
2. **Test pre-releases** in real applications before production release
3. **Keep changelog updated** with every PR
4. **Use conventional commits** for automatic changelog generation
5. **Review generated changelog** before releasing
6. **Monitor CI/CD pipelines** during release
7. **Announce releases** in project channels

## GitHub Secrets Required

Ensure these secrets are configured in your GitHub repository:

- `HEX_API_KEY`: Your Hex.pm API key for publishing packages
- `GITHUB_TOKEN`: Automatically provided by GitHub Actions

## Release Checklist

Before releasing, verify:

- [ ] All tests pass in CI
- [ ] No security vulnerabilities (Sobelow, deps.audit)
- [ ] Code formatting is correct
- [ ] Credo analysis passes
- [ ] Documentation builds successfully
- [ ] Changelog is updated
- [ ] Version is synchronized
- [ ] README examples are up-to-date
- [ ] Breaking changes are documented

## Support

For issues with the release process:

1. Check the [GitHub Actions logs](https://github.com/your-org/ash_phoenix_translations/actions)
2. Review this documentation
3. Open an issue if the problem persists