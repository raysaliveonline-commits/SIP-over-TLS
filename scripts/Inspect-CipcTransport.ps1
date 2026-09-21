# Read-only lab diagnostic. Does not reserve ports or change firewall/application state.
[CmdletBinding()]
param(
    [string[]]$CucmAddress = @('192.168.10.150', '192.168.10.151')
)

Write-Output 'TCP connections to CUCM (configuration, CAPF, SIP, SIP TLS)'
Get-NetTCPConnection -ErrorAction SilentlyContinue |
    Where-Object {
        $_.RemoteAddress -in $CucmAddress -and
        $_.RemotePort -in @(3804, 5060, 5061, 6970)
    } |
    ForEach-Object {
        $ownerProcess = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        [pscustomobject]@{
            LocalAddress = $_.LocalAddress
            LocalPort = $_.LocalPort
            RemoteAddress = $_.RemoteAddress
            RemotePort = $_.RemotePort
            State = $_.State
            ProcessId = $_.OwningProcess
            Process = $ownerProcess.ProcessName
        }
    } | Format-Table -AutoSize

Write-Output 'UDP 5060 owners (empty can be normal for the TLS phone)'
Get-NetUDPEndpoint -LocalPort 5060 -ErrorAction SilentlyContinue |
    ForEach-Object {
        $ownerProcess = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        [pscustomobject]@{
            LocalAddress = $_.LocalAddress
            LocalPort = $_.LocalPort
            ProcessId = $_.OwningProcess
            Process = $ownerProcess.ProcessName
        }
    } | Format-Table -AutoSize
