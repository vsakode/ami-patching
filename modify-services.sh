#!/bin/sh

touch /etc/test1
/sbin/chkconfig messagebus on
for SERVICE in NetworkManager acpid anacron atd autofs avahi-daemon avahi-dnsconfd bluetooth conman cpuspeed cups dnsmasq dund firstboot gpm haldaemon hidd ip6tables ipmi iptables irda irqbalance kudzu lvm2-monitor mcstrans mdmonitor mdmpd messagebus multipathd netconsole netplugd nfs nscd pand pcscd
do
        /sbin/chkconfig $SERVICE off
done

