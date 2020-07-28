<#
.SYNOPSIS
    Gets Network Time Protocol time(SNTP/NTP) from a specified server
.DESCRIPTION
    Invoke-IcingaCheckTimeSync connects to an NTP server on UDP default port 123 and retrieves the current NTP time.
    Selected components of the returned time information are decoded and returned in a hashtable.
.PARAMETER Server
    The NTP Server you want to connect to.
.PARAMETER Port 
    Port number (default: 123)
.PARAMETER TimeOffset
    The maximum acceptable offset between the local clock and the NTP Server, in seconds.
    Invoke-IcingaCheckTimeSync will return OK, if there is no difference between them,
    WARNING, if the time difference exceeds the Warning threshold,
    CRITICAL, if the time difference exceeds the Critical threshold.
.PARAMETER Warning
    Used to specify a offset Warning threshold. In this case an Integer or float value in seconds.
.PARAMETER Critical
    Used to specify a offset Critical threshold. In this case an Integer or float value in seconds.
.PARAMETER Timeout
    Seconds before connection times out (default: 10)
.PARAMETER IPV4
    Use IPV4 connection. Default $FALSE
.EXAMPLE
    PS> Invoke-IcingaCheckTimeSync -Server '0.pool.npt.org' -TimeOffset 10ms -Warning 10ms -Critical 20ms -Verbosity 2
    \_ [OK] Check package "Time Package" (Match All)
    \_ [OK] Sync Status: NoLeapWarning
    \_ [WARNING] Time Offset: Value "0.02s" is greater than threshold "0.01s"
    \_ [OK] Time Service: Running
    | 'time_offset'=0.02s;0.01;0.02 'time_service'=4;;4 
    0
.EXAMPLE
    PS> Invoke-IcingaCheckTimeSync -Server 'time.versatel.de' -TimeOffset 50ms -Warning 10ms -Critical 20ms -Verbosity 2
    \_ [OK] Sync Status: NoLeapWarning
    \_ [OK] Time Offset: 0s
    \_ [OK] Time Service: Running
    | 'time_offset'=0s;0.01;0.02 'time_service'=4;;4 
    1
.LINK
    https://github.com/Icinga/icinga-powershell-plugins
.NOTES
    The values you enter here are all converted into seconds and if you enter only values, 
    without type measurement behind like (s, ms, h, d etc.) the values are interpreted as seconds. 
#>

function Invoke-IcingaCheckTimeSync()
{
    param(
        [string]$Server,
        $TimeOffset         = 0,
        $Warning            = $null,
        $Critical           = $null,
        [int]$Timeout       = 10,
        [switch]$IPV4       = $FALSE,
        [int]$Port          = 123,
        [switch]$NoPerfData = $FALSE,
        [ValidateSet(0, 1, 2)]
        [int]$Verbosity     = 0
   );

    $TimeData    = Get-IcingaNtpData -Server $Server -Port $Port -TimeOffset $TimeOffset -Timeout $Timeout -IPV4:$IPV4;
    $TimeService = (Get-IcingaServices 'W32Time').W32time; 
    $Warning     = ConvertTo-SecondsFromIcingaThresholds $Warning;
    $Critical    = ConvertTo-SecondsFromIcingaThresholds $Critical;

    $OffsetCheck = New-IcingaCheck `
        -Name 'Time Offset' `
        -Value (
            $TimeData.CalculatedOffset
        ) `
        -Unit 's';

    $OffsetCheck.WarnOutOfRange($Warning).CritOutOfRange($Critical) | Out-Null;

    $TimeCheck = New-IcingaCheck `
        -Name 'Time Service' `
        -Value $TimeService.configuration.Status.raw `
        -ObjectExists $TimeService `
        -Translation $ProviderEnums.ServiceStatusName;

    $TimeCheck.CritIfNotMatch($ProviderEnums.ServiceStatus.Running) | Out-Null;

    $SyncStatus = New-IcingaCheck `
        -Name 'Sync Status' `
        -Value $TimeData.SyncStatus `
        -Translation $ProviderEnums.TimeSyncStatusName `
        -NoPerfData;

    $SyncStatus.CritIfMatch($ProviderEnums.TimeSyncStatus.ClockNotSynhronized) | Out-Null;

    $CheckPackage = New-IcingaCheckPackage `
        -Name 'Time Package' `
        -Checks @(
            $OffsetCheck,
            $TimeCheck,
            $SyncStatus
        ) `
        -OperatorAnd `
        -Verbose $Verbosity;

    return (New-IcingaCheckResult -Check $CheckPackage -NoPerfData $NoPerfData -Compile);
}
