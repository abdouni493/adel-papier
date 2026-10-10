# Lance automatiquement la passerelle de la pointeuse a l'ouverture de session Windows.
$root = Split-Path -Parent $PSScriptRoot
$bat = Join-Path $root 'lancer-pointeuse.bat'
$startup = [Environment]::GetFolderPath('Startup')
$lnk = Join-Path $startup 'Pointeuse Adel Papier.lnk'
$ws = New-Object -ComObject WScript.Shell
$s = $ws.CreateShortcut($lnk)
$s.TargetPath = $bat
$s.WorkingDirectory = $root
$s.WindowStyle = 7   # reduite
$s.Description = 'Passerelle pointeuse ZKTeco -> Adel Papier'
$s.Save()
Write-Output "Raccourci de demarrage cree : $lnk"
