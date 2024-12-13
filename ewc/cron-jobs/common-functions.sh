#!/bin/bash

# Function to check if a variable is set
check_var() {
  local var_name=$1
  local var_value=$2
  if [ -z "$var_value" ]; then
    echo "Error: $var_name is not set."
    exit 1
  fi
}

# Function to generate ISO 8601 compliant timestamp
generate_iso_8601_timestamp() {
  local timezone_offset=$(date +%z)
  local timestamp=$(date +%Y-%m-%dT%H:%M:%S)

  if [ "$timezone_offset" == "+0000" ]; then
    echo "${timestamp}Z"
  else
    # (need to use sed as couldn't make it work with '%:z' in date command)
    echo "${timestamp}$(echo $timezone_offset | sed 's/\(..\)$/:\1/')"
  fi
}