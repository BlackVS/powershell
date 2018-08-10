$zones=Get-DnsServerZone | where {$_.IsReverseLookupZone -eq $true} | select -ExpandProperty ZoneName 
foreach($z in $zones){
    $zone=$z.replace(".in-addr.arpa","")
    $ips =$zone.split(".")
    [array]::Reverse($ips)
    $mask=$ips.Length
    $ips+=@("0")*(4-$mask)
    $addr=[string]::Join(".",$ips)
    $mask*=8
    "$z -> $addr/$mask"
}