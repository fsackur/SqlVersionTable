
#region Import custom types
try {
    Add-Type -Path $PSScriptRoot\Dusty.Sql.Version.cs -ErrorAction Stop
} catch {
    if ($_ -match "Cannot add type. The type name .* already exists") {}
    else {throw}
}

Update-FormatData -AppendPath $PSScriptRoot\Dusty.Sql.format.ps1xml
#endregion Import custom types


function Get-SqlFriendlyVersion {
    <#
        .Synopsis
        Returns list of SQL Server versions

        .Description
        Queries the excellent internet resource sqlserverbuilds.blogspot.com for the close-to-exhaustive list of public SQL Server builds.

        Returned objects include versions, descriptions and links to the relevant BK articles.

        .Parameter Version
        Filters output by SQL release, e.g. 2012, 2008 R2. Default: 2008 R2 up to 2016.

        .Parameter UpdateType
        Filters output by update type, e.g. SP, RTM, CU.

        .Parameter Refresh
        Specifies to update cached version table from sqlserverbuilds.blogspot.com

        .Example
        PS C:\> Get-SqlVersionTable -Release Sql2008R2, Sql2012, Sql2014 -UpdateType RTM, SP | ft Release, UpdateType, Version, Description

        Release UpdateType Version    Description                                  
        ------- ---------- -----      ----------------                                  
        2014    SP         12.0.5000  SQL Server 2014 Service Pack 2 (SP2)  Latest SP   
        2014    SP         12.0.4100  SQL Server 2014 Service Pack 1 (SP1)              
        2014    SP         12.0.4050  SQL Server 2014 Service Pack 1 (SP1) [withdrawn]  
        2014    RTM        12.0.2000  SQL Server 2014 RTM  RTM                          
        2012    SP         11.0.6020  SQL Server 2012 Service Pack 3 (SP3)  Latest SP   
        2012    SP         11.0.5058  SQL Server 2012 Service Pack 2 (SP2)              
        2012    SP         11.0.3000  SQL Server 2012 Service Pack 1 (SP1)              
        2012    RTM        11.0.2100  SQL Server 2012 RTM  RTM                          
        2008 R2 SP         10.50.6000 SQL Server 2008 R2 Service Pack 3 (SP3)  Latest SP
        2008 R2 SP         10.50.4000 SQL Server 2008 R2 Service Pack 2 (SP2)           
        2008 R2 SP         10.50.2500 SQL Server 2008 R2 Service Pack 1 (SP1)           
        2008 R2 RTM        10.50.1600 SQL Server 2008 R2 RTM  RTM                       

        Returns the build numbers of all RTM and SP releases of SQL Server 2008 R2 up to 2014
    #>
    [CmdletBinding()]
    [OutputType([Dusty.Sql.SqlServerBuild[]])]
    param(
        [Parameter(Position=0)]
        [version]$Version
    )

    #Hack for 2008 R2 minor version 50/51/52 weirdness
    if ($Version.Minor -gt 50) {
        $Version = [version](
            [regex]::Replace(
                $Version.ToString(),
                '(?<=^\d+)\.5\d\.',
                '.50.'
            )
        )
    }

    $Release = [Dusty.Sql.SqlServerRelease]($Version.Major * 100 + $Version.Minor)

    $VersionTable = Get-SqlVersionTable -Release $Release

    #Get the 'known' build number
    $MatchedVersion = $VersionTable | where {$_.Version -le $Version} | select -First 1
    

    return $MatchedVersion

}


