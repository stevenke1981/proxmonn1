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

# 下載 Ubuntu 22.04 雲端映像檔
imagelink="https://cloud-images.ubuntu.com/jammy/current/$imagename"
wget -O $imagename $imagelink

# 設定 CPU type 為 host, 共 8(2x4) vcpu, 8GB memory, 網路使用 vmbr1(tag 1310, 此為我自己設定的 trunk bridge)
cpu_type="host"
sockets=1
cores=4
memory=8192
network_bridge="vmbr1"
network_tag=1310

# 創建虛擬機
qm create $vmid --name "$vm_name" --cpu $cpu_type --sockets $sockets --cores $cores --memory $memory --net0 virtio,bridge=$network_bridge,tag=$network_tag

# 將 cloud image 匯入到指定的 storage 作為虛擬機的第一個 disk
qm importdisk $vmid "$imagename" $storage_id

# 設定 VM 細節
# 設定 cloud-init 的功能以 cd-rom 的形式掛載
# serial 一定要加，否則 cloud image 會無法正常開機
qm set $vmid --scsi0 $storage_id:vm-$vmid-disk-0 --ide2 $storage_id:cloudinit --boot c --bootdisk scsi0 --serial0 socket

# 啟動虛擬機
qm start $vmid

echo "Ubuntu 22.04 VM $vm_name (ID: $vmid) has been created and started."
