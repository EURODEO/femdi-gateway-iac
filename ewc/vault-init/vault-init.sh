#!/usr/bin/env/ bash

KUBECONFIG_PATH=$1
NAMESPACE=$2
REPLICA_STATUS=($3)
KEY_TRESHOLD=$4

INPUT=$(kubectl --kubeconfig "$KUBECONFIG_PATH" -n "$NAMESPACE" exec vault-jani-0 -- \
  vault operator init -t $KEY_TRESHOLD -format=json 2>&1)

if jq -e . > /dev/null 2>&1 <<<"$INPUT"; 
then
  replica_index=0
  for status in "${REPLICA_STATUS[@]}"; do
    # If pod not ready, unseal it
    if [ "$status" == "False" ]; then
      for (( i=0; i<$KEY_TRESHOLD; i++ ))
      do
        kubectl --kubeconfig "$KUBECONFIG_PATH"  -n "$NAMESPACE" \
          exec vault-jani-"$replica_index" -- \
          vault operator unseal "$(jq -r ".unseal_keys_b64["$i"]" <<< $INPUT)" > /dev/null
      done
    # Sleep for raft auto join
    sleep 1
    fi
    ((replica_index++))
  done
  jq -n \
    --arg keys "$(jq -r '.unseal_keys_b64 | join(",")' <<< "$INPUT")" \
    --arg token "$(jq -r '.root_token' <<< "$INPUT")" \
  '{
    "flattened_unseal_keys_b64": $keys,
    "root_token": $token
  }'
else
  jq -n '{}'
fi
