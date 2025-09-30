<#
    report-database-compare.ps1

    Generates a HTML report comparing the structure and selected metadata of two SQL Server databases.
    The script relies on the dbatools PowerShell module for connectivity and querying.

    Requirements
    ------------
    * dbatools PowerShell module
    * Permissions to read metadata from both databases

    Output
    ------
    * HTML report highlighting matching and differing objects between the two databases

    Usage example
    -------------
    .\report-database-compare.ps1 -SourceInstance "SQL01" -SourceDatabase "DBA" -TargetInstance "SQL02" -TargetDatabase "DBA" -OutputPath "C:\Reports\DbCompare.html"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$SourceInstance,

    [Parameter(Mandatory = $true)]
    [string]$SourceDatabase,

    [Parameter(Mandatory = $true)]
    [string]$TargetInstance,

    [Parameter(Mandatory = $true)]
    [string]$TargetDatabase,

    [string]$OutputPath = (Join-Path -Path $PWD -ChildPath "DatabaseComparisonReport.html")
)

#--------------------------------------------------------------------------------
# Section: Dependencies and validation
#--------------------------------------------------------------------------------
try {
    if (-not (Get-Module -ListAvailable -Name dbatools)) {
        throw "The dbatools module is required. Install with 'Install-Module dbatools'."
    }

    Import-Module dbatools -ErrorAction Stop
}
catch {
    throw "Failed to load the dbatools module. $_"
}

#--------------------------------------------------------------------------------
# Section: Helper functions
#--------------------------------------------------------------------------------
function Invoke-DbMetadataQuery {
    <#
        Executes a query against the supplied database using dbatools.
        Returns an empty array when the query result is null to simplify comparisons.
    #>
    param (
        [string]$Instance,
        [string]$Database,
        [string]$Query
    )

    try {
        $result = Invoke-DbaQuery -SqlInstance $Instance -Database $Database -Query $Query -As PSObject -EnableException
        if ($null -eq $result) {
            return @()
        }
        return $result
    }
    catch {
        Write-Warning "Query failed on $Instance/$Database. $_"
        return @()
    }
}

