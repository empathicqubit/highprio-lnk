# Copyright 2021 EmpathicQubit

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Add-Type -Path "$PSScriptRoot/Gameloop.Vdf.dll"

# https://community.spiceworks.com/scripts/show/4656-powershell-create-menu-easily-add-arrow-key-driven-menu-to-scripts
Function Create-Menu (){
    
    Param(
        [Parameter(Mandatory=$True)][String]$MenuTitle,
        [Parameter(Mandatory=$True)][array]$MenuOptions
    )

    $MaxValue = $MenuOptions.count-1
    $Selection = 0
    $EnterPressed = $False
    
    Clear-Host

    While($EnterPressed -eq $False){
        
        Write-Host "$MenuTitle"

        For ($i=0; $i -le $MaxValue; $i++){
            
            If ($i -eq $Selection){
                Write-Host -BackgroundColor Cyan -ForegroundColor Black "[ $($MenuOptions[$i]) ]"
            } Else {
                Write-Host "  $($MenuOptions[$i])  "
            }

        }

        $KeyInput = $host.ui.rawui.readkey("NoEcho,IncludeKeyDown").virtualkeycode

        Switch($KeyInput){
            13{
                $EnterPressed = $True
                Return $Selection
                Clear-Host
                break
            }

            38{
                If ($Selection -eq 0){
                    $Selection = $MaxValue
                } Else {
                    $Selection -= 1
                }
                Clear-Host
                break
            }

            40{
                If ($Selection -eq $MaxValue){
                    $Selection = 0
                } Else {
                    $Selection +=1
                }
                Clear-Host
                break
            }
            Default{
                Clear-Host
            }
        }
    }
}

Function From-FileName() {
    Param(
        [Parameter(Mandatory=$True)][String]$FileName,
        [Parameter(Mandatory=$False)][String]$GameName
    )

    $lnkName = if($GameName) { $GameName } else { Split-Path -Leaf $FileName }
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$PSScriptRoot\$lnkName.lnk")
    $Shortcut.IconLocation = $FileName
    $Shortcut.TargetPath = 'cmd.exe'
    $Shortcut.Arguments = '/c start "" /b /high "'+$FileName+'"'
    $Shortcut.Save()
}

Function Prompt-SteamGame() {
    if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
        $steamInstallPath = "${env:ProgramFiles(x86)}/Steam"
    }
    else {
        $steamInstallPath = "$env:ProgramFiles/Steam"
    }

    $libraryFolders = [Gameloop.Vdf.VdfConvert]::Deserialize((Get-Content "$steamInstallPath/steamapps/libraryfolders.vdf") -join "`n")

    $steamLibraries = @()

    $steamLibraries += @($steamInstallPath)
    $steamLibraries += Get-Member -InputObject $libraryFolders.Value -MemberType Dynamic | where-object -Property Name -Match "[0-9]+" | foreach { $libraryFolders.Value[$_.Name].ToString() }

    $appManifests = @()

    foreach($steamLibrary in $steamLibraries) {
        foreach($manifestPath in (Get-Item "$steamLibrary/steamapps/appmanifest_*.acf")) {
            $appManifest = [Gameloop.Vdf.VdfConvert]::Deserialize((Get-Content "$manifestPath") -join "`n")
            $appManifests += @(@{ path = $manifestPath.FullName; name = $appManifest.Value["name"].ToString() ; installdir = $appManifest.Value["installdir"].ToString() })
        }
    }

    $idx = Create-Menu -MenuTitle "Select a game" -MenuOptions ($appManifests | % {$_.name} )
    $appManifest = $appManifests[$idx]
    $installDir = "$(Split-Path $appManifest.path)/common/$($appManifest.installdir)"

    $exes = Get-ChildItem -Recurse $installDir -Include "*.exe" | sort {([regex]::Split($_, '[\\/]+')).Count}, {$_}
    $idx = Create-Menu -MenuTitle "Select an executable" -MenuOptions ($exes | % {Push-Location $installDir ; Resolve-Path -relative $_.FullName ; Pop-Location } )

    From-FileName -FileName $exes[$idx].FullName -GameName $appManifest.installdir
}


if ($args.Count -gt 0) {
    From-FileName -FileName ($args -join " ")
}
else {
    Prompt-SteamGame
}