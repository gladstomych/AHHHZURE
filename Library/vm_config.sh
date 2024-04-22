#!/bin/bash

# Create the flag file
echo "{AHHHZURE_FL4G_5_RELI_N33D_VM_EXECUT0R?}" > /home/ubuntu/flag5.txt

# Ensure the ubuntu user owns the flag file
chown ubuntu:ubuntu /home/ubuntu/flag5.txt

# Create the .bash_history file with more authentic-looking entries
{
    echo "sudo apt update && sudo apt upgrade -y"
    echo "sudo apt install net-tools azure-cli"
    echo "mkdir projects"
    echo "cd projects"
    echo "git clone https://github.com/Azure/Azure-Functions.git"
    echo "cd Azure-Functions"
    echo "ls -la"
    echo "clear"
    echo ""
    echo "asdfasdf"
    echo 'az login --user JohnDavis@$tenanturi -t $tenantid --password wwdH3kNmmhHoQr5SUmOwkKbRl12'
    echo "az ad signed-in-user show"
} > /home/ubuntu/.bash_history

# Ensure the ubuntu user owns the .bash_history file
chown ubuntu:ubuntu /home/ubuntu/.bash_history

# Set permissions to ensure that only the ubuntu user can read these files
chmod 600 /home/ubuntu/flag5.txt /home/ubuntu/.bash_history