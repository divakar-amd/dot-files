
gpu_args="--device /dev/kfd --device /dev/dri --group-add video" 
mount_dirs="-v /data/:/data -v ${HOME}/Projects/:/Projects -v /mnt/:/mnt/"

image_name=$1
container_name=$2

docker pull ${image_name}

cmd="docker run --name ${container_name} -i -d  --network=host ${gpu_args} --cap-add=SYS_PTRACE --security-opt seccomp=unconfined ${mount_dirs} --shm-size=16G --ulimit core=0 --ulimit memlock=-1 --ulimit stack=67108864 ${image_name}"
echo ${cmd}
${cmd}

docker exec -it ${container_name} bash
