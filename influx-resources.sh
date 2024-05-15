#!/bin/bash

# if cpu over 90% exit monitoring script
cpu=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else print ($2+$4-u1) * 100 / (t-t1) ; }' \
<(grep 'cpu ' /proc/stat) <(sleep 1;grep 'cpu ' /proc/stat))
if [ 1 -eq "$(echo "$cpu > 90.0" | bc)" ]; then exit 0; fi

# Environment setup
export PATH=$PATH:$HOME/.local/bin
base_dir="/var/safenode-manager/services"

# Define the current time for the current date
current_date=$(date '+%Y-%m-%dT')

# Current time for influx database entries
influx_time="$(date +%s%N | awk '{printf "%d0000000000\n", $0 / 10000000000}')"
time_min=$(date +"%M")

# Counters
total_rewards_balance=0
total_nodes_running=0
total_nodes_killed=0

# Arrays
declare -A dir_pid
declare -A dir_peer_ids
declare -A node_numbers
declare -A node_details_store

# Fetch node overview from node-manager
safenode-manager status --details > /tmp/influx-resources/nodes_overview
if [ $? -ne 0 ]; then
    echo "Failed to get node overview from safenode-manager."
    exit 1
fi

# Process nodes
for dir in "$base_dir"/*; do
    if [[ -f "$dir/safenode.pid" ]]; then
        dir_name=$(basename "$dir")
        dir_pid["$dir_name"]=$(cat "$dir/safenode.pid")
        node_number=${dir_name#safenode}
        node_numbers["$dir_name"]=$node_number
        node_details=$(grep -A 12 "$dir_name - " /tmp/influx-resources/nodes_overview)

        # Skip if node status is ADDED
        if [[ $node_details == *"- ADDED"* ]]; then
            continue
        fi

        if [[ $node_details == *"- RUNNING"* ]]; then
            total_nodes_running=$((total_nodes_running + 1))
            status=TRUE
        else
            total_nodes_killed=$((total_nodes_killed + 1))
            status=FALSE
        fi

        peer_id=$(echo "$node_details" | grep "Peer ID:" | awk '{print $3}')
        dir_peer_ids["$dir_name"]="$peer_id"
        rewards_balance=$(echo "$node_details" | grep "Reward balance:" | awk '{print $3}')
        total_rewards_balance=$(echo "scale=10; $total_rewards_balance + $rewards_balance" | bc -l)

        # Format for InfluxDB
        node_details_store[$node_number]="nodes,id=$dir_name,peer_id=$peer_id status=$status,pid=${dir_pid[$dir_name]}i,records=$(find "$dir/record_store" -type f | wc -l)i,rewards=$rewards_balance $influx_time"
    fi
done

# Sort
for num in $(echo "${!node_details_store[@]}" | tr ' ' '\n' | sort -n); do
    echo "${node_details_store[$num]}"
done

# Output
echo "nodes_totals rewards=$total_rewards_balance,nodes_running="$total_nodes_running"i,nodes_killed="$total_nodes_killed"i $influx_time"

# Latency
latency=$(ping -c 4 8.8.8.8 | tail -1| awk '{print $4}' | cut -d '/' -f 2)
echo "nodes latency=$latency $influx_time"

# Grep for "us as BAD" in the logs from the last 24 hours and count occurrences
bad_occurrences=$(grep -r "$current_date" /var/log/safenode/ | grep "us as BAD" | wc -l)

# Print the result to influx
echo "nodes_errors us_as_BAD_count="$bad_occurrences"i $influx_time"

# Calculate total storage of the node services folder
total_disk=$(echo "scale=0;("$(du -s "$base_dir" | cut -f1)")/1024" | bc)
echo "nodes_totals total_disk="$total_disk"i $influx_time"

fi
