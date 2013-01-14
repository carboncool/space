#!/bin/bash
LANG=C
PROG=$0
URL_CNNIC="http://ipwhois.cnnic.cn/ipstats/detail.php?obj=ipv4&country=CN"
IPV4_HTML=/tmp/cnnic_ipv4.html
IPV4_DATA=~/cnnic_ipv4.data
VPN_IF=`ip tuntap | cut -d ':' -f 1`

if [ -z "$VPN_IF" ] ; then
	VPN_IF="tun"
fi

GATEWAY=`route -n | grep -v "$VPN_IF" | grep UG | tr -s ' ' | cut -d ' ' -f 2`

if [ "`echo "$GATEWAY" | wc -l`" -gt "1" ] ; then
	ROUTE_ADDED=true
	GATEWAY=`echo "$GATEWAY" | head -n 1`
fi

GATEWAY_IF=`route -n | grep $GATEWAY | head -n 1 | tr -s ' ' | cut -d ' ' -f8`

IP_PROG=`which ip`

ROUTE_DIR_DEBIAN=/etc/network/if-up.d
ROUTE_FILE_DEBIAN=$ROUTE_DIR_DEBIAN/vpnroute

ROUTE_DIR_REDHAT=/etc/sysconfig/network-scripts
ROUTE_FILE_REDHAT=$ROUTE_DIR_REDHAT/route-$GATEWAY_IF

function get_cn_data() {
	echo "Downloading CN network data from CNNIC..."
	RE_PATTERN="s/^.*searchtext=\([./0-9]*\).*$/\1/"
	wget -O $IPV4_HTML $URL_CNNIC
	grep "whois.pl?" $IPV4_HTML | sed -e "$RE_PATTERN" > $IPV4_DATA
	chmod a+w $IPV4_HTML
	chmod a+w $IPV4_DATA
	echo "Done."
}

function check_data() {
	if [ ! -f $IPV4_DATA ]
	then
		echo "CN network data file [$IPV4_DATA] is not exist."
		get_cn_data
	fi
}

function add_route_cn() {
	check_data
	PERMANENT="$1"
	# Check whether the routes are already added
	if [ "$ROUTE_ADDED" == "true" ] ; then
		echo "Routes already added, should be removed first."
		remove_route_cn
		GATEWAY=`echo "$GATEWAY" | head -n 1`
	fi
	echo "Adding routes of CN ..."
	echo "Default gateway is $GATEWAY on dev $GATEWAY_IF"
	if [ "$PERMANENT" == "yes" ] ; then
		echo "Generating route config file for next boot. [$ROUTE_FILE_DEBIAN]"
		# Debian/Ubuntu
		if [ -d $ROUTE_DIR_DEBIAN ] ; then
			# Prepare ROUTE_FILE_DEBIAN header
			rm -f $ROUTE_FILE_DEBIAN
			echo "#!/bin/bash" >> $ROUTE_FILE_DEBIAN
			chmod a+x $ROUTE_FILE_DEBIAN
		fi
		# Redhat/Fedora
		if [ -d $ROUTE_DIR_REDHAT ] ; then
			# Use backup overwrite current file, otherwise backup the file
			if [ -x "$ROUTE_FILE_REDHAT.bak" ] ; then
				cp -f "$ROUTE_FILE_REDHAT.bak" "$ROUTE_FILE_REDHAT"
			else
				cp -f "$ROUTE_FILE_REDHAT" "$ROUTE_FILE_REDHAT.bak"
			fi
		fi
	fi

	count=0
	while read line
	do
		net=`echo "$line" | cut -d '/' -f1`
		cidr=`echo "$line" | cut -d '/' -f2`

		# generate ip route cmd
		ip_args="$net/$cidr via $GATEWAY"
		if [ "$PERMANENT" == "yes" ]
		then
			# Debian/Ubuntu
			if [ -d $ROUTE_DIR_DEBIAN ] ; then
				echo "$IP_PROG route add $ip_args" >> $ROUTE_FILE_DEBIAN
			fi
			# Redhat/Fedora
			if [ -d $ROUTE_DIR_REDHAT ] ; then
				echo "$ip_args" >> $ROUTE_FILE_REDHAT
			fi
		fi
		$IP_PROG route add $ip_args
		count=$(( $count + 1 ))
	done < $IPV4_DATA
	echo "Added $count networks."
	echo "Done."
}

function remove_route_cn() {
	check_data
	echo "Removing routes of CN ..."
	# Debian/Ubuntu
	if [ -x $ROUTE_FILE_DEBIAN ] ; then
		rm -f $ROUTE_FILE_DEBIAN
	fi
	# Redhat/Fedora
	if [ -x $ROUTE_FILE_REDHAT ] ; then
		# If the backup exist, then use backup overwrite current file, otherwise filter the file
		if [ -x "$ROUTE_FILE_REDHAT.bak" ] ; then
			mv -f $ROUTE_FILE_REDHAT.bak $ROUTE_FILE_REDHAT
		else
			cp -f $ROUTE_FILE_REDHAT $ROUTE_FILE_REDHAT.old
			sed "/ via $GATEWAY$/d" $ROUTE_FILE_REDHAT > $ROUTE_FILE_REDHAT.tmp
			mv -f $ROUTE_FILE_REDHAT.tmp $ROUTE_FILE_REDHAT
		fi
	fi

	count=0
	while read line
	do
		net=`echo "$line" | cut -d '/' -f1`
		cidr=`echo "$line" | cut -d '/' -f2`
		$IP_PROG route del $net/$cidr via $GATEWAY 2> /dev/null
		count=$(( $count + 1 ))
	done < $IPV4_DATA
	echo "Removed $count networks."
	echo "Done."
}

function usage() {
	echo "Route networks of CN to the default gateway instead of VPN tunnel"
	echo ""
	echo "usage: $PROG {on|off|update}"
	echo ""
	echo "	on	Add routes of CN to default gateway."
	echo "	once	Add routes of CN to default gateway. Only for this time, reboot the configure will be disappeared."
	echo "	off	Remove routes of CN"
	echo "	update	Force download/update CN network data"
	echo ""
}

case "$1" in
	"on")		add_route_cn yes	;;
	"once")		add_route_cn no		;;
	"off")		remove_route_cn		;;
	"update")	get_cn_data		;;
	*)		usage			;;
esac

