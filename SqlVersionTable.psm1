
function Get-SqlVersionTable {

    $Blog = Invoke-WebRequest https://sqlserverbuilds.blogspot.co.uk/ -ErrorAction Stop

    $Tables = $Blog.ParsedHtml.getElementsByTagName('Table') | select -Skip 2

    $Output = New-Object System.Collections.Generic.List[psobject](1200)

    foreach ($Table in $Tables) {
        $Rows = $Table.Rows
        $HeaderCells = $Rows[0].Cells | foreach {$_.innerText}
        foreach ($Row in ($Rows | select -Skip 1)){

            $Cells = $Row.Cells | foreach {$_.innerText}
        
            $RowObj = New-Object psobject
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
            }
        
            $Href = $Row.getElementsByTagName('A') | foreach {$_.href} | select -First 1
            $RowObj | Add-Member NoteProperty -Name Link -Value $Href

            $Output.Add($RowObj)
        }
    }

    return $Output
}