function Get-SqlVersionTable {
    <#
        .Synopsis
        Returns list of SQL Server versions

        .Description
        Queries the excellent internet resource sqlserverbuilds.blogspot.com for the close-to-exhaustive list of public SQL Server builds.

        Returned objects include versions, descriptions and links to the relevant BK articles.

        .Parameter Version
        Filters output by SQL release, e.g. 2012, 2008 R2. Default: 2008 R2 up to 2016.

        .Parameter UpdateType
        Filters output by update type, e.g. SP, RTM, CU.

        .Parameter Refresh
        Specifies to update cached version table from sqlserverbuilds.blogspot.com

        .Example
        PS C:\> Get-SqlVersionTable -Release Sql2008R2, Sql2012, Sql2014 -UpdateType RTM, SP | ft Release, UpdateType, Version, Description

        Release UpdateType Version    Description                                  
        ------- ---------- -----      ----------------                                  
        2014    SP         12.0.5000  SQL Server 2014 Service Pack 2 (SP2)  Latest SP   
        2014    SP         12.0.4100  SQL Server 2014 Service Pack 1 (SP1)              
        2014    SP         12.0.4050  SQL Server 2014 Service Pack 1 (SP1) [withdrawn]  
        2014    RTM        12.0.2000  SQL Server 2014 RTM  RTM                          
        2012    SP         11.0.6020  SQL Server 2012 Service Pack 3 (SP3)  Latest SP   
        2012    SP         11.0.5058  SQL Server 2012 Service Pack 2 (SP2)              
        2012    SP         11.0.3000  SQL Server 2012 Service Pack 1 (SP1)              
        2012    RTM        11.0.2100  SQL Server 2012 RTM  RTM                          
        2008 R2 SP         10.50.6000 SQL Server 2008 R2 Service Pack 3 (SP3)  Latest SP
        2008 R2 SP         10.50.4000 SQL Server 2008 R2 Service Pack 2 (SP2)           
        2008 R2 SP         10.50.2500 SQL Server 2008 R2 Service Pack 1 (SP1)           
        2008 R2 RTM        10.50.1600 SQL Server 2008 R2 RTM  RTM                       

        Returns the build numbers of all RTM and SP releases of SQL Server 2008 R2 up to 2014
    #>
    [CmdletBinding()]
    [OutputType([Dusty.Sql.SqlServerBuild[]])]
    param(
        [Parameter(Position=0)]
        [Alias('Version')]
        [Dusty.Sql.SqlServerRelease[]]$Release = ('Sql2016', 'Sql2014', 'Sql2012', 'Sql2008R2'),

        [Parameter(Position=1)]
        [Dusty.Sql.SqlUpdateType[]]$UpdateType,

        [switch]$Refresh
    )

    $XmlPath = "$PSScriptRoot\SqlVersionTable.xml"
    
    $OutputFilter = {
        $Release -contains $_.Release -and
        (-not $PSBoundParameters.ContainsKey('UpdateType') -or ($UpdateType -contains $_.UpdateType))
    }
    

    #region Return from xml on disk
    if (-not $Refresh) {
        if (Test-Path $XmlPath) {
            return Import-Clixml $XmlPath | where $OutputFilter
        } else {
            Write-Warning ([string]::Format(
                "Version table not found at {0}",
                $XmlPath
            ))
        }
    }
    #endregion Return from xml on disk


    #region Web request
    $Url = 'https://sqlserverbuilds.blogspot.com/'
    try {
        $Blog = Invoke-WebRequest $Url -ErrorAction Stop
    } catch {
        Write-Error ([string]::Format(
            "Unable to fetch version table from {0}. {1}: {2}",
            $Url,
            $_.Exception.GetType().Name,
            $_.Exception.Message
        ))
        return
    }
    #endregion Web request


    #region Parse web response
    $Releases = [System.Enum]::GetValues([Dusty.Sql.SqlServerRelease]) | sort -Descending
    $TableNums = 0..($Releases.Count -1)

    $Tables = $Blog.ParsedHtml.getElementsByTagName('Table') | select -Skip 2

    $Output = New-Object System.Collections.Generic.List[psobject](1200)

    foreach ($TableNum in $TableNums) {
        $ThisRelease = $Releases[$TableNum]
        $Rows = $Tables[$TableNum].Rows
        $HeaderCells = $Rows[0].Cells | foreach {$_.innerText}

        #We want the property names in the output to be different to the column header names in the blogpost
        if ($ThisRelease -eq [Dusty.Sql.SqlServerRelease]::Sql7) {
            #HeaderCells = 'Build', 'SQLSERVR.EXE Build',                 'Q', 'KB', 'KB / Description', 'Release Date'
            $Properties = 'Version', 'SqlservrExeVersion',                'Q', 'KB', 'Description',      'ReleaseDate'
        } else {
            #HeaderCells = 'Build', 'SQLSERVR.EXE Build', 'File version', 'Q', 'KB', 'KB / Description', 'Release Date'
            $Properties = 'Version', 'SqlservrExeVersion', 'FileVersion', 'Q', 'KB', 'Description',      'ReleaseDate'
        }


        foreach ($Row in ($Rows | select -Skip 1)){

            $Cells = $Row.Cells | foreach {$_.innerText}
            
            $Href = $Row.getElementsByTagName('A') | foreach {$_.href} | select -First 1
            
            $RowObj = New-Object Dusty.Sql.SqlServerBuild
            $RowObj.Release = $ThisRelease
            $RowObj.Link = $Href

            #Add properties dynamically based on table header. Not all tables have same columns
            for ($i=0; $i -lt $Properties.Count; $i++) {
                $Property = $Properties[$i]
                $ValueText = $Cells[$i]

                Write-Debug "$Property : $ValueText"

                if ($Property -imatch 'version') {
                    if (-not [string]::IsNullOrWhiteSpace($ValueText)) {
                        $RowObj.$Property = ($ValueText -replace '\s.*')   #Blogpost just _has_ to have that one cell that breaks parsing...
                    }

                } elseif ($Property -match 'ReleaseDate') {
                    $null = [datetime]::TryParse(($ValueText -replace '\s*\*new'), ([ref]$RowObj.ReleaseDate))
                
                } else {
                    $RowObj.$Property = $ValueText
                }
            } #end for
            

            $RowObj.UpdateType = $(
                switch -Regex ($RowObj.Description) {
                    'Hotfix|QFE'                              {[Dusty.Sql.SqlUpdateType]::Hotfix; break}
                    'Community Technology Preview'            {[Dusty.Sql.SqlUpdateType]::CTP; break}
                    'Release Candidate'                       {[Dusty.Sql.SqlUpdateType]::RC; break}
                    'RTM .* RTM'                              {[Dusty.Sql.SqlUpdateType]::RTM; break}
                    'GDR'                                     {[Dusty.Sql.SqlUpdateType]::GDR; break}
                    'Cumulative update package \d+ \(CU\d+\)' {[Dusty.Sql.SqlUpdateType]::CU; break}
                    '^(?!\d+ FIX).*Service Pack \d \(SP\d\)'  {[Dusty.Sql.SqlUpdateType]::SP; break}
                    default                                   {[Dusty.Sql.SqlUpdateType]::Update}
                }
            )

            $Output.Add($RowObj)

        }
    }
    #endregion Parse web response


    try {
        $Output | Export-Clixml $XmlPath
    } catch {
        Write-Warning ([string]::Format(
            "Unable to write version table to {0}. {1}: {2}",
            $XmlPath,
            $_.Exception.GetType().Name,
            $_.Exception.Message
        ))
    }

    return $Output | where $OutputFilter
}
