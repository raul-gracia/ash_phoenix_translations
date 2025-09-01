#!/bin/bash
# Changelog generation and management script

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CHANGELOG_FILE="CHANGELOG.md"
UNRELEASED_FILE=".unreleased"

# Categories for conventional commits
declare -A COMMIT_CATEGORIES=(
    ["feat"]="Added"
    ["fix"]="Fixed"
    ["docs"]="Documentation"
    ["style"]="Style"
    ["refactor"]="Changed"
    ["perf"]="Performance"
    ["test"]="Testing"
    ["build"]="Build"
    ["ci"]="CI/CD"
    ["chore"]="Maintenance"
    ["revert"]="Reverted"
    ["breaking"]="Breaking Changes"
)

# Initialize unreleased entries file if it doesn't exist
init_unreleased() {
    if [ ! -f "$UNRELEASED_FILE" ]; then
        cat > "$UNRELEASED_FILE" << EOF
# Unreleased Changes
# Format: TYPE|SCOPE|DESCRIPTION|PR_NUMBER|AUTHOR
# Example: feat|translations|Add support for nested translations|123|john_doe
EOF
        echo -e "${GREEN}✓${NC} Initialized $UNRELEASED_FILE"
    fi
}

# Add entry to unreleased changes
add_entry() {
    local type=$1
    local scope=$2
    local description=$3
    local pr_number=${4:-""}
    local author=${5:-$(git config user.name)}
    
    init_unreleased
    
    # Validate type
    if [[ ! " feat fix docs style refactor perf test build ci chore revert breaking " =~ " $type " ]]; then
        echo -e "${RED}✗${NC} Invalid type: $type"
        echo "Valid types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert, breaking"
        exit 1
    fi
    
    # Add entry
    echo "${type}|${scope}|${description}|${pr_number}|${author}" >> "$UNRELEASED_FILE"
    echo -e "${GREEN}✓${NC} Added changelog entry: ${type}(${scope}): ${description}"
}

