#!/bin/bash

# Initialize isolate for v2.2.1 with cgroup v2 in Docker
CGROUP_ROOT="/sys/fs/cgroup"
ISOLATE_CGROUP="$CGROUP_ROOT/isolate"

# Create /run/isolate directory structure
sudo mkdir -p /run/isolate/locks

# Setup cgroup v2 for isolate
# Docker uses cgroup v2 but doesn't enable controllers by default.
# We need to create a delegated cgroup hierarchy for isolate.

# Create isolate's cgroup directory
sudo mkdir -p "$ISOLATE_CGROUP"

# Move all processes from root cgroup to a "init" child cgroup
# This allows us to enable controllers in the root cgroup
INIT_CGROUP="$CGROUP_ROOT/init"
sudo mkdir -p "$INIT_CGROUP"

# Move all existing processes to init cgroup
if [ -f "$CGROUP_ROOT/cgroup.procs" ]; then
    while read -r pid; do
        echo "$pid" | sudo tee "$INIT_CGROUP/cgroup.procs" > /dev/null 2>&1 || true
    done < "$CGROUP_ROOT/cgroup.procs"
fi

# Enable all available controllers in root cgroup
if [ -f "$CGROUP_ROOT/cgroup.controllers" ]; then
    CONTROLLERS=$(cat "$CGROUP_ROOT/cgroup.controllers")
    for controller in $CONTROLLERS; do
        echo "+$controller" | sudo tee "$CGROUP_ROOT/cgroup.subtree_control" > /dev/null 2>&1 || true
    done
fi

# Enable controllers for isolate cgroup
if [ -f "$CGROUP_ROOT/cgroup.controllers" ]; then
    CONTROLLERS=$(cat "$CGROUP_ROOT/cgroup.controllers")
    for controller in $CONTROLLERS; do
        echo "+$controller" | sudo tee "$ISOLATE_CGROUP/cgroup.subtree_control" > /dev/null 2>&1 || true
    done
fi

# Create isolate configuration file
# This explicitly tells isolate where to find its cgroup root
sudo tee /usr/local/etc/isolate > /dev/null <<EOF
# Isolate configuration for Judge0 with cgroup v2
box_root = /var/local/lib/isolate
lock_root = /run/isolate/locks
cg_root = $ISOLATE_CGROUP
first_uid = 60000
first_gid = 60000
num_boxes = 1000
EOF

# Set proper permissions
sudo chmod 755 /run/isolate
sudo chmod 755 /run/isolate/locks
sudo chmod 755 "$ISOLATE_CGROUP"
sudo chmod 644 /usr/local/etc/isolate

# Ensure box_root directory exists with proper permissions
sudo mkdir -p /var/local/lib/isolate
sudo chmod 755 /var/local/lib/isolate

# Start cron
sudo cron

exec "$@"
