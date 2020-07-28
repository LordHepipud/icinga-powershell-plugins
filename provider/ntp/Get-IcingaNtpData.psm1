function Get-IcingaNtpData()
{
    param (
        [string]$Server,
        [int]$Port      = 123,
        $TimeOffset     = 0,
        [int]$Timeout   = 10,
        [switch]$IPV4   = $FALSE
    );

    if ([string]::IsNullOrEmpty($Server)) {
        Exit-IcingaThrowException -ExceptionType 'Configuration' `
            -ExceptionThrown $IcingaExceptions.Configuration.PluginArgumentMissing `
            -CustomMessage 'Plugin argument "-Server" is empty' `
            -Force;
    }

    $StartOfEpoch = New-Object -TypeName DateTime -ArgumentList ( 
        1900, 1, 1, 0, 0, 0, [DateTimeKind]::Utc
    );

    # A 48-byte client NTP time packet to send to the specified server
    [Byte[]]$NtpData = ,0 * 48;

    # Request Header: [00=No Leap Warning; 011=Version 3; 011=Client Mode]; 00011011 = 0x1B
    $NtpData[0] = 0x1B;
    $Socket     = New-Object -TypeName Net.Sockets.Socket -ArgumentList (
        [Net.Sockets.AddressFamily]::InterNetwork,
        [Net.Sockets.SocketType]::Dgram,
        [Net.Sockets.ProtocolType]::Udp
    );

    $Socket.SendTimeOut    = ($Timeout * 1000.0);
    $Socket.ReceiveTimeOut = ($Timeout * 1000.0);

    try {
        $Socket.Connect($Server, $Port);
    } catch [System.Net.Sockets.SocketException] {
        Exit-IcingaThrowException -ExceptionType 'Custom' -CustomMessage 'ConnectionError' -InputString (
            [string]::Format(
                'Failed to connect to the provided server "{0}":{1}{2}',
                $Server,
               (New-IcingaNewLine),
               $_
            )
        ) -Force;
    }

    # Get time before sending a packet to the ntp server
    $StartDate = Get-Date;

    try {
        [Void]$Socket.Send($NtpData);
        [Void]$Socket.Receive($NtpData);
    } catch [System.Net.Sockets.SocketException] {
        Exit-IcingaThrowException -ExceptionType 'Custom' -CustomMessage 'ConnectionError' -InputString (
            [string]::Format(
                'Failed to communicate with the provided server "{0}".{1}{2}',
                $Server,
                (New-IcingaNewLine),
                $_
            )
        ) -Force;
    }

    # Get Time After receiving a packet from the ntp server
    $EndDate = Get-Date;

    $Socket.Shutdown('Both');
    $Socket.Close();
    $Socket.Dispose();

    $TimeOffset              = ConvertTo-Seconds $TimeOffset;
    # Leap Second indicator
    [int]$SyncStatus         = ($NtpData[0] -band 0xC0) -shr 6;

    # Convert Integer and Fractional parts of the (64-bit) (LocalReceiveTime) NTP time from the byte array
    $IntPart                 = [BitConverter]::ToUInt32($NtpData[43..40],0);
    $FracPart                = [BitConverter]::ToUInt32($NtpData[47..44],0); 

    # Convert to Millseconds (convert fractional part by dividing value by 2^32)
    $LocalReceiveTime        = $Intpart * 1000 + ($FracPart * 1000 / 0x100000000);

    # Perform the same calculation for (NtpReceiveTime) (in bytes [32..39])
    $IntPart                 = [BitConverter]::ToUInt32($NtpData[35..32],0);
    $FracPart                = [BitConverter]::ToUInt32($NtpData[39..36],0);
    $NtpReceiveTime          = $IntPart * 1000 + ($FracPart * 1000 / 0x100000000);

    # Calculate values for $StartDate and $EndDate as Milliseconds since 1/1/1900 (NTP format) / UTC
    $LocalSendTime           = ([TimeZoneInfo]::ConvertTimeToUtc($StartDate) - $StartOfEpoch).TotalMilliseconds;
    $NtpSendTime             = ([TimeZoneInfo]::ConvertTimeToUtc($EndDate) - $StartOfEpoch).TotalMilliseconds;

    # Calculate the NTP Offset and Delay values
    $Offset                  = (($NtpReceiveTime - $LocalSendTime) + ($LocalReceiveTime - $NtpSendTime)) / 2;
    $Delay                   = ($LocalReceiveTime - $LocalSendTime) - ($NtpSendTime - $NtpReceiveTime);

    # Convert NTP and local time from Unix timestamp to the local time zone
    $TimeZoneId              = (Get-TimeZone).Id;
    $TimeZone                = [System.TimeZoneInfo]::FindSystemTimeZoneById($TimeZoneId);
    $Ntpdate                 = ([datetime]'1/1/1900').AddMilliseconds(($NtpSendTime + $Offset));
    [DateTime]$NtpDateTime   = [System.TimeZoneInfo]::ConvertTimeFromUtc($Ntpdate, $TimeZone);
    $localDate               = ([datetime]'1/1/1900').AddMilliseconds(($LocalReceiveTime + $Offset));
    [DateTime]$LocalDateTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($localDate, $TimeZone);

    Write-IcingaConsoleDebug -Message 'Local date time: {0}, NtpServer date time: {1}' -Objects $LocalDateTime.ToString(
        "MM/dd/yyyy HH:mm:ss.fff tt"
        ), $NtpDateTime.ToString(
            "MM/dd/yyyy HH:mm:ss.fff tt"
        );

    # Get Server Version and mode
    $VersionN = ($NtpData[0] -band 0x38);
    $Mode     = ($NtpData[0] -band 0x07);
    $Stratum  = $NtpData[1];

    return @{
        'NtpServer'        = $Server;
        'NtpTime'          = $NtpDateTime;
        'TimeOffset'       = [Math]::Round($Offset / 1000, 2);
        'Delay'            = [Math]::Round($Delay / 1000, 3);
        'CalculatedOffset' = (Get-IcingaValue -Value ([Math]::Round($Offset / 1000, 2) - $TimeOffset) -Compare 0 -Maximum);
        'ServerVersion'    = $VersionN;
        'LocalTime'        = $LocalDateTime;
        'SyncStatus'       = $SyncStatus;
        'Stratum'          = $Stratum;
        'StratumTxt'       = $ProviderEnums.StratumTxt[$Stratum];
        'Mode'             = $Mode;
        'ModeTxt'          = $ProviderEnums.ClientModeName[$Mode];
    };
}
