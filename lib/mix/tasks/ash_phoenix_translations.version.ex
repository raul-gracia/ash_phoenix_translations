defmodule Mix.Tasks.AshPhoenixTranslations.Version do
  @moduledoc """
  Version management for ash_phoenix_translations.

  This task provides comprehensive version management across your project files,
  ensuring version consistency in mix.exs, README.md, and CHANGELOG.md. It
  supports semantic versioning with automatic changelog generation.

  ## Features

  - **Version Retrieval**: Get current version from mix.exs
  - **Version Setting**: Update version across all files
  - **Semantic Bumping**: Increment major, minor, or patch versions
  - **Synchronization**: Sync version from mix.exs to documentation
  - **Consistency Checking**: Validate version consistency across files
  - **Changelog Management**: Automatic changelog entry generation
  - **Semantic Version Validation**: Ensure valid SemVer format

  ## Basic Usage

      # Show current version
      mix ash_phoenix_translations.version get

      # Set specific version
      mix ash_phoenix_translations.version set 1.2.3

      # Bump patch version (1.0.0 → 1.0.1)
      mix ash_phoenix_translations.version bump patch

      # Bump minor version (1.0.0 → 1.1.0)
      mix ash_phoenix_translations.version bump minor

      # Bump major version (1.0.0 → 2.0.0)
      mix ash_phoenix_translations.version bump major

      # Synchronize version to all files
      mix ash_phoenix_translations.version sync

      # Check version consistency
      mix ash_phoenix_translations.version check

  ## Commands

  ### get

  Displays the current version from `mix.exs`:

      mix ash_phoenix_translations.version get

  Output:

      Current version: 1.0.0

  ### set VERSION

  Sets a specific version across all project files:

      mix ash_phoenix_translations.version set 1.2.3

  Updates:
  - `mix.exs`: `version: "1.2.3"`
  - `README.md`: `{:ash_phoenix_translations, "~> 1.2.3"}`
  - `CHANGELOG.md`: Creates new version entry

  ### bump TYPE

  Increments version according to semantic versioning:

      # Patch bump: 1.0.0 → 1.0.1 (bug fixes)
      mix ash_phoenix_translations.version bump patch

      # Minor bump: 1.0.0 → 1.1.0 (new features, backward compatible)
      mix ash_phoenix_translations.version bump minor

      # Major bump: 1.0.0 → 2.0.0 (breaking changes)
      mix ash_phoenix_translations.version bump major

  ### sync

  Synchronizes version from mix.exs to documentation files:

      mix ash_phoenix_translations.version sync

  Useful when you've manually updated mix.exs and need to propagate changes.

  ### check

  Validates version consistency across project files:

      mix ash_phoenix_translations.version check

  Output (consistent):

      Checking version consistency...
        mix.exs:   1.0.0
        README.md: 1.0.0
      ✓ Versions are synchronized

  Output (inconsistent):

      Checking version consistency...
        mix.exs:   1.0.1
        README.md: 1.0.0
      ⚠ Version mismatch detected!
      Run 'mix ash_phoenix_translations.version sync' to synchronize

  ## Semantic Versioning

  This task follows Semantic Versioning (SemVer) 2.0.0 specification:

  ### Version Format

      MAJOR.MINOR.PATCH[-prerelease][+build]

  Examples:
  - `1.0.0` - Standard release
  - `1.0.0-alpha.1` - Pre-release
  - `1.0.0+20250119` - Build metadata
  - `2.0.0-rc.1+exp.sha.5114f85` - Complex version

  ### When to Bump

  **MAJOR version** when you make incompatible API changes:
  - Breaking changes to public API
  - Removing deprecated features
  - Major architectural changes
  - Elixir/OTP version requirement changes

  **MINOR version** when you add functionality in a backward compatible manner:
  - New features
  - New public functions/modules
  - Deprecating features (not removing)
  - Performance improvements

  **PATCH version** when you make backward compatible bug fixes:
  - Bug fixes
  - Documentation updates
  - Internal refactoring
  - Security patches

  ## File Updates

  ### mix.exs

  Updates the version line in your project definition:

      # Before
      def project do
        [
          app: :ash_phoenix_translations,
          version: "1.0.0",
          # ...
        ]
      end

      # After set 1.2.3
      def project do
        [
          app: :ash_phoenix_translations,
          version: "1.2.3",
          # ...
        ]
      end

  ### README.md

  Updates dependency version in installation instructions:

      # Before
      {:ash_phoenix_translations, "~> 1.0.0"}

      # After set 1.2.3
      {:ash_phoenix_translations, "~> 1.2.3"}

  Also updates any standalone version references:

      # Before
      ash_phoenix_translations 1.0.0

      # After
      ash_phoenix_translations 1.2.3

  ### CHANGELOG.md

  Adds a new version entry with today's date:

      # Changelog

      ## [1.2.3] - 2025-01-19

      ### Added

      ### Changed

      ### Fixed

      ### Removed

      ## [1.0.0] - 2024-12-01
      ...

  ## Workflow Examples

  ### Release Workflow

      # 1. Ensure all changes are committed
      git status

      # 2. Check current version consistency
      mix ash_phoenix_translations.version check

      # 3. Bump version (e.g., patch release)
      mix ash_phoenix_translations.version bump patch

      # 4. Edit CHANGELOG.md to document changes
      vim CHANGELOG.md

      # 5. Commit version bump
      git add mix.exs README.md CHANGELOG.md
      git commit -m "Bump version to $(mix ash_phoenix_translations.version get)"

      # 6. Tag the release
      VERSION=$(mix ash_phoenix_translations.version get)
      git tag -a "v$VERSION" -m "Release v$VERSION"

      # 7. Push to repository
      git push origin main --tags

  ### Pre-release Workflow

      # Create pre-release version
      mix ash_phoenix_translations.version set 2.0.0-rc.1

      # Test and iterate
      # ...

      # Final release
      mix ash_phoenix_translations.version set 2.0.0

  ### Hotfix Workflow

      # On maintenance branch for version 1.2.x
      git checkout -b hotfix/1.2.4 v1.2.3

      # Apply fixes
      # ...

      # Bump patch version
      mix ash_phoenix_translations.version bump patch

      # Commit and tag
      git commit -am "Hotfix: Critical security patch"
      git tag -a v1.2.4 -m "Hotfix v1.2.4"

  ## CI/CD Integration

  ### Automated Version Check

      # .github/workflows/version-check.yml
      name: Version Check

      on: [pull_request]

      jobs:
        check:
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v3
            - uses: erlef/setup-beam@v1
              with:
                elixir-version: '1.17'
                otp-version: '27'

            - name: Install dependencies
              run: mix deps.get

            - name: Check version consistency
              run: mix ash_phoenix_translations.version check

  ### Automated Release

      # .github/workflows/release.yml
      name: Release

      on:
        push:
          tags:
            - 'v*'

      jobs:
        release:
          runs-on: ubuntu-latest
          steps:
            - uses: actions/checkout@v3
            - uses: erlef/setup-beam@v1

            - name: Get version
              id: version
              run: |
                VERSION=$(mix ash_phoenix_translations.version get)
                echo "version=$VERSION" >> $GITHUB_OUTPUT

            - name: Publish to Hex
              env:
                HEX_API_KEY: ${{ secrets.HEX_API_KEY }}
              run: mix hex.publish --yes

  ### Pre-commit Hook

      # .git/hooks/pre-commit
      #!/bin/sh

      # Check version consistency before commit
      mix ash_phoenix_translations.version check

      if [ $? -ne 0 ]; then
        echo "Version mismatch detected. Run:"
        echo "  mix ash_phoenix_translations.version sync"
        exit 1
      fi

  ## Advanced Use Cases

  ### Automated Version Bumping

      # Bump based on commit messages
      defmodule MyApp.AutoVersion do
        def bump_from_commits do
          # Get commits since last tag
          {commits, 0} = System.cmd("git", ["log", "--format=%s", "$(git describe --tags --abbrev=0)..HEAD"])

          # Determine bump type from conventional commits
          bump_type =
            cond do
              String.contains?(commits, "BREAKING CHANGE") -> "major"
              String.contains?(commits, "feat:") -> "minor"
              true -> "patch"
            end

          # Bump version
          System.cmd("mix", ["ash_phoenix_translations.version", "bump", bump_type])
        end
      end

  ### Multi-File Synchronization

      # Sync to additional files beyond defaults
      defmodule MyApp.ExtendedVersionSync do
        def sync_to_all do
          version = get_version()

          # Update package.json (if using Node assets)
          update_package_json(version)

          # Update Docker labels
          update_dockerfile(version)

          # Update OpenAPI spec
          update_openapi_spec(version)
        end

        defp get_version do
          {output, 0} = System.cmd("mix", ["ash_phoenix_translations.version", "get"])
          String.trim(output) |> String.replace("Current version: ", "")
        end

        defp update_package_json(version) do
          # Implementation
        end
      end

  ## Troubleshooting

  ### Version Validation Failed

  **Problem**: "Invalid version format: x.y.z-alpha"

  **Solution**:
  Ensure version follows SemVer format:
  - Valid: `1.0.0`, `1.0.0-alpha.1`, `1.0.0+build.123`
  - Invalid: `v1.0.0`, `1.0`, `1.0.0.0`

  ### CHANGELOG Not Created

  **Problem**: CHANGELOG.md doesn't exist

  **Solution**:
  The task auto-creates it. Ensure directory is writable:

      touch CHANGELOG.md
      git add CHANGELOG.md

  ### README Pattern Not Found

  **Problem**: README version not updated

  **Solution**:
  Ensure README contains dependency declaration:

      {:ash_phoenix_translations, "~> X.Y.Z"}

  ### Sync Fails After Manual Edit

  **Problem**: Manual mix.exs edit not reflected in README

  **Solution**:

      # After manual mix.exs edit
      mix ash_phoenix_translations.version sync

  ## Security Considerations

  ### Version String Validation

  The task validates all version strings to prevent injection:

      defp valid_version?(version) do
        Regex.match?(~r/^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$/, version)
      end

  Only valid SemVer strings are accepted.

  ## Related Tasks

  - `mix hex.publish` - Publish package to Hex.pm
  - `git tag` - Create version tags in Git
  - `mix docs` - Generate documentation

  ## Examples

  ### Standard Release Process

      # Check current state
      mix ash_phoenix_translations.version get
      # Output: Current version: 1.0.0

      # Bump patch for bug fix release
      mix ash_phoenix_translations.version bump patch
      # Output: Bumping version from 1.0.0 to 1.0.1

      # Edit CHANGELOG to document changes
      # Add release notes to CHANGELOG.md under ## [1.0.1]

      # Verify all files updated
      mix ash_phoenix_translations.version check

      # Commit and tag
      git add -A
      git commit -m "Release v1.0.1"
      git tag v1.0.1

  ### Feature Release

      # Bump minor for new feature
      mix ash_phoenix_translations.version bump minor
      # 1.0.1 → 1.1.0

      # Document features in CHANGELOG
      # git commit, tag, push

  ### Breaking Change Release

      # Major version bump
      mix ash_phoenix_translations.version bump major
      # 1.1.0 → 2.0.0

      # Update migration guides
      # Document breaking changes in CHANGELOG

  ### Manual Version Control

      # Set specific version manually
      mix ash_phoenix_translations.version set 1.5.0

      # Sync ensures consistency
      mix ash_phoenix_translations.version sync

  ### Pre-release Testing

      # Create release candidate
      mix ash_phoenix_translations.version set 2.0.0-rc.1

      # Test thoroughly
      # ...

      # Promote to final release
      mix ash_phoenix_translations.version set 2.0.0
  """
  @shortdoc "Manage ash_phoenix_translations version"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    case args do
      ["get"] ->
        get_version()

      ["set", version] ->
        set_version(version)

      ["bump", type] ->
        bump_version(type)

      ["sync"] ->
        sync_versions()

      ["check"] ->
        check_versions()

      _ ->
        Mix.shell().info("""
        ash_phoenix_translations version management

        Usage: mix ash_phoenix_translations.version <command> [options]

        Commands:
          get              Show current version from mix.exs
          set <version>    Set specific version across all files
          bump <type>      Bump version (major|minor|patch)
          sync             Synchronize version from mix.exs to all files
          check            Check version consistency across files

        Examples:
          mix ash_phoenix_translations.version get
          mix ash_phoenix_translations.version set 1.0.0
          mix ash_phoenix_translations.version bump patch
        """)
    end
  end

  defp get_version do
    version = Mix.Project.config()[:version]
    Mix.shell().info("Current version: #{version}")
    version
  end

  defp set_version(new_version) do
    unless valid_version?(new_version) do
      Mix.raise("Invalid version format: #{new_version}")
    end

    update_mix_exs(new_version)
    update_readme(new_version)
    update_changelog(new_version)

    Mix.shell().info([:green, "✓", :reset, " Version synchronized to #{new_version}"])
  end

  defp bump_version(type) do
    current = Mix.Project.config()[:version]
    new_version = bump_semver(current, type)

    Mix.shell().info("Bumping version from #{current} to #{new_version}")
    set_version(new_version)
  end

  defp sync_versions do
    version = Mix.Project.config()[:version]
    update_readme(version)
    update_changelog(version)

    Mix.shell().info([:green, "✓", :reset, " All files synchronized to version #{version}"])
  end

  defp check_versions do
    mix_version = Mix.Project.config()[:version]
    readme_version = extract_readme_version()

    Mix.shell().info("Checking version consistency...")
    Mix.shell().info("  mix.exs:   #{mix_version}")
    Mix.shell().info("  README.md: #{readme_version || "not found"}")

    if mix_version == readme_version do
      Mix.shell().info([:green, "✓", :reset, " Versions are synchronized"])
    else
      Mix.shell().error([:yellow, "⚠", :reset, " Version mismatch detected!"])
      Mix.shell().info("Run 'mix ash_phoenix_translations.version sync' to synchronize")
      exit({:shutdown, 1})
    end
  end

  defp update_mix_exs(version) do
    path = "mix.exs"
    content = File.read!(path)

    updated = Regex.replace(~r/version: "[^"]*"/, content, ~s(version: "#{version}"))

    File.write!(path, updated)
    Mix.shell().info([:green, "✓", :reset, " Updated mix.exs to version #{version}"])
  end

  defp update_readme(version) do
    path = "README.md"

    if File.exists?(path) do
      content = File.read!(path)

      # Update hex.pm dependency version
      updated =
        content
        |> String.replace(
          ~r/{:ash_phoenix_translations, "~> [^"]*"}/,
          ~s({:ash_phoenix_translations, "~> #{version}"})
        )
        |> String.replace(
          ~r/ash_phoenix_translations [0-9]+\.[0-9]+\.[0-9]+/,
          "ash_phoenix_translations #{version}"
        )

      File.write!(path, updated)
      Mix.shell().info([:green, "✓", :reset, " Updated README.md to version #{version}"])
    else
      Mix.shell().info([:yellow, "⚠", :reset, " README.md not found, skipping"])
    end
  end

  defp update_changelog(version) do
    path = "CHANGELOG.md"
    date = Date.utc_today() |> to_string()

    unless File.exists?(path) do
      File.write!(path, "# Changelog\n\n")
    end

    content = File.read!(path)

    if String.contains?(content, "## [#{version}]") do
      Mix.shell().info([
        :yellow,
        "⚠",
        :reset,
        " Version #{version} already exists in CHANGELOG.md"
      ])
    else
      lines = String.split(content, "\n")

      # Insert new version after the title
      updated =
        [
          Enum.at(lines, 0),
          "",
          "## [#{version}] - #{date}",
          "",
          "### Added",
          "",
          "### Changed",
          "",
          "### Fixed",
          "",
          "### Removed"
        ] ++ Enum.drop(lines, 1)

      File.write!(path, Enum.join(updated, "\n"))
      Mix.shell().info([:green, "✓", :reset, " Added version #{version} to CHANGELOG.md"])
    end
  end

  defp extract_readme_version do
    path = "README.md"

    if File.exists?(path) do
      content = File.read!(path)

      case Regex.run(~r/{:ash_phoenix_translations, "~> ([^"]*)"/, content) do
        [_, version] -> version
        _ -> nil
      end
    else
      nil
    end
  end

  defp bump_semver(version, type) do
    [major, minor, patch] =
      version
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)

    case type do
      "major" ->
        "#{major + 1}.0.0"

      "minor" ->
        "#{major}.#{minor + 1}.0"

      "patch" ->
        "#{major}.#{minor}.#{patch + 1}"

      _ ->
        Mix.raise("Invalid bump type: #{type} (use major, minor, or patch)")
    end
  end

  defp valid_version?(version) do
    Regex.match?(~r/^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$/, version)
  end
end