# Parse commits since last tag
parse_commits() {
    local since_tag=${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo "")}
    local until_ref=${2:-"HEAD"}
    
    if [ -z "$since_tag" ]; then
        echo -e "${YELLOW}⚠${NC} No previous tag found, parsing all commits"
        local range="$until_ref"
    else
        local range="${since_tag}..${until_ref}"
    fi
    
    echo -e "${BLUE}ℹ${NC} Parsing commits in range: $range"
    
    # Parse conventional commits
    while IFS= read -r commit; do
        # Extract commit hash and message
        local hash=$(echo "$commit" | cut -d' ' -f1)
        local message=$(echo "$commit" | cut -d' ' -f2-)
        
        # Parse conventional commit format
        if [[ "$message" =~ ^([a-z]+)(\(([^)]+)\))?(!)?:\ (.+)$ ]]; then
            local type="${BASH_REMATCH[1]}"
            local scope="${BASH_REMATCH[3]:-""}"
            local breaking="${BASH_REMATCH[4]}"
            local description="${BASH_REMATCH[5]}"
            
            # Check for breaking change
            if [ -n "$breaking" ] || [[ "$message" =~ "BREAKING CHANGE" ]]; then
                type="breaking"
            fi
            
            # Extract PR number if present
            local pr_number=""
            if [[ "$description" =~ \(#([0-9]+)\) ]]; then
                pr_number="${BASH_REMATCH[1]}"
                description=$(echo "$description" | sed "s/ (#$pr_number)//")
            fi
            
            # Get author
            local author=$(git show -s --format='%an' "$hash")
            
            # Add to unreleased
            echo "${type}|${scope}|${description}|${pr_number}|${author}" >> "$UNRELEASED_FILE"
        fi
    done < <(git log --oneline "$range" 2>/dev/null)
    
    echo -e "${GREEN}✓${NC} Parsed commits successfully"
}

# Generate changelog for a version
generate_version() {
    local version=$1
    local date=${2:-$(date +%Y-%m-%d)}
    
    init_unreleased
    
    # Group entries by category
    declare -A categories
    
    # Read unreleased entries
    while IFS='|' read -r type scope description pr_number author; do
        # Skip comments and empty lines
        [[ "$type" =~ ^#.*$ ]] && continue
        [[ -z "$type" ]] && continue
        
        # Get category
        local category="${COMMIT_CATEGORIES[$type]:-Other}"
        
        # Format entry
        local entry="- "
        [ -n "$scope" ] && entry+="**${scope}**: "
        entry+="$description"
        [ -n "$pr_number" ] && entry+=" (#$pr_number)"
        [ -n "$author" ] && entry+=" - @${author}"
        
        # Add to category
        if [ -z "${categories[$category]}" ]; then
            categories[$category]="$entry"
        else
            categories[$category]="${categories[$category]}\n$entry"
        fi
    done < "$UNRELEASED_FILE"
    
    # Generate changelog section
    local changelog_section="## [$version] - $date\n\n"
    
    # Add categories in order
    for category in "Breaking Changes" "Added" "Changed" "Fixed" "Performance" "Documentation" "Testing" "Build" "CI/CD" "Maintenance" "Reverted" "Other"; do
        if [ -n "${categories[$category]}" ]; then
            changelog_section+="### $category\n"
            changelog_section+="${categories[$category]}\n\n"
        fi
    done
    
    echo -e "$changelog_section"
}

# Update changelog file
update_changelog() {
    local version=$1
    local content=$2
    
    if [ ! -f "$CHANGELOG_FILE" ]; then
        echo "# Changelog" > "$CHANGELOG_FILE"
        echo "" >> "$CHANGELOG_FILE"
        echo "All notable changes to this project will be documented in this file." >> "$CHANGELOG_FILE"
        echo "" >> "$CHANGELOG_FILE"
    fi
    
    # Check if version already exists
    if grep -q "## \[$version\]" "$CHANGELOG_FILE"; then
        echo -e "${YELLOW}⚠${NC} Version $version already exists in changelog"
        return 1
    fi
    
    # Insert new version after the header
    local temp_file=$(mktemp)
    
    # Copy header (first 4 lines)
    head -n 4 "$CHANGELOG_FILE" > "$temp_file"
    
    # Add new version
    echo -e "$content" >> "$temp_file"
    
    # Add rest of file
    tail -n +5 "$CHANGELOG_FILE" >> "$temp_file"
    
    # Replace original file
    mv "$temp_file" "$CHANGELOG_FILE"
    
    echo -e "${GREEN}✓${NC} Updated $CHANGELOG_FILE with version $version"
}

# Clear unreleased entries
clear_unreleased() {
    cat > "$UNRELEASED_FILE" << EOF
# Unreleased Changes
# Format: TYPE|SCOPE|DESCRIPTION|PR_NUMBER|AUTHOR
# Example: feat|translations|Add support for nested translations|123|john_doe
EOF
    echo -e "${GREEN}✓${NC} Cleared unreleased entries"
}

# Main command handling
case "${1:-}" in
    add)
        shift
        if [ $# -lt 3 ]; then
            echo -e "${RED}✗${NC} Usage: $0 add <type> <scope> <description> [pr_number] [author]"
            exit 1
        fi
        add_entry "$@"
        ;;
    
    parse)
        shift
        parse_commits "$@"
        echo -e "${GREEN}✓${NC} Parsed commits added to $UNRELEASED_FILE"
        ;;
    
    generate)
        shift
        if [ -z "${1:-}" ]; then
            echo -e "${RED}✗${NC} Version required"
            echo "Usage: $0 generate <version> [date]"
            exit 1
        fi
        generate_version "$@"
        ;;
    
    release)
        shift
        if [ -z "${1:-}" ]; then
            echo -e "${RED}✗${NC} Version required"
            echo "Usage: $0 release <version> [date]"
            exit 1
        fi
        
        version=$1
        date=${2:-$(date +%Y-%m-%d)}
        
        # Generate changelog content
        content=$(generate_version "$version" "$date")
        
        # Update changelog file
        update_changelog "$version" "$content"
        
        # Clear unreleased entries
        clear_unreleased
        
        echo -e "${GREEN}✓${NC} Released version $version"
        ;;
    
    show)
        if [ ! -f "$UNRELEASED_FILE" ]; then
            echo -e "${YELLOW}⚠${NC} No unreleased entries found"
            exit 0
        fi
        
        echo -e "${BLUE}Unreleased Changes:${NC}"
        echo ""
        
        # Show formatted unreleased entries
        while IFS='|' read -r type scope description pr_number author; do
            [[ "$type" =~ ^#.*$ ]] && continue
            [[ -z "$type" ]] && continue
            
            echo -n "  • "
            echo -n -e "${GREEN}${type}${NC}"
            [ -n "$scope" ] && echo -n "(${scope})"
            echo -n ": $description"
            [ -n "$pr_number" ] && echo -n " (#$pr_number)"
            [ -n "$author" ] && echo -n " - @${author}"
            echo ""
        done < "$UNRELEASED_FILE"
        ;;
    
    *)
        echo "Changelog management script for ash_phoenix_translations"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  add <type> <scope> <description> [pr] [author]"
        echo "                          Add a changelog entry"
        echo "  parse [from_tag] [to]   Parse commits and add to unreleased"
        echo "  generate <version>      Generate changelog for version"
        echo "  release <version>       Update changelog and clear unreleased"
        echo "  show                    Show unreleased entries"
        echo ""
        echo "Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert, breaking"
        echo ""
        echo "Examples:"
        echo "  $0 add feat translations 'Add GraphQL support' 123 john_doe"
        echo "  $0 parse v0.9.0 HEAD"
        echo "  $0 generate 1.0.0"
        echo "  $0 release 1.0.0"
        echo "  $0 show"
        ;;
esac