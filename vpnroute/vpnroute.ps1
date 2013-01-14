$prog = $myinvocation.mycommand.name
$url_cnnic = "http://ipwhois.cnnic.cn/ipstats/detail.php?obj=ipv4&country=CN"
$url_dancefire = "http://www.dancefire.org/vpnroute.php"
$curdir = (get-location).path
$ipv4_html = join-path $curdir "cnnic_ipv4.html"
$ipv4_data = join-path $curdir "cnnic_ipv4.data"
$gateway = route print -4 | where { $_ -match "^\s+0.0.0.0\s+0.0.0.0" } | %{ $_ -replace '\s+', ' ' } | %{ $_.Split(" ")[3] }

function cidr-to-mask($cidr) {
	[string]$mask = ""
	$full_octets = $cidr/8
	$partial_octet = $cidr%8
	
	for ($i = 0; $i -lt 4; $i++) {
		$a = $full_octets - $i
		if (($a -gt 0) -and ($a -ge 1)) {
			$mask += "255"
		} elseif (($a -gt 0) -and ($a -lt 1)) {
			$mask += (256 - [math]::Pow(2,(8-$partial_octet)))
		} else {
			$mask += "0"
		}
		if ($i -lt 3) { $mask += "." }
	}
	return $mask
}

function get-cn-data {
	Write-Host "Downloading CN network data from CNNIC..."
	$webclient = new-object System.Net.WebClient
	$webclient.DownloadFile($url_dancefire, $ipv4_data)
	Write-Host "Done."
}

function check-data {
	if (!(test-path $ipv4_data)) {
		Write-Host "CN network data file [$ipv4_data] is not exist."
		get-cn-data
	}
}

function add-route-cn([bool]$permanent) {
	check-data

	$route_count = route print -4 | where { $_ -match "$gateway" } | measure-object
	if ($route_count > 1) {
		Write-Host "Routes already added, should be removed first."
		remove-route-cn
	}

	Write-Host "Adding routes of CN ..."
	Write-Host "Default gateway is $gateway"
	$count = 0
	foreach ($line in Get-Content $ipv4_data)
	{
		$item = $line.split("/")
		$net = $item[0]
		$cidr = $item[1]
		if (($cidr -ge 0) -and ($cidr -le 32))
		{
			$mask = cidr-to-mask($cidr)
			$opt = ""
			if ($permanent) {
				$opt = "-p"
			}
			route.exe add $opt $net mask $mask $gateway > null
			$count++
		}
	}
	Write-Host "Added $count networks."
	Write-Host "Done."
}

function remove-route-cn {
	check-data
	Write-Host "Removing routes of CN ..."
	$count = 0
	foreach ($line in Get-Content $ipv4_data)
	{
		$item = $line.split("/")
		$net = $item[0]
		$cidr = $item[1]
		if (($cidr -ge 0) -and ($cidr -le 32))
		{
			$mask = cidr-to-mask($cidr)
		}
		route delete $net mask $mask > null
		$count++
	}
	Write-Host "Removed $count networks."
	Write-Host "Done."
}

function usage {
	Write-Host "Route networks of CN to the default gateway instead of VPN tunnel"
	Write-Host ""
	Write-Host "usage: $prog {on|off|update}"
	Write-Host ""
	Write-Host "	on	Add routes of CN to default gateway"
	Write-Host "	once	Add routes of CN to default gateway. Only for this time, reboot the configure will be disappeared."
	Write-Host "	off	Remove routes of CN"
	Write-Host "	update	Download/update CN network data"
	Write-Host ""
}

switch($args[0]) {
	"on"		{	add-route-cn($true)	}
	"once"		{	add-route-cn($false)	}
	"off"		{	remove-route-cn		}
	"update"	{	get-cn-data		}
	default		{	usage			}
}
