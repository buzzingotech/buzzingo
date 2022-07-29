Import-Module -Name $env:ProgramData\Syncro\bin\module

$wifi = Get-NetAdapter | Where-Object -Property Name -Like -Value "Wi-Fi"
$ethernet = Get-NetAdapter | Where-Object -Property Name -Like -Value "Ethernet"

if ($wifi -ne $null){
    $status = $wifi.Status
    if ($status -eq 'Disconnected' -or $status -eq 'Disabled'){
        $wifi | Restart-NetAdapter
        Broadcast-Message -Title "Wi-Fi disabled" -Message "Your Wi-Fi was disabled. Please make sure Airplane mode is turned off or contact support if you are still having connection issues:`n`nEmail:`nPhone:" -LogActivity "true"
    } else {
        $wifi | Restart-NetAdapter
        Write-Host 'Wi-Fi adapter restarted'
    }
} if ($ethernet -ne $null){
    $status = $ethernet.Status
    if ($status -eq 'Disconnected' -or $status -eq 'Disabled'){
        $ethernet | Restart-NetAdapter
        Broadcast-Message -Title "Ethernet disabled" -Message "Your Ethernet was disabled. Please contact support if you have still have connection issues:`n`nEmail:`nPhone:" -LogActivity "true"
    } else {
        Write-Host 'Ethernet adapter restarted'
    }
}