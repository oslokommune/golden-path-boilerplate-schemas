#!/bin/bash
# This script populates the /schemas directory in this repo root with with schemas for all the GitHub releases in the
# golden-path-boilerplate repository.

set -e

# Default configuration
REPO=""
BOILERPLATE_DIR=""  # Base directory for templates
OUTPUT_DIR="test"
TEST_MODE=false
TEST_RELEASE=""
TEMP_DIR=""

# GitHub Actions components list
GITHUB_ACTIONS_COMPONENTS=(
  "terraform-on-changed-dirs"
  "receive-dispatch-event"
  "template-tracker"
  "docker-build-push-partials"
  "docker-build-push"
  "integration-and-delivery"
  "template-tracker-tfa"
  "renovate"
)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo|-r)
      shift
      if [[ $# -gt 0 ]]; then
        REPO="$1"
        shift
      else
        echo "Error: --repo requires a repository name (OWNER/REPO format)"
        exit 1
      fi
      ;;
    --boilerplate-dir|-b)
      shift
      if [[ $# -gt 0 ]]; then
        BOILERPLATE_DIR="$1"
        shift
      else
        echo "Error: --boilerplate-dir requires a directory path"
        exit 1
      fi
      ;;
    --output|-o)
      shift
      if [[ $# -gt 0 ]]; then
        OUTPUT_DIR="$1"
        shift
      else
        echo "Error: --output requires a directory path"
        exit 1
      fi
      ;;
    --test)
      TEST_MODE=true
      shift
      if [[ $# -gt 0 && ! $1 =~ ^- ]]; then
        TEST_RELEASE="$1"
        shift
      fi
      ;;
    --help)
      echo "Usage: $0 --repo OWNER/REPO --boilerplate-dir BOILERPLATE_DIR [options]"
      echo ""
      echo "Required:"
      echo "  --repo, -r OWNER/REPO          GitHub repository in OWNER/REPO format"
      echo "  --boilerplate-dir, -b DIRECTORY    Base directory for boilerplate templates"
      echo ""
      echo "Options:"
      echo "  --output, -o DIRECTORY         Output directory for schema files (default: test)"
      echo "  --test [RELEASE_TAG]           Run in test mode with just one release"
      echo "                                 If RELEASE_TAG is provided, use that specific release"
      echo "                                 If not provided, use the latest release"
      echo "  --help                         Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$REPO" ]]; then
  echo "Error: --repo is required"
  echo "Use --help for more information"
  exit 1
fi

if [[ -z "$BOILERPLATE_DIR" ]]; then
  echo "Error: --boilerplate-dir is required"
  echo "Use --help for more information"
  exit 1
fi

# Create a unique temporary directory
TEMP_DIR=$(mktemp -d -t "${REPO//\//-}-releases-XXXXXX")
if [[ ! "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
  echo "Error: Failed to create temporary directory"
  exit 1
fi

# Cleanup function
cleanup() {
  echo "Cleaning up temporary directory..."
  rm -rf "$TEMP_DIR"
}

# Register cleanup function to run on exit, interruption, or termination
trap cleanup EXIT INT TERM

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

echo "Starting to process releases for $REPO"
echo "Boilerplate base directory: $BOILERPLATE_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Working directory: $TEMP_DIR"

# Clone the repository to temp directory
echo "Cloning repository..."
if ! git clone "git@github.com:$REPO.git" "$TEMP_DIR" --quiet; then
  echo "Error: Failed to clone repository. Check if the repository exists and you have SSH access."
  exit 1
fi

# Change to the cloned repository
cd "$TEMP_DIR"

# Get releases based on mode
echo "Fetching GitHub releases..."

if [[ "$TEST_MODE" = true ]]; then
  if [[ -n "$TEST_RELEASE" ]]; then
    echo "Test mode: Using specified release tag '$TEST_RELEASE'"
    # Create a JSON array with just the specified release
    releases="[{\"tagName\":\"$TEST_RELEASE\",\"name\":\"$TEST_RELEASE\"}]"
    echo "Processing 1 release (test mode with specified tag)"
  else
    echo "Test mode: Using latest release"
    # Get only the latest release
    releases=$(gh release list --repo "$REPO" --limit 1 --json tagName,name)
    echo "Processing 1 release (test mode with latest release)"
  fi
else
  # Get all releases in one go
  releases=$(gh release list --repo "$REPO" --limit 1000 --json tagName,name)
fi

# Check if we got valid JSON
if ! echo "$releases" | jq empty 2>/dev/null; then
  echo "Error: Failed to get releases. Make sure you're authenticated with GitHub CLI."
  exit 1
fi

release_count=$(echo "$releases" | jq length)
if [[ "$TEST_MODE" != true ]]; then
  echo "Found $release_count releases to process"
fi

# Process each release
for i in $(seq 0 $((release_count - 1))); do
  tag_name=$(echo "$releases" | jq -r ".[$i].tagName")
  release_name=$(echo "$releases" | jq -r ".[$i].name")

  echo -e "\n===== Processing release: $tag_name ($release_name) ====="

  # Checkout the tag
  echo "Checking out tag: $tag_name"

  # First verify the tag exists
  if ! git tag -l | grep -q "^${tag_name}$"; then
    echo "  ❌ Tag $tag_name doesn't exist in the repository"
    echo "     Available tags that match closely (if any):"
    git tag -l | grep -i "${tag_name%%-*}" | head -n 5
    continue
  fi

  if ! git checkout "$tag_name" --quiet 2>/dev/null; then
    echo "  ❌ Failed to checkout tag $tag_name, skipping"
    continue
  fi

  # Extract the component name from the tag
  # Get everything before the last dash in the tag
  component_name=$(echo "$tag_name" | sed -E 's/^(.*)-v[0-9]+(\.[0-9]+)*$/\1/')

  # Determine if this is a GitHub Actions component
  is_github_action=false
  for action in "${GITHUB_ACTIONS_COMPONENTS[@]}"; do
    if [[ "$component_name" == "$action" ]]; then
      is_github_action=true
      break
    fi
  done

  # Create a dynamic template directory path based on the component name and type
  if [[ "$is_github_action" == true ]]; then
    dynamic_template_dir="$BOILERPLATE_DIR/github-actions/$component_name"
    component_type="github-actions"
  else
    dynamic_template_dir="$BOILERPLATE_DIR/terraform/$component_name"
    component_type="terraform"
  fi

  # Run the command
  output_file="$(cd - > /dev/null && pwd)/$OUTPUT_DIR/$tag_name.schema.json"
  echo "Running command with:"
  echo "  - Component: $component_name (type: $component_type)"
  echo "  - Template directory: $dynamic_template_dir"
  echo "  - Release: $tag_name"
  echo "  - Output file: $output_file"
  echo "Resulting command: schema-generator $dynamic_template_dir $tag_name $output_file"

  # Create parent directory for output file if it doesn't exist
  mkdir -p "$(dirname "$output_file")"

  if schema-generator "$dynamic_template_dir" "$tag_name" "$output_file"; then
    echo "  ✅ Successfully processed $tag_name"
  else
    echo "  ❌ Failed to process $tag_name"
  fi
done

echo -e "\nProcessing complete"
echo "Schema files saved in $OUTPUT_DIR directory"
