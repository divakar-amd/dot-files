### ---- Custom Commands ---- ###


# Dumps the outuput logs of a cmd to a file
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

# stops and removes a list of containers
# usage:
#    dstoprm <container_1> <container_2> ...
dstoprm() {
    for container in "$@"; do docker stop "$container" && docker rm "$container"; done;
}
