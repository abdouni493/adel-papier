# Configure le PC pour une pointeuse ZKTeco branchee directement en cable sur le PC.
#   PC (carte Ethernet) : 192.168.1.50 / 255.255.255.0
#   Pointeuse           : 192.168.1.201, serveur ADMS = 192.168.1.50, port 8090
$ErrorActionPreference = 'Continue'
$pcIp     = '192.168.1.50'
$deviceIp = '192.168.1.201'
$port     = 8090
$root     = Split-Path -Parent $PSScriptRoot

function Titre($t) { Write-Host ''; Write-Host "=== $t ===" -ForegroundColor Cyan }

# --- 1. Carte Ethernet (cable) ---
Titre '1/5 Carte reseau Ethernet'
$cartes = Get-NetAdapter -Physical | Where-Object { $_.MediaType -eq '802.3' }
$carte = $cartes | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
if (-not $carte) {
  Write-Host '[!] Aucune carte Ethernet connectee. Verifiez le cable PC <-> pointeuse et que la pointeuse est allumee.' -ForegroundColor Red
  $cartes | Format-Table Name, InterfaceDescription, Status -AutoSize
  return
}
Write-Host "Carte trouvee : $($carte.Name) ($($carte.InterfaceDescription))"

# --- 2. IP fixe sur cette carte ---
Titre "2/5 IP fixe $pcIp sur '$($carte.Name)'"
netsh interface ip set address name="$($carte.Name)" static $pcIp 255.255.255.0 | Out-Host
Start-Sleep -Seconds 4
$ip = (Get-NetIPAddress -InterfaceIndex $carte.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
if ($ip -contains $pcIp) { Write-Host "OK : $pcIp" -ForegroundColor Green }
else { Write-Host "[!] IP actuelle : $ip (attendu $pcIp)" -ForegroundColor Red }

# --- 3. Pare-feu ---
Titre "3/5 Pare-feu : port $port"
netsh advfirewall firewall delete rule name="Pointeuse ZKTeco $port" | Out-Null
netsh advfirewall firewall add rule name="Pointeuse ZKTeco $port" dir=in action=allow protocol=TCP localport=$port profile=any | Out-Null
# Si on a clique "Annuler" a l'alerte pare-feu de Node.js, Windows a cree des regles BLOQUER
# pour node.exe : elles passent avant les regles "autoriser". On les supprime.
$bloques = Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue |
  Where-Object { $_.Program -like '*node.exe' } | Get-NetFirewallRule |
  Where-Object { $_.Action -eq 'Block' -and $_.Direction -eq 'Inbound' }
foreach ($r in $bloques) {
  Write-Host "Suppression de la regle bloquante : $($r.DisplayName) ($($r.Profile))" -ForegroundColor Yellow
  Remove-NetFirewallRule -Name $r.Name
}
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if ($node) {
  netsh advfirewall firewall delete rule name="Node.js Pointeuse" | Out-Null
  netsh advfirewall firewall add rule name="Node.js Pointeuse" dir=in action=allow program="$node" enable=yes profile=any | Out-Null
}
Write-Host 'OK' -ForegroundColor Green

# --- 4. Demarrage automatique ---
Titre '4/5 Demarrage automatique'
& (Join-Path $PSScriptRoot 'install-pointeuse-startup.ps1')

# --- 5. Test de la pointeuse ---
Titre "5/5 Test de la pointeuse ($deviceIp)"
if (Test-Connection -ComputerName $deviceIp -Count 2 -Quiet) {
  Write-Host "OK : la pointeuse repond sur $deviceIp" -ForegroundColor Green
} else {
  Write-Host "[!] La pointeuse ne repond pas sur $deviceIp." -ForegroundColor Yellow
  Write-Host '    Reglez la pointeuse (puis redemarrez-la) :'
  Write-Host '    Menu > COMM. > Ethernet : DHCP desactive'
  Write-Host "        IP $deviceIp   Masque 255.255.255.0   Passerelle $pcIp"
}

Write-Host ''
Write-Host 'Sur la pointeuse : Menu > COMM. > Serveur Cloud (ADMS)' -ForegroundColor Cyan
Write-Host "    Adresse du serveur : $pcIp    Port : $port"
Write-Host '    HTTPS : desactive   Proxy : desactive   Nom de domaine : desactive'
Write-Host '    Puis redemarrez la pointeuse.'

# --- Lancer la passerelle si elle ne tourne pas ---
# (on arrete l'ancienne passerelle et sa fenetre pour relancer la version de ce dossier)
Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -like '*lancer-pointeuse.bat*' -or $_.CommandLine -like '*bridge.mjs*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2
Write-Host ''
Write-Host 'Lancement de la passerelle...' -ForegroundColor Cyan
Start-Process -FilePath (Join-Path $root 'lancer-pointeuse.bat') -WorkingDirectory $root -WindowStyle Minimized
Write-Host "Page d'etat : http://localhost:$port (la pointeuse apparait 1-2 min apres son redemarrage)"
