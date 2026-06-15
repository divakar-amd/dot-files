
gpu_args="--device /dev/kfd --device /dev/dri --group-add video"
mount_dirs="-v /data/:/data -v ${HOME}/Projects/:/Projects -v /mnt/:/mnt/"
myscript_path="${HOME}/Projects/dot-files/custom_bash_cmds.sh"
claude_dir="${HOME}/.claude"

container_name=$1
image_name=${2:-"rocm/vllm-dev:nightly"}

if [ ! -f "${myscript_path}" ]; then
    echo "ERROR: Script file not found at ${myscript_path}"
    exit 1
fi

if [ ! -d "${claude_dir}" ]; then
    echo "WARNING: Claude directory not found at ${claude_dir}"
    echo "Claude Code will be installed without custom settings"
fi

# Create unique vLLM directory for this container
vllm_parent_dir="${HOME}/Projects/VLLM_DIR_CI"
current_date=$(date +%m-%d)
vllm_dir_name="vllm_${current_date}_${container_name}"
vllm_path="${vllm_parent_dir}/${vllm_dir_name}"

# Create parent directory if it doesn't exist
if [ ! -d "${vllm_parent_dir}" ]; then
    echo "Creating parent directory: ${vllm_parent_dir}"
    mkdir -p ${vllm_parent_dir}
fi

# Clone vLLM repository if this specific directory doesn't exist or is not a valid git repo
if [ ! -d "${vllm_path}/.git" ]; then
    if [ -d "${vllm_path}" ]; then
        echo "Directory exists but is not a git repository. Removing and cloning fresh..."
        rm -rf ${vllm_path}
    fi
    echo "Cloning vLLM repository to ${vllm_path}..."
    git clone https://github.com/vllm-project/vllm.git ${vllm_path}
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to clone vLLM repository"
        exit 1
    fi
else
    echo "Using existing vLLM directory: ${vllm_path}"
fi

# Add vLLM directory to mount_dirs
mount_dirs+=" -v ${vllm_path}:${vllm_path}"
mount_dirs+=" -v ${myscript_path}:/root/custom_bash_cmds.sh"

docker pull ${image_name}

# Read HuggingFace token from config file
hf_token_file="${HOME}/.config/huggingface/token"
if [ -f "${hf_token_file}" ]; then
    HF_TOKEN=$(cat "${hf_token_file}")
    env_vars="-e HF_TOKEN=${HF_TOKEN} -e HF_HOME=/data/models/hub"
    echo "HuggingFace token loaded from ${hf_token_file}"
else
    echo "WARNING: HuggingFace token not found at ${hf_token_file}"
    env_vars=""
fi

cmd="docker run --name ${container_name} -i -d  --network=host ${gpu_args} --cap-add=SYS_PTRACE --security-opt seccomp=unconfined ${mount_dirs} ${env_vars} --shm-size=16G --ulimit core=0 --ulimit memlock=-1 --ulimit stack=67108864 --entrypoint /bin/bash ${image_name}"
echo ${cmd}
${cmd}

# adding 'source ...' to .bashrc will source the script for every instance of shell
docker exec ${container_name} bash -c "echo \"source /root/custom_bash_cmds.sh\" >> /root/.bashrc"

# Copy Claude configuration directory if available
if [ -d "${claude_dir}" ]; then
    echo "Copying Claude configuration to container..."
    docker exec ${container_name} mkdir -p /root/.claude
    docker cp ${claude_dir}/. ${container_name}:/root/.claude/
    echo "Claude configuration directory copied successfully"
fi

# Copy .claude.json file if it exists (separate from the .claude directory)
if [ -f "${HOME}/.claude.json" ]; then
    echo "Copying .claude.json to container..."
    docker cp ${HOME}/.claude.json ${container_name}:/root/.claude.json
    echo ".claude.json copied successfully"
elif [ -d "${claude_dir}/backups" ]; then
    # If .claude.json doesn't exist but backups do, restore from the latest backup
    echo "Restoring .claude.json from backup..."
    docker exec ${container_name} bash -c "
        latest_backup=\$(ls -t /root/.claude/backups/.claude.json.backup.* 2>/dev/null | head -1)
        if [ -n \"\$latest_backup\" ]; then
            cp \"\$latest_backup\" /root/.claude.json
            echo \"Restored from \$latest_backup\"
        fi
    "
fi

# Install Claude Code in the container
echo "Installing Claude Code in container..."
docker exec ${container_name} bash -c "
  # Install curl if not available
  if ! command -v curl &> /dev/null; then
    apt-get update && apt-get install -y curl
  fi

  # Install Claude Code
  curl -fsSL https://claude.ai/install.sh | bash

  # Add ~/.local/bin to PATH and set Claude environment variables in .bashrc
  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> /root/.bashrc
  echo 'export CLAUDE_TRUST_WORKSPACE=1' >> /root/.bashrc
  echo 'export CLAUDE_AUTO_APPROVE_SETUP=1' >> /root/.bashrc
"

# Set up vLLM Python source to match container's compiled version
echo "Setting up vLLM source to match container version..."
docker exec ${container_name} bash -c "
  # Fix git permission issue for mounted directory
  git config --global --add safe.directory ${vllm_path}

  if [ -d ${vllm_path} ]; then
    # Get the exact commit hash from container's installed vLLM
    echo 'Detecting vLLM version in container...'
    VLLM_VERSION=\$(python -c 'import vllm; print(vllm.__version__)')
    echo \"Container vLLM version: \${VLLM_VERSION}\"

    # Try multiple methods to extract git commit hash
    # Method 1: Extract from __version__ string (format: 0.21.1rc1.dev42+g966903eb9)
    GIT_HASH=\$(echo \${VLLM_VERSION} | grep -oP 'g\K[0-9a-f]+')

    # Method 2: Check _version.py for commit_id
    if [ -z \"\${GIT_HASH}\" ]; then
      echo 'Trying fallback method to detect commit hash...'
      GIT_HASH=\$(python -c 'from vllm._version import commit_id; print(commit_id.lstrip(\"g\") if commit_id else \"\")' 2>/dev/null)
    fi

    if [ -z \"\${GIT_HASH}\" ]; then
      echo 'WARNING: Could not extract git hash from container'
      echo 'Skipping checkout. Your source may not match the container!'
    else
      echo \"Git commit hash: \${GIT_HASH}\"

      cd ${vllm_path}

      # Check if working directory is clean
      if [ -z \"\$(git status --porcelain)\" ]; then
        echo 'Fetching latest commits...'
        git fetch origin

        echo \"Checking out commit \${GIT_HASH}...\"
        git checkout \${GIT_HASH}

        if [ \$? -eq 0 ]; then
          echo 'Successfully synced source with container version!'
        else
          echo 'WARNING: Checkout failed. Your source may not match the container!'
        fi
      else
        echo 'WARNING: Working directory has uncommitted changes. Skipping checkout.'
        git status --short
        echo 'Your source may not match the container version!'
      fi
    fi

    # Set PYTHONPATH to prioritize mounted source (Python files only, uses pre-compiled extensions)
    echo 'export PYTHONPATH=${vllm_path}:\${PYTHONPATH}' >> /root/.bashrc
    echo ''
    echo '=== Setup Complete ==='
    echo 'Python source: ${vllm_path}'
    echo 'Compiled extensions: from container'
    echo 'Python file changes will be picked up immediately (no recompilation needed)!'
  else
    echo 'WARNING: vLLM directory not found at ${vllm_path}'
  fi
"

# Drop into interactive shell in the vLLM directory
docker exec -it -w ${vllm_path} ${container_name} bash
