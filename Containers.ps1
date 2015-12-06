param(
    #
    # Create, Boot, Cease, Delete
    #
    [string]
    $Method,
    #
    # Container, Image
    #
    [string]
    $Object,

    $ContainerId,

    [int]
    $UserId,

    [string]
    $ContainerName,

    [string]
    $ContainerImageName,

    [string]
    $ContainerImageVersion,

    [string]
    $Password
)
$global:SwitchName = "Virtual Switch"
$global:ContainerNAT = "ContainerNAT"


function
Activate-Administrator
{
    param(
        [ValidateNotNullOrEmpty()]
        $ContainerId,
        [string]
        $Password = "Zettage321"
    )

    #
    # Get the container
    #
    $Container = Get-Container | ? ContainerId -EQ $ContainerId

    if ($Container)
    {
        Start-Container -Container $Container
        
        Invoke-Command -ContainerId $ContainerId -ScriptBlock {net user administrator Zettage321} -RunAsAdministrator
        
        Invoke-Command -ContainerId $ContainerId -ScriptBlock {net user administrator /active:yes} -RunAsAdministrator

        $IP = Invoke-Command -ContainerId $ContainerId -ScriptBlock {((ipconfig|findstr "IPv4") -split ": ")[1]}

        Invoke-Command -ContainerId $ContainerId -ScriptBlock {Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' | Set-ItemProperty -Name SecurityLayer -Value 1} -RunAsAdministrator

        $Mapping = Get-NetNatStaticMapping | ? InternalIPAddress -EQ $IP | ? InternalPort -EQ 3389
    
        if (!$Mapping)
        {
            $ExternalPort = Get-AvailablePort

            Add-NetNatStaticMapping -NatName $global:ContainerNAT -Protocol TCP -ExternalPort $ExternalPort -ExternalIPAddress 0.0.0.0 -InternalPort 3389 -InternalIPAddress $IP
        }
        
        Stop-Container -Container $Container
    }
    else
    {
        throw "There is no such container. Please check it."
    }
}


function
Create-Container
{
    param(
        [ValidateNotNullOrEmpty()]
        [int]
        $UserId,
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        [ValidateNotNullOrEmpty()]
        [string]
        $ContainerImageName,
        [string]
        $Password
    )

    $Container = New-Container -Name $Name -ContainerImageName $ContainerImageName -SwitchName $global:SwitchName
    
    $ContainerId = $Container.ContainerId
    
    Activate-Administrator -ContainerId $ContainerId -Password $Password

    Write-Output (ConvertTo-Json -InputObject @{"ContainerId" = $ContainerId})
}

function
Boot-Container
{
    param(
        [ValidateNotNullOrEmpty()]
        $Id
    )

    $Container = Get-Container | ? Id -EQ $Id

    if (!$Container)
    {
        throw "There is no such container"
    }

    if ($Container.State -ne "Running")
    {
        Start-Container -Container $Container
    }
}

function
Inspect-Container()
{
    param(
        $Id
    )
    $LocalIP = [System.Net.Dns]::GetHostAddresses('') | select -ExpandProperty IPAddressToString | findstr "192.168.1.*"
    if ($Id)
    {        
        if ((Get-Container -Id $Id).State -ne "Running")
        {
            Boot-Container -Id $Id
        }
        
        $IP = Invoke-Command -ContainerId $Id -ScriptBlock {[System.Net.Dns]::GetHostAddresses('') | select -ExpandProperty IPAddressToString | findstr "172.16.*.*"}
        $ExternalPort = (Get-NetNatStaticMapping | ? InternalIPAddress -EQ $IP | ? InternalPort -EQ 3389).ExternalPort
        $Container = ConvertTo-Json -InputObject (Get-Container -Id $Id)
        $Container | Add-Member -Name "HostIP" -Value $LocalIP -MemberType NoteProperty
        $Container | Add-Member -Name "HostPort" -Value $ExternalPort -MemberType NoteProperty
        $data = ConvertTo-Json -InputObject $Container
    }
    else
    {
        $Containers = Get-Container
        $data = "["
        foreach ($Container in $Containers)
        {
            $ExternalPort = (Get-NetNatStaticMapping | ? InternalIPAddress -EQ $c.Id | ? InternalPort -EQ 3389).ExternalPort
            $tmp = ConvertTo-Json -InputObject $Container
            $tmp | Add-Member -Name "HostIP" -Value $LocalIP -MemberType NoteProperty
            $tmp | Add-Member -Name "HostPort" -Value $ExternalPort -MemberType NoteProperty
            $json = ConvertTo-Json -InputObject $tmp
            $data = $data + $json + ','
        }
        $data = $data.Substring(0, $data.Length-1)+"]"
    }

    Write-Output $data
}

function
Get-AvailablePort()
{
    for ($Port = 3390; $Port -le 65535; $Port++)
    {
        if ((Test-PortAvailable -Port $Port) -and ($Port -notin (Get-NetNatStaticMapping).ExternalPort))
        {
            return $Port
        }
    }
    throw "There is no available port."
}


function
Test-PortAvailable
{
    param(
        [ValidateRange(1,65535)]
        [int]
        $Port
    )
    $sockt=New-Object System.Net.Sockets.Socket -ArgumentList 'InterNetwork','Stream','TCP'
    $ip = (Get-NetIPConfiguration).IPv4Address | select -First 1 -ExpandProperty IPAddress
    $ipAddress = [ipaddress]::Parse($ip)
    try
    {
        $ipEndpoint = New-Object System.Net.IPEndPoint $ipAddress,$Port
        $sockt.Bind($ipEndpoint)
        return $true
    }
    catch [System.Exception]
    {
        return $false
    }
    finally
    {
        $sockt.Close()
    }
}

function
Cease-Container
{
    param(
        [ValidateNotNullOrEmpty()]
        $Id
    )

    $Container = Get-Container | ? Id -EQ $Id

    if ($Container)
    {
        if ($Container.State -eq "Running"){

            Stop-Container -Container $Container -TurnOff
        }
    }
    else
    {
        throw "There is no such container. Please check it."
    }
}

function
Delete-Container
{
    param(
        [ValidateNotNullOrEmpty()]
        $Id
    )

    $Container = Get-Container | ? Id -EQ $Id

    if ($Container)
    {
        if ($Container.State -ne "Running")
        {
            Start-Container -Container $Container
        }
        $IP = Invoke-Command -ContainerId $ContainerId -ScriptBlock {((ipconfig|findstr "IPv4") -split ": ")[1]}
        Stop-Container -Container $Container -TurnOff
        Remove-Container -Container $Container -Force:$true
        $Mapping = Get-NetNatStaticMapping | ? InternalIPAddress -EQ $IP
        if (!$Mapping)
        {
            Remove-NetNatStaticMapping -StaticMappingID $Mapping.StaticMappingID
        }
        Write-Output (ConvertTo-Json -InputObject @{"ContainerId" = $Id})
    }
    else
    {
        throw "There is no container named $ContainerName. Please check it."
    }
}


if ($Object -eq 'Container')
{
    switch ($Method)
    {
        'Create'   {Create-Container -UserId $UserId -Name $ContainerName -ContainerImageName $ContainerImageName -Password $Password}
        'Start'    {Boot-Container -Id $ContainerId}
        'Inspect'  {Inspect-Container -Id $ContainerId}
        'Stop'     {Cease-Container -Id $ContainerId}
        'Delete'   {Delete-Container -Id $ContainerId}
        default    {throw "Unexpected method."}
    }
}