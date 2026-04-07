
gpu_args="--device /dev/kfd --device /dev/dri --group-add video" 
mount_dirs="-v /data/:/data -v ${HOME}/Projects/:/Projects -v /mnt/:/mnt/"
myscript_path="${HOME}/Projects/dot-files/custom_bash_cmds.sh"

image_name=$1
container_name=$2

if [ ! -f "${myscript_path}" ]; then
    echo "ERROR: Script file not found at ${myscript_path}"
    exit 1
fi

mount_dirs+=" -v ${myscript_path}:/root/custom_bash_cmds.sh"

docker pull ${image_name}

cmd="docker run --name ${container_name} -i -d  --network=host ${gpu_args} --cap-add=SYS_PTRACE --security-opt seccomp=unconfined ${mount_dirs} --shm-size=16G --ulimit core=0 --ulimit memlock=-1 --ulimit stack=67108864 --entrypoint /bin/bash ${image_name}"
echo ${cmd}
${cmd}

# adding 'source ...' to .bashrc will source the script for every instance of shell 
docker exec -it ${container_name} bash -c "echo \"source /root/custom_bash_cmds.sh\" >> /root/.bashrc &&  exec bash"
