# 1) Console-only (no file), auto-verbose
Write-Log -Message "Hello console" -Level Info

# 2) Force global console printing for everything
$Global:WriteLog_Verbose = $true
Write-Log -Message "Always to console" -Level Warning

# 3) Use a global default file and size
$Global:WriteLog_LogFileName      = 'C:\Logs\ops.log'
$Global:WriteLog_MaximumSizeLogKB = 25000
Write-Log -Message "Goes to file and console (because global verbose)" -Level Important

# 4) Override globals per call
Write-Log -Message "Only this call uses a different file" -LogFileName 'D:\temp\oneoff.log' -Level Error
