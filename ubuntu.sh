#!/bin/bash

# 判斷是否為 root 使用者
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# 設定虛擬機器名稱
read -p "Enter a name for the new VM: " vm_name

# 建立虛擬機器
qm create $vm_name --memory 2048 --net0 virtio,bridge=vmbr0

# 導入 Ubuntu 22.04 雲端映像檔
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# 將雲端映像檔設為虛擬機器的虛擬硬碟
qm importdisk $vm_name jammy-server-cloudimg-amd64.img local-zfs

# 設定虛擬機器啟動時從雲端映像檔開機
qm set $vm_name --scsi0 local-zfs:vm-$vm_name-disk-0.qcow2

# 設定虛擬機器網路
qm set $vm_name --ipconfig0 ip=dhcp

# 允許 VRDE (虛擬機器遠端桌面連線)
qm set $vm_name --vga qxl
qm set $vm_name --machine pc-q35-5.2

# 啟動虛擬機器
qm start $vm_name

echo "Ubuntu 22.04 VM $vm_name has been created and started."
