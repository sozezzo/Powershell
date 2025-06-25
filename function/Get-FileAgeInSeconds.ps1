<#
.SYNOPSIS
    Returns the number of seconds since the last modification of a file.

.DESCRIPTION
    This function calculates how many seconds have elapsed since a given file was last modified.
    If the file does not exist and a default value is provided via the `DefaultValueIfMissing` parameter,
    the function returns that value silently.
    If the file does not exist and no default value is provided, it throws an error.

.PARAMETER FilePath
    The full path to the file you want to check.

.PARAMETER DefaultValueIfMissing
    (Optional) The value to return if the file does not exist. If this is not provided and the file is missing, an error is thrown.

.OUTPUTS
    Integer. The number of seconds since the file's last modification.

.EXAMPLE
    Get-FileAgeInSeconds -FilePath "C:\temp\log.txt"

.EXAMPLE
    Get-FileAgeInSeconds -FilePath "C:\temp\log.txt" -DefaultValueIfMissing 9999

.NOTES
    Author: Milton Sozezzo
    Date: 2025-06-25
    License: MIT
#>

function Get-FileAgeInSeconds {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [int]$DefaultValueIfMissing
    )

    # Check if the file exists
    if (-Not (Test-Path -Path $FilePath -PathType Leaf)) {
        # If a default value is provided, return it silently
        if ($PSBoundParameters.ContainsKey('DefaultValueIfMissing')) {
            return $DefaultValueIfMissing
        } else {
            # Otherwise, throw an error with a descriptive message
            throw "File '$FilePath' does not exist."
        }
    }

    # Get the last modification time in UTC
    $lastWriteTime = (Get-Item $FilePath).LastWriteTimeUtc
    $currentTime = [DateTime]::UtcNow

    # Calculate time difference in seconds
    $ageInSeconds = ($currentTime - $lastWriteTime).TotalSeconds

    # Return the age rounded down to the nearest integer
    return [int]$ageInSeconds
}
