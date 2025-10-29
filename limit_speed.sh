#!/bin/bash
set -e
source "$(dirname "$0")/config.env"

tc qdisc del dev "$AP_IF" root 2>/dev/null || true
tc qdisc add dev "$AP_IF" root handle 1: htb default 30
tc class add dev "$AP_IF" parent 1: classid 1:1 htb rate 10mbit
tc class add dev "$AP_IF" parent 1:1 classid 1:30 htb rate "$LIMIT_RATE" ceil "$LIMIT_RATE"
tc qdisc add dev "$AP_IF" parent 1:30 handle 30: sfq perturb 10
