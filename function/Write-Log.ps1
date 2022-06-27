function Write-Log 
{
    Param(
        $Message = "",
        $Path = "",
        $MaximumSizeLogKB = 10000,
        [switch] $Verbose 
         )

    if ($Path -eq "")
    {
        $Path = $PSCommandPath+".log"
    }

    if ((Test-Path $path))
    {
        $SizeLogKB = (Get-Item $Path).length/1KB
        if ($SizeLogKB -gt $MaximumSizeLogKB)
        {
            $PathBak = $Path+'.bak' 
            $FileName = "D:\PowerShell\File-Delete.txt"
            if (Test-Path $PathBak) {
              Remove-Item -Force $PathBak
            }
            Rename-Item -Path $Path -NewName $PathBak 
        }
    }

    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    if ($Verbose)
    {
        "$ts|$Message"
    }

    "$ts|$Message" | Tee-Object -FilePath $Path -Append | Write-Verbose

}
