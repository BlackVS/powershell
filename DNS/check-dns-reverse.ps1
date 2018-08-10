#Requires -Version 3

<# 
  .SYNOPSIS  
    Check reverse DNS for wring IP addresses in a range 
  .EXAMPLE 
   Check-DNS-Reverse -start 192.168.8.2 -end 192.168.8.20 
  .EXAMPLE 
   Check-DNS-Reverse -ip 192.168.8.2 -mask 255.255.255.0 
  .EXAMPLE 
   Check-DNS-Reverse -ip 192.168.8.3 -cidr 24 
#> 
 
param 
( 
  [string]$start, 
  [string]$end,
  [string]$ip,
  [string]$mask, 
  [int]$cidr 
) 
begin {
 
    function IP-toINT64 () { 
      param ($ip) 
      $octets = $ip.split(".") 
      return [int64]([int64]$octets[0]*16777216 +[int64]$octets[1]*65536 +[int64]$octets[2]*256 +[int64]$octets[3]) 
    } 
 
    function INT64-toIP() { 
      param ([int64]$int) 
      return (([math]::truncate($int/16777216)).tostring()+"."+([math]::truncate(($int%16777216)/65536)).tostring()+"."+([math]::truncate(($int%65536)/256)).tostring()+"."+([math]::truncate($int%256)).tostring() )
    } 
	
    function Get-DnsHostname ($IPAddress) {
		try {
			@(Resolve-DnsName $IPAddress -DnsOnly -QuickTimeout -ErrorAction SilentlyContinue 2>$null | select -ExpandProperty NameHost)
		} catch {
			$false
		}
	}
	
    function Get-DnsIP ($hostname) {
		try {
			@(Resolve-DnsName $hostname -DnsOnly -QuickTimeout -ErrorAction SilentlyContinue 2>$null | select -ExpandProperty IPAddress)	    } catch {
			$false
		}
	}

    function Test-Ping ($ComputerName) {
		$Result = ping $Computername -n 2
		if ($Result | where { $_ -match 'Reply from ' }) {
			$true
		} else {
			$false
		}
	}
	
	function Get-Computername ($IpAddress) {
		try {
			& $NbtScanFilePath $IpAddress 2> $null | where { $_ -match "$NetbiosDomainName\\(.*) " } | foreach { $matches[1].Trim() }
		} catch {
			Write-Warning -Message "Failed to get computer name for IP $IpAddress"
			$false
		}
	}
}
process {

    $verbose=$VerbosePreference -eq 'Continue'
    $paramsCount=$args.Count+$PSBoundParameters.Count
    if($paramsCount -eq 0) {
        Get-Help $MyInvocation.MyCommand.Definition -detailed
        return
    }

    try {
        if ($ip) {
         $ipaddr = [Net.IPAddress]::Parse($ip)
        } 
        if ($cidr) {$maskaddr = [Net.IPAddress]::Parse((INT64-toIP -int ([convert]::ToInt64(("1"*$cidr+"0"*(32-$cidr)),2)))) } 
        if ($mask) {$maskaddr = [Net.IPAddress]::Parse($mask)} 
        if ($ip) {$networkaddr = new-object net.ipaddress ($maskaddr.address -band $ipaddr.address)} 
        if ($ip) {$broadcastaddr = new-object net.ipaddress (([system.net.ipaddress]::parse("255.255.255.255").address -bxor $maskaddr.address -bor $networkaddr.address))} 
 
        if ($ip) { 
          $startaddr = IP-toINT64 -ip $networkaddr.ipaddresstostring 
          $endaddr = IP-toINT64 -ip $broadcastaddr.ipaddresstostring 
        } else { 
          $startaddr = IP-toINT64 -ip $start 
          $endaddr = IP-toINT64 -ip $end 
        } 
 

        Write-Host("Start DNS reverse health check...`n") 
        $fcnt=0
        for ($i = $startaddr; $i -le $endaddr; $i++) {
            $addr = INT64-toIP -int $i
            $hostnames=Get-DnsHostname($addr)
            $fOk=$false
            $fChecked=$false
            $ipCnt=0
            foreach($hostname in $hostnames){
                $fChecked=$true
                $ips=Get-DnsIP($hostname)

                foreach($ip in $ips){
                    $f=$ip -eq $addr
                    $fOk=$fOk -or $f
                    ++$ipCnt
                }
            }
            if($fChecked -and -not $fOk){
               if ($ipcnt -eq 0){
                    Write-Output("WARNING: No A (forward) record")
                    Write-Output("REVERSE: $addr -> $hostname")
                    Write-Output("FORWARD: $hostname -> X")
		    Write-Output("")
               } else {
                    Write-Output("WARNING: A and PTR are not the same")
                    Write-Output("REVERSE: $addr -> $hostname")
                    Write-Output("FORWARD: $hostname -> $ips")
		    Write-Output("")
               }
               ++$fcnt
            }
        }
        Write-Host("$fcnt ambiguities found")
    } catch {
		Write-Error $_.Exception.Message
	}
}