#!/bin/bash

install_arch() {
	echo -n "Hostname: "
	read hostname
	: "${hostname:?"Missing hostname"}"

	echo -n "Root password: "
	read -s root_password
	echo

	echo -n "Repeat root password: "
	read -s root_password2
	echo

	[[ "$root_password" == "$root_password2" ]] || { echo "Passwords did not match"; exit 1; }

	echo -n "Username: "
	read username

	echo -n "Password: "
	read -s password
	echo

	echo -n "Repeat password: "
	read -s password2
	echo

	[[ "$password" == "$password2" ]] || { echo "Passwords did not match"; exit 1; }


	lsblk
	echo -n "Enter the disk to partition (e.g., /dev/nvme0n1): "
	read disk
	: "${disk:?"Disk has not been selected"}"
	cfdisk $disk

	lsblk
	echo "Enter your EFI partition (e.g. /dev/nvme0n1p1): "
	read efi_part

	echo "Enter your ROOT partition (e.g. /dev/nvme0n1p2): "
	read root_part

	echo "Enter your SWAP partition (e.g. /dev/nvme0n1p3): "
	read swap_part

	mkfs.fat -F 32 $efi_part
	mkfs.ext4 $root_part
	mkswap $swap_part
	swapon $swap_part

	mount $root_part /mnt
	mkdir -p /mnt/boot
	mount $efi_part /mnt/boot

	if systemd-detect-virt -q; then
		ucode=""
	elif grep -q "GenuineIntel" /proc/cpuinfo; then
		ucode="intel-ucode"
	elif grep -q "AuthenticAMD" /proc/cpuinfo; then
		ucode="amd-ucode"
	else
		ucode=""
	fi

	pacstrap -K /mnt base linux linux-firmware networkmanager neovim alacritty git curl firefox base-devel sudo efibootmgr grub pipewire wireplumber pipewire-pulse ly hyprland $ucode

	genfstab -U /mnt >> /mnt/etc/fstab

	arch-chroot /mnt /bin/bash <<EOF

	echo "$hostname" > /etc/hostname
	# FIX: Added the | pipe here
	echo "root:$root_password" | chpasswd
	useradd -m -G wheel -s /bin/bash $username
	echo "$username:$password" | chpasswd
	sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

	ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
	hwclock --systohc

	sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
	locale-gen
	echo "LANG=en_US.UTF-8" > /etc/locale.conf

	grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
	grub-mkconfig -o /boot/grub/grub.cfg

	systemctl enable ly
	systemctl enable NetworkManager

	EOF


	umount -R /mnt
	echo "Arch Linux installation complete. Type 'reboot' and remove your installation media."
}

install_arch
