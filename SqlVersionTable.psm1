
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

        .Example
        PS C:\> Get-SqlVersionTable -Version '2008 R2', 2012, 2014 -UpdateType RTM, SP | ft Release, UpdateType, Build, 'KB / Description'

        Release UpdateType Build      KB / Description                                  
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
    param(
        [Parameter(Position=0)]
        [Alias('Release')]
        [ValidateSet('v.Next', '2016', '2014', '2012', '2008 R2', '2008', '2005', '2000', '7.0')]
        [string[]]$Version = ('2016', '2014', '2012', '2008 R2'),

        [Parameter(Position=1)]
        [ValidateSet('CTP', 'RC', 'RTM', 'GDR', 'Hotfix', 'CU', 'SP', 'Update')]
        [string[]]$UpdateType
                
    )
    
    $Url = 'https://sqlserverbuilds.blogspot.com/'
    try {
        #$Blog = Invoke-WebRequest $Url -ErrorAction Stop
    } catch {
        Write-Error ([string]::Format(
            "Unable to fetch version table from {0}. {1}: {2}",
            $Url,
            $_.Exception.GetType().Name,
            $_.Exception.Message
        ))
        return
    }

    $Releases = 'v.Next', '2016', '2014', '2012', '2008 R2', '2008', '2005', '2000', '7.0'
    $TableNums = $Version | foreach {$Releases.IndexOf($_)}

    $Tables = $Blog.ParsedHtml.getElementsByTagName('Table') | select -Skip 2

    $Output = New-Object System.Collections.Generic.List[psobject](1200)

    foreach ($TableNum in $TableNums) {
        $Rows = $Tables[$TableNum].Rows
        $HeaderCells = $Rows[0].Cells | foreach {$_.innerText}
        foreach ($Row in ($Rows | select -Skip 1)){

            $Cells = $Row.Cells | foreach {$_.innerText}
            
            $Href = $Row.getElementsByTagName('A') | foreach {$_.href} | select -First 1
            
            $RowObj = New-Object psobject -Property @{
                Release = $Releases[$TableNum];
                Link = $Href;
            }

            #Add properties dynamically based on table header. Not all tables have same columns
            for ($i=0; $i -lt $HeaderCells.Count; $i++) {
                $Property = $HeaderCells[$i]
                $ValueText = $Cells[$i]

                if ($Property -match 'build|version') {
                    if ($ValueText -match "^12.0.5537 or 12.0.5538$") {$ValueText = "12.0.5537"}
                    $Value = [version]$ValueText
                } elseif ($Property -match 'release date') {
                    $Value = try {
                        [datetime]($Cells[6] -replace '\s*\*new')
                    } catch {}
                }
                else {
                    $Value = $ValueText
                }

                $RowObj | Add-Member NoteProperty -Name $Property -Value $Value
            } #end for
            

            $RowObj | Add-Member NoteProperty -Name UpdateType -Value $(
                switch -Regex ($RowObj.'KB / Description') {
                    'Hotfix|QFE' {'Hotfix'; break}
                    'Community Technology Preview' {'CTP'; break}
                    'Release Candidate' {'RC'; break}
                    'RTM .* RTM' {'RTM'; break}
                    'GDR' {'GDR'; break}
                    'Cumulative update package \d+ \(CU\d+\)' {'CU'; break}
                    '^(?!\d+ FIX).*Service Pack \d \(SP\d\)' {'SP'; break}
                    default {'Update'}
                }
            )

            if (-not $PSBoundParameters.ContainsKey('UpdateType') -or ($UpdateType -contains $RowObj.UpdateType)) {
                $Output.Add($RowObj)
            }
        }
    }

    return $Output
}
