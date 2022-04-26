
function Write-Log {
    Param(
        $Message,
        $Path = "",
        $MaximumSizeLogKB = 10000
    )
    
    if ($Path -eq "")
    {
        $Path = $PSCommandPath+".log"
    }

    $SizeLogKB = (Get-Item $Path).length/1KB

    function TS {Get-Date -Format 'yyyy-MM-dd HH:mm:ss'}
    "$(TS)|$Message"
    "$(TS)|$Message" | Tee-Object -FilePath $Path -Append | Write-Verbose

}
