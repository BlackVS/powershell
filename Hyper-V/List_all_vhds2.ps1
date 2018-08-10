$VMs = Get-VM
Foreach ($VM in $VMs)
{
  Write-Output ""
  Write-Output $VM.VMName
  $HardDrives = $VM.HardDrives
  Foreach ($HardDrive in $HardDrives)
  {
    Write-Output $HardDrive.path
  }
}