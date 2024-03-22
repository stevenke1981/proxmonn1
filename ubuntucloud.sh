#!/bin/bash

# 檢查是否為 root 用戶
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# 提示輸入期望的 vmid 範圍(1-999)
read -p "Enter the desired vmid range (1-999): " vmid_range

# 提示輸入虛擬機名稱
read -p "Enter a name for the new VM: " vm_name

# 預設映像檔名稱
imagename="jammy-server-cloudimg-amd64.img"

# 預設儲存池 ID
storage_id="local-lvm"

# 在指定範圍內找到一個可用的 vmid
for ((i=$vmid_range; i<1000; i++)); do
  vmid=$(qm status $i 2>/dev/null | grep -w $i)
  if [ -z "$vmid" ]; then
    vmid=$i
    break
  fi
done

# 如果在範圍內沒有找到可用的 vmid，則退出
if [ -z "$vmid" ]; then
  echo "No available vmid found in the specified range."
  exit 1
fi

# 檢查映像檔是否存在
if [ -f "$imagename" ]; then
  echo "Found existing $imagename, using it."
else
  # 下載 Ubuntu 22.04 雲端映像檔
  wget "https://cloud-images.ubuntu.com/jammy/current/$imagename"
fi

# 檢查 qcow2 格式的映像檔是否存在
qcow2_image="${imagename%.img}.qcow2"
if [ -f "$qcow2_image" ]; then
  echo "Found existing $qcow2_image, using it."
else
  # 轉換為 qcow2 格式
  qemu-img convert -f raw -O qcow2 "$imagename" "$qcow2_image"
fi

# 使用指定的 vmid 創建虛擬機
qm create $vmid --name "$vm_name" --memory 2048 --net0 virtio,bridge=vmbr0

# 將 qcow2 格式的映像檔導入到存儲池
qm importdisk $vmid "$qcow2_image" $storage_id

# 設定虛擬機硬碟設備以及開機設置
qm set $vmid --scsi0 $storage_id:vm-$vmid-disk-0
qm set $vmid --boot c

# 設定虛擬機網路
qm set $vmid --ipconfig0 ip=dhcp

# 允許 VRDE (虛擬機遠端桌面連線)
qm set $vmid --vga qxl
qm set $vmid --machine pc-q35-5.2

# 啟動虛擬機
qm start $vmid

echo "Ubuntu 22.04 VM $vm_name (ID: $vmid) has been created and started with a 32GB virtual disk."