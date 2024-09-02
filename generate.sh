#
# Copyright (C) 2024 Souhrud Reddy
#
# SPDX-License-Identifier: Apache-2.0
#

#!/bin/bash

# Check if a filename is provided as an argument
if [ -z "$1" ]; then
    echo "Please provide a filename as an argument."
    exit 1
fi

# Check if the input file exists
if [ ! -f "$1" ]; then
    echo "File not found: $1"
    exit 1
fi

if [ ! -f *.output ]; then
    echo "Output not found! Run adapt.sh first"
    exit 1
fi

# Define the input file
INFILE="$1"
FILENAME=$(basename "$1")

echo "Processing input file: $INFILE"

# Start the XML file with the header
cat << EOF > local_manifests.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
<!-- Generated using sounddrill31/actions_generate_local_manifests -->
EOF

# Initialize associative arrays to store remotes, projects, and remove-projects
declare -A REMOTES
declare -A PROJECTS
declare -A REMOVE_PROJECTS

# Initialize counters
ADD_COUNT=0
REMOVE_COUNT=0

# Read the input file line by line
while IFS= read -r LINE || [ -n "$LINE" ]; do
    # Remove carriage return and leading/trailing whitespace
    LINE=$(echo "$LINE" | tr -d '\r' | xargs)
    
    echo "Processing line: $LINE"
    
    # Check if the line starts with curly braces
    if [[ $LINE =~ ^\{.*\}$ ]]; then
        # Extract TESTING_URL and TESTING_BRANCH
        read -r TESTING_URL TESTING_BRANCH <<< $(echo "$LINE" | tr -d '{}' | tr '"' ' ')
        echo "$TESTING_URL" > url
        echo "$TESTING_BRANCH" > branch
        echo "true" > test_status
        echo "Set TESTING_URL=$TESTING_URL and TESTING_BRANCH=$TESTING_BRANCH"
        continue
    fi
    
    # Call add.sh for 'add' lines
    if [[ $LINE == add* ]]; then
        echo "Calling add.sh with: $LINE"
        if source ./add.sh "$LINE"; then
            ((ADD_COUNT++))
        else
            echo "Error in add.sh"
        fi
    fi
    
    # Call remove.sh for 'remove' lines
    if [[ $LINE == remove* ]]; then
        echo "Calling remove.sh with: $LINE $TESTING_URL $TESTING_BRANCH"
        if source ./remove.sh "$LINE" "$TESTING_URL" "$TESTING_BRANCH"; then
            ((REMOVE_COUNT++))
        else
            echo "Error in remove.sh"
        fi
    fi
done < "$INFILE"

# Clean up
rm -rf manifest

echo "" >> local_manifests.xml

# Output remotes
echo "    <!-- Remotes -->" >> local_manifests.xml
for remote in "${REMOTES[@]}"; do
    echo "$remote" >> local_manifests.xml
done
echo "" >> local_manifests.xml

# Output remove-project entries
echo "    <!-- Removals -->" >> local_manifests.xml
for remove_project in "${REMOVE_PROJECTS[@]}"; do
    echo "$remove_project" >> local_manifests.xml
done
echo "" >> local_manifests.xml

# Output projects
echo "    <!-- Repos -->" >> local_manifests.xml
echo "    <!-- Device -->" >> local_manifests.xml
for project in "${PROJECTS[@]}"; do
    if [[ $project == *"device/"* && $project != *"common"* ]]; then
        echo "$project" >> local_manifests.xml
    fi
done
echo "" >> local_manifests.xml

echo "    <!-- Device - Common -->" >> local_manifests.xml
for project in "${PROJECTS[@]}"; do
    if [[ $project == *"device/"* && $project == *"common"* ]]; then
        echo "$project" >> local_manifests.xml
    fi
done
echo "" >> local_manifests.xml

echo "    <!-- Kernel -->" >> local_manifests.xml
for project in "${PROJECTS[@]}"; do
    if [[ $project == *"kernel/"* ]]; then
        echo "$project" >> local_manifests.xml
    fi
done
echo "" >> local_manifests.xml

echo "    <!-- Vendor -->" >> local_manifests.xml
for project in "${PROJECTS[@]}"; do
    if [[ $project == *"vendor/"* && $project != *"common"* ]]; then
        echo "$project" >> local_manifests.xml
    fi
done
echo "" >> local_manifests.xml

echo "    <!-- Vendor - Common -->" >> local_manifests.xml
for project in "${PROJECTS[@]}"; do
    if [[ $project == *"vendor/"* && $project == *"common"* ]]; then
        echo "$project" >> local_manifests.xml
    fi
done
echo "" >> local_manifests.xml

# Check if there are any hardware projects
HARDWARE_PROJECTS=()
for project in "${PROJECTS[@]}"; do
    if [[ $project == *"hardware/"* ]]; then
        HARDWARE_PROJECTS+=("$project")
    fi
done
if [[ ${#HARDWARE_PROJECTS[@]} -gt 0 ]]; then
    echo "    <!-- Hardware -->" >> local_manifests.xml
    for project in "${HARDWARE_PROJECTS[@]}"; do
        echo "$project" >> local_manifests.xml
    done
    echo "" >> local_manifests.xml
fi

# Check if there are any other projects
OTHER_PROJECTS=()
for project in "${PROJECTS[@]}"; do
    if [[ $project != *"device/"* && $project != *"kernel/"* && $project != *"vendor/"* && $project != *"hardware/"* ]]; then
        OTHER_PROJECTS+=("$project")
    fi
done
if [[ ${#OTHER_PROJECTS[@]} -gt 0 ]]; then
    echo "    <!-- Other Repos -->" >> local_manifests.xml
    for project in "${OTHER_PROJECTS[@]}"; do
        echo "$project" >> local_manifests.xml
    done
    echo "" >> local_manifests.xml
fi

# Close the XML file
echo '</manifest>' >> local_manifests.xml

echo "Local manifests generated in local_manifests.xml"
echo "Add operations processed: $ADD_COUNT"
echo "Remove operations processed: $REMOVE_COUNT"

# Print the contents of the arrays
echo "REMOTES:"
for key in "${!REMOTES[@]}"; do
    echo "  $key: ${REMOTES[$key]}"
done

echo "PROJECTS:"
for key in "${!PROJECTS[@]}"; do
    echo "  $key: ${PROJECTS[$key]}"
done

echo "REMOVE_PROJECTS:"
for key in "${!REMOVE_PROJECTS[@]}"; do
    echo "  $key: ${REMOVE_PROJECTS[$key]}"
done

# Print the exported variables
echo "TESTING_URL: $TESTING_URL"
echo "TESTING_BRANCH: $TESTING_BRANCH"