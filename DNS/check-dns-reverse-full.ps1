#Requires -Version 3

<# 
  .SYNOPSIS  
   Check reverse DNS zones 
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

    function IPcalc_arpa2ip($arpa) {
        $zone=$arpa.replace(".in-addr.arpa","")
        $ips =$zone.split(".")
        [array]::Reverse($ips)
        $mask=$ips.Length
        $ips+=@("0")*(4-$mask)
        $addr=[string]::Join(".",$ips)
        $mask*=8
        @{Arpa=$arpa;IPAddress=$addr;Mask=$mask}
    }

    Function Write-Log
    {
        Param([string]$file, [string]$logstring)
        if ($log) {
            #Write-Host("$file : $logstring")
            Add-content $file -value $logstring
        } else {
            Write-Output($logstring)
        }
    }

    function Check-DNSZone {
        param( 
            [string] $zone, 
            [string] $log 
        )
        try {
            #Write-Log $log "Start DNS reverse zone $ip/$cidr health check...`n"
            $fcnt=0
            $recs=Get-DnsServerResourceRecord -ZoneName $zone -RRType "PTR"
            foreach($r in $recs){
                $name=$r.RecordData.PtrDomainName
                $arpa="$($r.HostName).$zone"
                $ips=IPcalc_arpa2ip($arpa)
                $addr=$ips.IPAddress
                #Write-Host("$arpa : $name : $addr")
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
                        Write-Log $log "WARNING: No A (forward) record"
                        Write-Log $log "REVERSE: $addr -> $hostname"
                        Write-Log $log "FORWARD: $hostname -> X"
		                Write-Log $log ""
                   } else {
                        Write-Log $log "WARNING: A and PTR are not the same"
                        Write-Log $log "REVERSE: $addr -> $hostname"
                        Write-Log $log "FORWARD: $hostname -> $ips"
        		        Write-Log $log ""
                   }
                   ++$fcnt
                }            }
            $fcnt
        } catch {
		    Write-Error $_.Exception.Message
            -1
	    }
    }
}

process {

    #$verbose=$VerbosePreference -eq 'Continue'
    #$paramsCount=$args.Count+$PSBoundParameters.Count
    #if($paramsCount -eq 0) {
    #    Get-Help $MyInvocation.MyCommand.Definition -detailed
    #    return
    #}

    $zones=Get-DnsServerZone | where {$_.IsReverseLookupZone -eq $true} | select -ExpandProperty ZoneName 
    foreach($z in $zones){
        Write-Output("Checking zone $z :")
        Write-Output($z.GetType())
        $ip=IPcalc_arpa2ip($z)
        $addr=$ip.IPAddress
        $cidr=$ip.Mask
        $log="$z.log"
        Write-Output(" writing results  to $log")
        if($log) { Set-Content $log "Zone $z :`n`r" }
        #" $addr/$cidr"
        $res=Check-DNSZone -zone $z -log $log
        Write-Output(" $res ambiguities found`n`r")
        Write-Log $log "$res ambiguities found"
        #break
    }

}