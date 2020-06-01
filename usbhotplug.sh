#!/bin/bash
action=$1
vmname="$2"
vendorid=$3
productid=$4
sleepon=false
timecheckfile="/root/usb-${vendorid}-${productid}"
#touch -a /root/runcheck

# Check if timecheck file exists
if [ -f "$timecheckfile" ]; then
	lastruntime=$(stat -c %X ${timecheckfile})
else
	lastruntime=0
fi

# Compare Last Time Device was Added/Removed
currenttime=$(date +%s)
timecheck=$(( ${currenttime} - ${lastruntime} ))
echo ${timecheck} >> /root/usbtimelog

# Check if Device is already attached to VM
devcheck=$(/usr/sbin/virsh dumpxml ${vmname} | grep -A1 -e "<vendor id='0x"${vendorid}"'/>" | grep -c -e "<product id='0x"${productid}"'/>")

# Remove All Instances of Device
removeDevice () {
	maxloop=5
	while [ ${devcheck} -gt 0 ]; do
		if [ ${maxloop} -gt 0 ]; then
			/usr/sbin/virsh detach-device ${vmname} /etc/libvirt/qemu/USB/usb-${vendorid}-${productid}.xml 2>&1 | while read line; do echo "[$(date '+%Y-%m-%d %H:%M:%S')]  $line" >> /root/usbhotplug.log; done;
			((--maxloop))
			sleep 2
		else
			break
		fi
	done
}

# Add Device Function
addDevice () {
	/usr/sbin/virsh attach-device ${vmname} /etc/libvirt/qemu/USB/usb-${vendorid}-${productid}.xml --current 2>&1 | while read line; do echo "[$(date '+%Y-%m-%d %H:%M:%S')]  $line" >> /root/usbhotplug.log; done;
}

# Main Code
if [ ${action} = 'add' ]; then
	if [ ${timecheck} -gt 2 ]; then
		touch -a ${timecheckfile}
		removeDevice
		addDevice
		sleepon=true
	else
		touch -a /root/usbattachnotrun
		exit 0
	fi
elif [ ${action} = 'remove' ]; then
	if [ ${timecheck} -gt 2 ]; then
		touch -a ${timecheckfile}
		removeDevice
	else
		touch -a /root/usbdetachnotrun
		exit 0
	fi
else
	echo "Incorrect or Missing Argument"
	exit 1
fi

if [ ${sleepon} = true ]; then
	sleep 2
fi
