param(
    [Parameter(Position = 0)]
    [string]$Adapter,

    [Parameter(Position = 1)]
    [string]$Setting,

    [Parameter(Position = 2)]
    [string]$NetMask = "255.255.255.0",

    [Parameter(Position = 3)]
    [string]$Gateway = "none"
)

$currentFile = Split-Path $PSCommandPath -Leaf

if (-not $Adapter -and -not $Setting) {
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\$currentFile <adapter> Dhcp"
    Write-Host "  .\$currentFile <adapter> <IPv4 address>"
    Write-Host ""
    Write-Host "Available network interfaces:"
    Get-NetAdapter | Format-Table Name, Status, InterfaceDescription -AutoSize
    exit 0
}

if (-not $Adapter -or -not $Setting) {
    Write-Error "Specify both an adapter name and Dhcp or an IPv4 address."
    exit 1
}

$interface = Get-NetAdapter | Where-Object { $_.Name -eq $Adapter }
if (-not $interface) {
    Write-Error "Adapter '$Adapter' was not found. Run without arguments to list adapters."
    exit 1
}

$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    Write-Error "Run PowerShell as Administrator to change network settings."
    exit 1
}

if ($Setting -eq "Dhcp") {
    & netsh interface ipv4 set address "name=$Adapter" source=dhcp
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & netsh interface ipv4 set dnsservers "name=$Adapter" source=dhcp
    if ($LASTEXITCODE -ne 0) {
        Write-Error "IP settings changed, but enabling DHCP for DNC failed"
        exit $LASTEXITCODE
    }

    Write-Host "DHCP enabled for IPv4 and DNS on '$Adapter'."
}
else {
    $ip = $null
    if (-not [System.Net.IPAddress]::TryParse($Setting, [ref]$ip) -or
    $ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        Write-Error "'$Setting' is not a valid IPv4 address nor Dhcp."
        exit 1
    }

    & netsh interface ipv4 set address "name=$Adapter" source=static "address=$($ip.IPAddressToString)" `
        mask=$NetMask gateway=$Gateway
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host "Static IPv4 address $ip set for $Adapter with net mask $NetMask and gateway $Gateway."
}

Write-Host ""