function New-NameComparisonResult {
    <#
        Compares two lists of object names and returns a collection that flags matches and differences.
    #>
    param (
        [string]$ObjectType,
        [string[]]$SourceNames,
        [string[]]$TargetNames
    )

    $sourceSet = @(
        $SourceNames |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $targetSet = @(
        $TargetNames |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
    $allNames = @($sourceSet + $targetSet) | Sort-Object -Unique

    foreach ($name in $allNames) {
        $inSource = $sourceSet -contains $name
        $inTarget = $targetSet -contains $name

        if ($inSource -and $inTarget) {
            $result = '✅ Match'
        }
        elseif ($inSource -and -not $inTarget) {
            $result = '⚠️ Missing in target'
        }
        elseif (-not $inSource -and $inTarget) {
            $result = '⚠️ Missing in source'
        }
        else {
            continue
        }

        [PSCustomObject]@{
            ObjectType = $ObjectType
            ObjectName = $name
            Result     = $result
        }
    }
}

function New-HtmlSection {
    <#
        Generates a HTML fragment for a titled section with data.
    #>
    param (
        [string]$Title,
        [object[]]$Data
    )

    if (-not $Data -or $Data.Count -eq 0) {
        return "<h2>$Title</h2><p>No differences found.</p>"
    }

    $tableHtml = $Data | ConvertTo-Html -Fragment
    return "<h2>$Title</h2>$tableHtml"
}

function Format-DatabaseOptionName {
    <#
        Converts database option identifiers into a friendlier display format for the report.
    #>
    param (
        [string]$OptionName
    )

    if ([string]::IsNullOrWhiteSpace($OptionName)) {
        return $OptionName
    }

    $prefix = ''
    $nameBody = $OptionName

    if ($nameBody.StartsWith('Scoped.')) {
        $prefix = 'Scoped: '
        $nameBody = $nameBody.Substring(7)
    }

    $nameBody = $nameBody -replace '[._]', ' '
    $textInfo = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo
    $titleCase = $textInfo.ToTitleCase($nameBody.ToLowerInvariant())

    $titleCase = $titleCase -replace '\bAnsi\b', 'ANSI'
    $titleCase = $titleCase -replace '\bSql\b', 'SQL'

    return "$prefix$titleCase"
}

function Get-DatabaseOptions {
    <#
        Retrieves a harmonised list of database options and scoped configurations so that
        missing values caused by version differences can be highlighted during comparison.
    #>
    param (
        [string]$Instance,
        [string]$Database
    )

    $metadataOptionsQuery = @"
DECLARE @options TABLE (
    OptionName NVARCHAR(256),
    OptionValue NVARCHAR(4000)
);

INSERT INTO @options (OptionName, OptionValue)
SELECT 'collation_name' COLLATE DATABASE_DEFAULT,
       CAST(collation_name AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'compatibility_level' COLLATE DATABASE_DEFAULT,
       CAST(compatibility_level AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'containment_desc' COLLATE DATABASE_DEFAULT,
       CAST(containment_desc AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'recovery_model_desc' COLLATE DATABASE_DEFAULT,
       CAST(recovery_model_desc AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'page_verify_option_desc' COLLATE DATABASE_DEFAULT,
       CAST(page_verify_option_desc AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'target_recovery_time_in_seconds' COLLATE DATABASE_DEFAULT,
       CAST(target_recovery_time_in_seconds AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_auto_close_on' COLLATE DATABASE_DEFAULT,
       CAST(is_auto_close_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_auto_shrink_on' COLLATE DATABASE_DEFAULT,
       CAST(is_auto_shrink_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_auto_create_stats_on' COLLATE DATABASE_DEFAULT,
       CAST(is_auto_create_stats_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_auto_update_stats_on' COLLATE DATABASE_DEFAULT,
       CAST(is_auto_update_stats_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_auto_update_stats_async_on' COLLATE DATABASE_DEFAULT,
       CAST(is_auto_update_stats_async_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_read_committed_snapshot_on' COLLATE DATABASE_DEFAULT,
       CAST(is_read_committed_snapshot_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'snapshot_isolation_state_desc' COLLATE DATABASE_DEFAULT,
       CAST(snapshot_isolation_state_desc AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_ansi_null_default_on' COLLATE DATABASE_DEFAULT,
       CAST(is_ansi_null_default_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_ansi_nulls_on' COLLATE DATABASE_DEFAULT,
       CAST(is_ansi_nulls_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_ansi_padding_on' COLLATE DATABASE_DEFAULT,
       CAST(is_ansi_padding_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_ansi_warnings_on' COLLATE DATABASE_DEFAULT,
       CAST(is_ansi_warnings_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_arithabort_on' COLLATE DATABASE_DEFAULT,
       CAST(is_arithabort_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_concat_null_yields_null_on' COLLATE DATABASE_DEFAULT,
       CAST(is_concat_null_yields_null_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_numeric_roundabort_on' COLLATE DATABASE_DEFAULT,
       CAST(is_numeric_roundabort_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_quoted_identifier_on' COLLATE DATABASE_DEFAULT,
       CAST(is_quoted_identifier_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_trustworthy_on' COLLATE DATABASE_DEFAULT,
       CAST(is_trustworthy_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'is_cursor_close_on_commit_on' COLLATE DATABASE_DEFAULT,
       CAST(is_cursor_close_on_commit_on AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.databases WHERE name = DB_NAME();

INSERT INTO @options (OptionName, OptionValue)
SELECT 'Scoped.' + name COLLATE DATABASE_DEFAULT,
       CAST(value AS NVARCHAR(4000)) COLLATE DATABASE_DEFAULT
FROM sys.database_scoped_configurations;

IF EXISTS (
    SELECT 1
    FROM sys.all_objects
    WHERE object_id = OBJECT_ID('sys.database_options')
)
BEGIN
    INSERT INTO @options (OptionName, OptionValue)
    SELECT option_name COLLATE DATABASE_DEFAULT,
           option_state_desc COLLATE DATABASE_DEFAULT
    FROM sys.database_options;
END;

SELECT OptionName, OptionValue
FROM @options;
"@

    return Invoke-DbMetadataQuery -Instance $Instance -Database $Database -Query $metadataOptionsQuery
}

#--------------------------------------------------------------------------------
# Section: Table row count comparison
#--------------------------------------------------------------------------------
$rowCountQuery = @"
SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    SUM(ps.row_count) AS RowCountValue
FROM sys.tables AS t
    JOIN sys.schemas AS s ON t.schema_id = s.schema_id
    JOIN sys.dm_db_partition_stats AS ps ON t.object_id = ps.object_id AND ps.index_id IN (0, 1)
GROUP BY s.name, t.name;
"@

$sourceRowCounts = Invoke-DbMetadataQuery -Instance $SourceInstance -Database $SourceDatabase -Query $rowCountQuery
$targetRowCounts = Invoke-DbMetadataQuery -Instance $TargetInstance -Database $TargetDatabase -Query $rowCountQuery

$rowCountLookupSource = @{}
foreach ($row in $sourceRowCounts) {
    $key = "$($row.SchemaName).$($row.TableName)"
    $rowCountLookupSource[$key] = $row
}

$rowCountLookupTarget = @{}
foreach ($row in $targetRowCounts) {
    $key = "$($row.SchemaName).$($row.TableName)"
    $rowCountLookupTarget[$key] = $row
}

$tableRowResults = @()
$allTableKeys = @($rowCountLookupSource.Keys + $rowCountLookupTarget.Keys) | Sort-Object -Unique

foreach ($key in $allTableKeys) {
    $schema, $table = $key.Split('.', 2)
    $sourceValue = $rowCountLookupSource[$key]
    $targetValue = $rowCountLookupTarget[$key]

    if ($null -eq $sourceValue) {
        $result = '⚠️ Missing in source'
    }
    elseif ($null -eq $targetValue) {
        $result = '⚠️ Missing in target'
    }
    elseif ($sourceValue.RowCountValue -eq $targetValue.RowCountValue) {
        $result = '✅ Match'
    }
    else {
        $result = '❌ Different row count'
    }

    $tableRowResults += [PSCustomObject]@{
        Schema     = $schema
        Table      = $table
        SourceRows = if ($sourceValue) { $sourceValue.RowCountValue } else { $null }
        TargetRows = if ($targetValue) { $targetValue.RowCountValue } else { $null }
        Result     = $result
    }
}

#--------------------------------------------------------------------------------
# Section: Table column comparison
#--------------------------------------------------------------------------------
$columnQuery = @"
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS;
"@

$sourceColumns = Invoke-DbMetadataQuery -Instance $SourceInstance -Database $SourceDatabase -Query $columnQuery
$targetColumns = Invoke-DbMetadataQuery -Instance $TargetInstance -Database $TargetDatabase -Query $columnQuery

$columnLookupSource = @{}
foreach ($row in $sourceColumns) {
    $key = "$($row.TABLE_SCHEMA).$($row.TABLE_NAME)"
    if (-not $columnLookupSource.ContainsKey($key)) {
        $columnLookupSource[$key] = @()
    }
    $columnLookupSource[$key] += $row.COLUMN_NAME
}

$columnLookupTarget = @{}
foreach ($row in $targetColumns) {
    $key = "$($row.TABLE_SCHEMA).$($row.TABLE_NAME)"
    if (-not $columnLookupTarget.ContainsKey($key)) {
        $columnLookupTarget[$key] = @()
    }
    $columnLookupTarget[$key] += $row.COLUMN_NAME
}

$allColumnTableKeys = @($columnLookupSource.Keys + $columnLookupTarget.Keys) | Sort-Object -Unique
$tableColumnResults = @()

foreach ($key in $allColumnTableKeys) {
    $schema, $table = $key.Split('.', 2)
    $sourceList = if ($columnLookupSource[$key]) { $columnLookupSource[$key] | Sort-Object } else { @() }
    $targetList = if ($columnLookupTarget[$key]) { $columnLookupTarget[$key] | Sort-Object } else { @() }

    if ($sourceList.Count -eq 0) {
        $result = '⚠️ Missing table in source'
    }
    elseif ($targetList.Count -eq 0) {
        $result = '⚠️ Missing table in target'
    }
    elseif ($sourceList.Count -eq $targetList.Count -and (@(Compare-Object -ReferenceObject $sourceList -DifferenceObject $targetList).Count -eq 0)) {
        $result = '✅ Columns match'
    }
    else {
        $result = '❌ Column mismatch'
    }

    $sourceOnly = @($sourceList | Where-Object { $targetList -notcontains $_ })
    $targetOnly = @($targetList | Where-Object { $sourceList -notcontains $_ })

    $tableColumnResults += [PSCustomObject]@{
        Schema            = $schema
        Table             = $table
        SourceColumnCount = $sourceList.Count
        TargetColumnCount = $targetList.Count
        SourceOnlyColumns = if ($sourceOnly.Count) { ($sourceOnly -join ', ') } else { '' }
        TargetOnlyColumns = if ($targetOnly.Count) { ($targetOnly -join ', ') } else { '' }
        Result            = $result
    }
}

#--------------------------------------------------------------------------------
# Section: Object name comparisons (synonyms, schemas, views, procedures, functions, triggers)
#--------------------------------------------------------------------------------
$synonymQuery = @"
SELECT
    s.name + '.' + sn.name AS ObjectName
FROM sys.synonyms AS sn
    JOIN sys.schemas AS s ON sn.schema_id = s.schema_id;
"@

$schemaQuery = "SELECT name AS ObjectName FROM sys.schemas WHERE schema_id < 16384;"
$viewQuery = @"
SELECT
    s.name + '.' + v.name AS ObjectName
FROM sys.views AS v
    JOIN sys.schemas AS s ON v.schema_id = s.schema_id;
"@

$procedureQuery = @"
SELECT
    s.name + '.' + p.name AS ObjectName
FROM sys.procedures AS p
    JOIN sys.schemas AS s ON p.schema_id = s.schema_id;
"@

$functionQuery = @"
SELECT
    s.name + '.' + o.name AS ObjectName
FROM sys.objects AS o
    JOIN sys.schemas AS s ON o.schema_id = s.schema_id
WHERE o.[type] IN ('FN', 'IF', 'TF', 'FS', 'FT');
"@

$tableTriggerQuery = @"
SELECT
    sch.name + '.' + tr.name AS ObjectName
FROM sys.triggers AS tr
    JOIN sys.objects AS parentObj ON tr.parent_id = parentObj.object_id
    JOIN sys.schemas AS sch ON parentObj.schema_id = sch.schema_id
WHERE tr.parent_class_desc = 'OBJECT_OR_COLUMN';
"@

$dbTriggerQuery = "SELECT name AS ObjectName FROM sys.triggers WHERE parent_class_desc = 'DATABASE';"

$objectComparisons = @()
$objectComparisons += New-NameComparisonResult -ObjectType 'Synonym' -SourceNames (Invoke-DbMetadataQuery -Instance $SourceInstance -Database $SourceDatabase -Query $synonymQuery | Select-Object -ExpandProperty ObjectName) -TargetNames (Invoke-DbMetadataQuery -Instance $TargetInstance -Database $TargetDatabase -Query $synonymQuery | Select-Object -ExpandProperty ObjectName)
$objectComparisons += New-NameComparisonResult -ObjectType 'Schema' -SourceNames (Invoke-DbMetadataQuery -Instance $SourceInstance -Database $SourceDatabase -Query $schemaQuery | Select-Object -ExpandProperty ObjectName) -TargetNames (Invoke-DbMetadataQuery -Instance $TargetInstance -Database $TargetDatabase -Query $schemaQuery | Select-Object -ExpandProperty ObjectName)
$objectComparisons += New-NameComparisonResult -ObjectType 'View' -SourceNames (Invoke-DbMetadataQuery -Instance $SourceInstance -Database $SourceDatabase -Query $viewQuery | Select-Object -ExpandProperty ObjectName) -TargetNames (Invoke-DbMetadataQuery -Instance $TargetInstance -Database $TargetDatabase -Query $viewQuery | Select-Object -ExpandProperty ObjectName)
$objectComparisons += New-NameComparisonResult -ObjectType 'Procedure' -SourceNames (Invoke-DbMetadataQuery -Instance $SourceInstance -Database $SourceDatabase -Query $procedureQuery | Select-Object -ExpandProperty ObjectName) -TargetNames (Invoke-DbMetadataQuery -Instance $TargetInstance -Database $TargetDatabase -Query $procedureQuery | Select-Object -ExpandProperty ObjectName)
$objectComparisons += New-NameComparisonResult -ObjectType 'Function' -SourceNames (Invoke-DbMetadataQuery -Instance $SourceInstance -Database $SourceDatabase -Query $functionQuery | Select-Object -ExpandProperty ObjectName) -TargetNames (Invoke-DbMetadataQuery -Instance $TargetInstance -Database $TargetDatabase -Query $functionQuery | Select-Object -ExpandProperty ObjectName)
$objectComparisons += New-NameComparisonResult -ObjectType 'Trigger' -SourceNames (Invoke-DbMetadataQuery -Instance $SourceInstance -Database $SourceDatabase -Query $tableTriggerQuery | Select-Object -ExpandProperty ObjectName) -TargetNames (Invoke-DbMetadataQuery -Instance $TargetInstance -Database $TargetDatabase -Query $tableTriggerQuery | Select-Object -ExpandProperty ObjectName)
$objectComparisons += New-NameComparisonResult -ObjectType 'Database Trigger' -SourceNames (Invoke-DbMetadataQuery -Instance $SourceInstance -Database $SourceDatabase -Query $dbTriggerQuery | Select-Object -ExpandProperty ObjectName) -TargetNames (Invoke-DbMetadataQuery -Instance $TargetInstance -Database $TargetDatabase -Query $dbTriggerQuery | Select-Object -ExpandProperty ObjectName)

#--------------------------------------------------------------------------------
# Section: User comparison
#--------------------------------------------------------------------------------
$userQuery = @"
SELECT name AS ObjectName
FROM sys.database_principals
WHERE type IN ('S', 'U', 'G')
  AND principal_id > 4;
"@

$userComparison = New-NameComparisonResult -ObjectType 'Database User' -SourceNames (Invoke-DbMetadataQuery -Instance $SourceInstance -Database $SourceDatabase -Query $userQuery | Select-Object -ExpandProperty ObjectName) -TargetNames (Invoke-DbMetadataQuery -Instance $TargetInstance -Database $TargetDatabase -Query $userQuery | Select-Object -ExpandProperty ObjectName)

#--------------------------------------------------------------------------------
# Section: Database configuration comparison
#--------------------------------------------------------------------------------
$sourceOptions = Get-DatabaseOptions -Instance $SourceInstance -Database $SourceDatabase
$targetOptions = Get-DatabaseOptions -Instance $TargetInstance -Database $TargetDatabase

$optionLookupSource = @{}
foreach ($row in $sourceOptions) {
    if ($row.OptionName -and -not $optionLookupSource.ContainsKey($row.OptionName)) {
        $optionLookupSource[$row.OptionName] = $row.OptionValue
    }
}

$optionLookupTarget = @{}
foreach ($row in $targetOptions) {
    if ($row.OptionName -and -not $optionLookupTarget.ContainsKey($row.OptionName)) {
        $optionLookupTarget[$row.OptionName] = $row.OptionValue
    }
}

$optionComparison = @()
$allOptionNames = @($optionLookupSource.Keys + $optionLookupTarget.Keys) | Sort-Object -Unique

foreach ($optionName in $allOptionNames) {
    $sourceValue = if ($optionLookupSource.ContainsKey($optionName)) { $optionLookupSource[$optionName] } else { $null }
    $targetValue = if ($optionLookupTarget.ContainsKey($optionName)) { $optionLookupTarget[$optionName] } else { $null }

    if ($null -eq $sourceValue -and $null -ne $targetValue) {
        $result = '⚠️ Missing in source'
    }
    elseif ($null -ne $sourceValue -and $null -eq $targetValue) {
        $result = '⚠️ Missing in target'
    }
    elseif (("$sourceValue") -eq ("$targetValue")) {
        $result = '✅ Match'
    }
    else {
        $result = '❌ Different value'
    }

    $displayName = Format-DatabaseOptionName -OptionName $optionName

    $optionComparison += [PSCustomObject]@{
        OptionName  = $displayName
        SourceValue = $sourceValue
        TargetValue = $targetValue
        Result      = $result
    }
}

#--------------------------------------------------------------------------------
# Section: HTML report assembly
#--------------------------------------------------------------------------------
$styleBlock = @"
<style>
body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; }
h1 { color: #2c3e50; }
h2 { color: #34495e; border-bottom: 1px solid #ccc; padding-bottom: 4px; }
table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
th, td { border: 1px solid #ddd; padding: 6px 8px; text-align: left; }
th { background-color: #f2f2f2; }
.toggle-container {
    margin: 16px 0;
}
.toggle-link {
    display: inline-block;
    padding: 6px 14px;
    background-color: #3498db;
    color: #ffffff;
    text-decoration: none;
    border-radius: 4px;
}
.toggle-link:hover,
.toggle-link:focus {
    background-color: #2d83bf;
    color: #ffffff;
}
body.hide-ok table tbody tr.status-ok {
    display: none;
}
</style>
"@

$scriptBlock = @"
<script>
document.addEventListener('DOMContentLoaded', function () {
    const toggleLink = document.getElementById('toggle-differences');
    if (!toggleLink) {
        return;
    }

    const tables = Array.from(document.querySelectorAll('table'));
    tables.forEach(table => {
        const rows = Array.from(table.querySelectorAll('tr'));
        const headerRow = rows.find(row => row.querySelectorAll('th').length > 0);
        if (!headerRow) {
            return;
        }

        const headerCells = Array.from(headerRow.querySelectorAll('th'))
            .map(th => th.textContent.trim().toLowerCase());
        const resultIndex = headerCells.indexOf('result');
        if (resultIndex === -1) {
            return;
        }

        rows.forEach(row => {
            if (row === headerRow) {
                return;
            }

            const cells = row.querySelectorAll('td, th');
            const resultCell = cells[resultIndex];
            if (!resultCell) {
                return;
            }

            const text = resultCell.textContent.trim();
            if (/match/i.test(text)) {
                row.classList.add('status-ok');
            } else {
                row.classList.add('status-diff');
            }
        });
    });

    let showAll = false;
    const applyState = () => {
        document.body.classList.toggle('hide-ok', !showAll);
        toggleLink.textContent = showAll ? 'Show differences' : 'Show all comparation';
    };

    toggleLink.addEventListener('click', function (event) {
        event.preventDefault();
        showAll = !showAll;
        applyState();
    });

    applyState();
});
</script>
"@

$reportGeneratedOn = Get-Date

$toggleControl = @'
<div class="toggle-container">
    <a href="#" id="toggle-differences" class="toggle-link">Show all comparation</a>
</div>
'@

$reportSections = @()
$reportSections += $toggleControl
$reportSections += "<h1>Database Comparison Report</h1>"
$reportSections += "<p><strong>Source:</strong> $SourceInstance/$SourceDatabase</p>"
$reportSections += "<p><strong>Target:</strong> $TargetInstance/$TargetDatabase</p>"
$reportSections += "<p><strong>Generated:</strong> $($reportGeneratedOn.ToString('yyyy-MM-dd HH:mm:ss'))</p>"
$reportSections += New-HtmlSection -Title 'Table row counts' -Data $tableRowResults
$reportSections += New-HtmlSection -Title 'Table column definitions' -Data $tableColumnResults
$reportSections += New-HtmlSection -Title 'Object name comparison (synonyms, schemas, views, procedures, functions, triggers)' -Data $objectComparisons
$reportSections += New-HtmlSection -Title 'Database users' -Data $userComparison
$reportSections += New-HtmlSection -Title 'Database configuration options' -Data $optionComparison

$headContent = $styleBlock + "`n" + $scriptBlock
$fullHtml = ConvertTo-Html -Title 'Database Comparison Report' -Head $headContent -Body ($reportSections -join "`n")
Set-Content -Path $OutputPath -Value $fullHtml -Encoding UTF8

Write-Host "Report generated at $OutputPath"
