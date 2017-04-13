
function Get-SqlVersionTable {
    param(
        [Parameter(Position=0)]
        [Alias('Release')]
        [ValidateSet('v.Next', '2016', '2014', '2012', '2008 R2', '2008', '2005', '2000', '7.0')]
        [string[]]$Version = ('2016', '2014', '2012', '2008 R2')
    )
    
    $Url = 'https://sqlserverbuilds.blogspot.co.uk/'
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
                    'Community Technology Preview' {'CTP'; break}
                    'Release Candidate' {'RC'; break}
                    'RTM' {'RTM'; break}
                    'GDR' {'GDR'; break}
                    'Hotfix' {'Hotfix'; break}
                    'Cumulative update' {'CU'; break}
                    'Service Pack' {'SP'; break}
                    default {'Update'}
                }
            )


            $Output.Add($RowObj)
        }
    }

    return $Output
}
