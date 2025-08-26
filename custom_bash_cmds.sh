 #!/bin/bash

# logrun function
# Usage:
#     logrun <name_of_log_file.txt> <cmd>
logrun() {
  logfile="$1"
  shift
  echo "$@" | tee "$logfile"
  "$@" 2>&1 | tee -a "$logfile"
}

# greet function
greet() {
  echo "Hello, $1!"
}


