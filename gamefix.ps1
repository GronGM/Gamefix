param(
    [ValidateSet('install','uninstall','status','test','retest','run','deadips','diag','shortcut')][string]$Action = 'status',
    [switch]$Pause
)
# GameFix - obhod DPI dlya igr (WARDOGS, Discord i dr.). Dvizhok: zapret/winws (bol-van, MIT).
# Sluzhba Windows "GameFix". Strategiya podbiraetsya avtomaticheski pod provaydera pri ustanovke.
$ErrorActionPreference = 'Continue'
$SVC = 'GameFix'
$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
$BIN = "$ROOT\bin\"; $LISTS = "$ROOT\lists\"; $CFG = "$ROOT\config.txt"; $LOG = "$ROOT\gamefix-log.txt"
$DEFAULT_PINGTARGET = '93.190.139.96'   # server WARDOGS (EU, Worldstream). Svoy adres: stroka pingtarget=IP v config.txt
function W($s) { Write-Host $s; Add-Content -Encoding UTF8 -Path $LOG -Value ("[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $s) }
function Finish { if ($Pause) { Write-Host ''; Read-Host 'Nazhmi Enter, chtoby zakryt' | Out-Null } }

# ---------- strategii (poryadok = prioritet). TCP - dlya HTTPS/HTTP k domenam iz hosts.txt ----------
$STRATEGIES = [ordered]@{
  'ALT11'         = "--dpi-desync=fake,multisplit --dpi-desync-split-seqovl=664 --dpi-desync-split-pos=1 --dpi-desync-fooling=ts --dpi-desync-repeats=8 --dpi-desync-split-seqovl-pattern=${BIN}tls_clienthello_max_ru.bin --dpi-desync-fake-tls=${BIN}stun2.bin --dpi-desync-fake-tls=${BIN}tls_clienthello_max_ru.bin --dpi-desync-fake-http=${BIN}tls_clienthello_max_ru.bin"
  'ALT12'         = "--dpi-desync=fake,multisplit --dpi-desync-split-seqovl=664 --dpi-desync-split-pos=1 --dpi-desync-fooling=ts --dpi-desync-repeats=8 --dpi-desync-split-seqovl-pattern=${BIN}tls_clienthello_max_ru.bin --dpi-desync-fake-tls=${BIN}stun.bin --dpi-desync-fake-tls=${BIN}tls_clienthello_max_ru.bin --dpi-desync-fake-http=${BIN}tls_clienthello_max_ru.bin"
  'EXP'           = "--dpi-desync=fake,multisplit --dpi-desync-split-seqovl=480 --dpi-desync-split-pos=1 --dpi-desync-fooling=ts --dpi-desync-repeats=4 --dpi-desync-split-seqovl-pattern=${BIN}stun2.bin --dpi-desync-fake-tls=${BIN}tls_clienthello_max_ru.bin --dpi-desync-fake-http=${BIN}tls_clienthello_max_ru.bin"
  'FAKE_TLS_AUTO' = "--dpi-desync=fake,multidisorder --dpi-desync-split-pos=1,midsld --dpi-desync-repeats=11 --dpi-desync-fooling=badseq --dpi-desync-fake-tls=0x00000000 --dpi-desync-fake-tls=! --dpi-desync-fake-tls-mod=rnd,dupsid,sni=www.google.com --dpi-desync-fake-http=${BIN}tls_clienthello_max_ru.bin"
  'SIMPLE_FAKE'   = "--dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-fooling=ts --dpi-desync-fake-tls=${BIN}tls_clienthello_www_google_com.bin --dpi-desync-fake-http=${BIN}tls_clienthello_max_ru.bin"
  'ALT9'          = "--dpi-desync=hostfakesplit --dpi-desync-repeats=4 --dpi-desync-fooling=ts,md5sig --dpi-desync-hostfakesplit-mod=host=ozon.ru"
  'ALT8'          = "--dpi-desync=fake --dpi-desync-fake-tls-mod=none --dpi-desync-repeats=6 --dpi-desync-fooling=badseq --dpi-desync-badseq-increment=2 --dpi-desync-fake-http=${BIN}tls_clienthello_max_ru.bin"
  'ALT2'          = "--dpi-desync=multisplit --dpi-desync-split-seqovl=652 --dpi-desync-split-pos=2 --dpi-desync-split-seqovl-pattern=${BIN}tls_clienthello_www_google_com.bin"
  'GENERAL'       = "--dpi-desync=multisplit --dpi-desync-split-seqovl=568 --dpi-desync-split-pos=1 --dpi-desync-split-seqovl-pattern=${BIN}tls_clienthello_4pda_to.bin"
}

# Programmy, kotorye mogut vliyat na ping i poteri (ne obhodchiki - prosto pokazyvaem v otchete)
$SUSPECTS = @(
  @('^(qbittorrent|utorrent|bittorrent|transmission-qt|transmission|deluge|tixati|biglybt|vuze|tribler|frostwire|zona)$', 'торрент'),
  @('^(mediaget|mediaget2)$', 'торрент MediaGet'),
  @('^(fdm|aria2c|motrix)$', 'менеджер загрузок'),
  @('^(avp|avpui)$', 'Kaspersky, проверка трафика'),
  @('^(dwservice|dwnetfilter|spideragent)$', 'Dr.Web, проверка трафика'),
  @('^(ekrn)$', 'ESET, проверка трафика'),
  @('^(cfosspeed|cfosspeeds)$', 'cFosSpeed'),
  @('^(killernetworkservice|killeranalyticsservice|kndbwm)$', 'Killer Network'),
  @('^(gamefirst|gamefirstservice|gamefirstv)$', 'ASUS GameFirst'),
  @('^(noping|wtfast|mudfish|lagofast|lagofastservice)$', 'игровой ускоритель'),
  @('^(warp-svc|amneziavpn|hiddify|nekoray|nekobox|v2rayn|xray|sing-box|clash|clash-verge|mihomo|outline|happ)$', 'VPN/прокси')
)

function Get-Cfg($key, $default) {
    if (Test-Path $CFG) { $l = Get-Content $CFG | Where-Object { $_ -match "^$key=" } | Select-Object -First 1; if ($l) { return ($l -replace "^$key=", '').Trim() } }
    return $default
}
function Set-Cfg($key, $value) {
    $lines = @(); if (Test-Path $CFG) { $lines = @(Get-Content $CFG | Where-Object { $_ -notmatch "^$key=" }) }
    Set-Content -Path $CFG -Value ($lines + "$key=$value")
}

# Spiski domenov: bez kommentariev i pustyh strok
function Read-Hosts($file) { return @(Get-Content $file -EA SilentlyContinue | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') }) }
# Popadaet li domen pod spisok (sam domen ili poddomen)
function Covered([string]$h, $list) { foreach ($d in $list) { if ($h -eq $d -or $h.EndsWith(".$d")) { return $true } }; return $false }
# winws chitaet spiski tolko v UTF-8 bez BOM
function Write-List($path, $lines) { [IO.File]::WriteAllLines($path, [string[]]@($lines), (New-Object System.Text.UTF8Encoding($false))) }
function Has-Bom($path) {
    $b = [IO.File]::ReadAllBytes($path)
    if ($b.Length -ge 2 -and (($b[0] -eq 0xFF -and $b[1] -eq 0xFE) -or ($b[0] -eq 0xFE -and $b[1] -eq 0xFF))) { return 'UTF-16' }
    if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { return 'UTF-8 BOM' }
    return ''
}
function Fix-ListEncoding {
    foreach ($f in 'hosts.txt','test-hosts.txt','ipset-exclude.txt','ipset-exclude-udp.txt') {
        $p = "$LISTS$f"; if (-not (Test-Path $p)) { continue }
        $e = Has-Bom $p
        if ($e) { Write-List $p @(Get-Content $p); W "  lists\$f byl v $e - peresohranen v UTF-8 bez BOM (inache winws ego ne ponimaet)" }
    }
}

# Adresa, kotorye UDP-profili NE trogayut: lokalnaya set i golosovoy chat Vivox (Unity) - v WARDOGS golos idet cherez nego.
# Feyki v nachale UDP-potoka lomayut ishodyashchiy golos Vivox (sobesednikov slyshno, tebya - net).
# Diapazony: support.unity.com, "Vivox: What IPs and ports are required" (media - UDP 12000-54000).
# V samom fayle - tolko adresa, bez kommentariev (ipset ih ne zhdet).
$UDP_EXCLUDE_DEFAULT = @('10.0.0.0/8','172.16.0.0/12','192.168.0.0/16','100.64.0.0/10','85.236.96.0/21','85.236.104.0/23')
function Ensure-UdpExclude { $p = "${LISTS}ipset-exclude-udp.txt"; if (-not (Test-Path $p)) { Write-List $p $UDP_EXCLUDE_DEFAULT } }

function Get-Args([string]$strategy, [string]$hostfile) {
    $tcp = $STRATEGIES[$strategy]
    $udpGame = (Get-Cfg 'udp' 'off') -eq 'on'
    $a = @(
        "--wf-tcp=80,443,2053,2083,2087,2096,8443", $(if ($udpGame) { "--wf-udp=443,1024-65535" } else { "--wf-udp=443,19294-19344,50000-50100" }),
        "--filter-udp=443", "--hostlist=$hostfile", "--ipset-exclude=${LISTS}ipset-exclude.txt", "--dpi-desync=fake", "--dpi-desync-repeats=11", "--dpi-desync-fake-quic=${BIN}quic_initial_www_google_com.bin", "--new",
        "--filter-udp=19294-19344,50000-50100", "--filter-l7=discord,stun", "--ipset-exclude=${LISTS}ipset-exclude-udp.txt", "--dpi-desync=fake", "--dpi-desync-fake-discord=${BIN}ACTIVE_DISCORD_UDP.bin", "--dpi-desync-fake-stun=${BIN}ACTIVE_DISCORD_UDP.bin", "--dpi-desync-repeats=6", "--new",
        "--filter-tcp=2053,2083,2087,2096,8443", "--hostlist-domains=discord.media", "--dpi-desync=fake,multisplit", "--dpi-desync-split-seqovl=681", "--dpi-desync-split-pos=1", "--dpi-desync-fooling=ts", "--dpi-desync-repeats=8", "--dpi-desync-split-seqovl-pattern=${BIN}tls_clienthello_www_google_com.bin", "--dpi-desync-fake-tls=${BIN}tls_clienthello_www_google_com.bin", "--new",
        "--filter-tcp=80,443", "--hostlist=$hostfile", "--ipset-exclude=${LISTS}ipset-exclude.txt", $tcp
    )
    # Igrovoy UDP-filtr (feyki na pervye pakety UDP-potokov). Po umolchaniyu VYKL: u provayderov s limitom UDP po obemu on tolko vredit.
    # Vklyuchit: v config.txt stroka udp=on, potom install.bat
    if ($udpGame) { $a += @("--new", "--filter-udp=1024-65535", "--ipset-exclude=${LISTS}ipset-exclude-udp.txt", "--dpi-desync=fake", "--dpi-desync-repeats=10", "--dpi-desync-any-protocol=1", "--dpi-desync-fake-unknown-udp=${BIN}ACTIVE_GAME_UDP.bin", "--dpi-desync-cutoff=n4") }
    return ($a -join ' ')
}

function Stop-Others {
    foreach ($n in $SVC,'zapret','GMzapret') { $s = Get-Service $n -EA SilentlyContinue; if ($s -and $s.Status -ne 'Stopped') { W "  ostanavlivayu sluzhbu '$n'"; Stop-Service $n -Force -EA SilentlyContinue } }
    Start-Sleep 1
    $p = Get-Process winws -EA SilentlyContinue
    if ($p) { W ("  ostanavlivayu drugoy winws (pid " + ($p.Id -join ',') + ")"); $p | Stop-Process -Force -EA SilentlyContinue; Start-Sleep 2 }
}

function Probe($h) { $c = & curl.exe -s -o NUL -w '%{http_code}' -m 6 "https://$h/" 2>&1; return "$c" }

function TcpOk($ip) {
    $c = New-Object System.Net.Sockets.TcpClient
    try { $iar = $c.BeginConnect($ip, 443, $null, $null); if ($iar.AsyncWaitHandle.WaitOne(2500)) { $c.EndConnect($iar); return $true } else { return $false } } catch { return $true } finally { $c.Close() }
}

# Pochemu domen ne otkryvaetsya: dns - adres ne nahoditsya, ip - k adresam ne prohodit dazhe TCP (obhod bessilen), dpi - rezhut po soderzhimomu
function Block-Kind($h) {
    $all = @(); try { $all = @([System.Net.Dns]::GetHostAddresses($h)) } catch {}
    if (-not $all.Count) { return 'dns' }
    $v4 = @($all | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | ForEach-Object { $_.IPAddressToString })
    if (-not $v4.Count) { return 'dpi' }
    foreach ($ip in ($v4 | Select-Object -First 3)) { if (TcpOk $ip) { return 'dpi' } }
    return 'ip'
}

# Pachka ping-ov ko vsem celyam parallelno: poteri, sredniy, maksimum, dzhitter
function Ping-Many([string[]]$targets, [int]$n = 40) {
    $tasks = @{}
    foreach ($t in $targets) { $tasks[$t] = New-Object System.Collections.ArrayList }
    for ($i = 0; $i -lt $n; $i++) {
        foreach ($t in $targets) { try { [void]$tasks[$t].Add((New-Object System.Net.NetworkInformation.Ping).SendPingAsync($t, 1000)) } catch {} }
        Start-Sleep -Milliseconds 100
    }
    $res = @{}
    foreach ($t in $targets) {
        $list = @($tasks[$t])
        if ($list.Count) { try { [void][System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]$list, 3000) } catch {} }
        $rtt = @(); foreach ($k in $list) { if ($k.Status -eq 'RanToCompletion' -and $k.Result.Status -eq 'Success') { $rtt += [int]$k.Result.RoundtripTime } }
        $jit = 0
        if ($rtt.Count -gt 1) { $s = 0; for ($j = 1; $j -lt $rtt.Count; $j++) { $s += [math]::Abs($rtt[$j] - $rtt[$j - 1]) }; $jit = [math]::Round($s / ($rtt.Count - 1), 1) }
        $res[$t] = [pscustomobject]@{
            Sent = $n; Got = $rtt.Count
            Loss = [math]::Round(100.0 * ($n - $rtt.Count) / $n, 1)
            Avg  = $(if ($rtt.Count) { [math]::Round(($rtt | Measure-Object -Average).Average) } else { 0 })
            Max  = $(if ($rtt.Count) { ($rtt | Measure-Object -Maximum).Maximum } else { 0 })
            Jit  = $jit
        }
    }
    return $res
}

# Mertvye IP: adresa domenov iz spiska, k kotorym ne prohodit dazhe TCP (blokirovka po IP).
# Zakryvaem ih lokalno pravilom brandmauera - prilozhenie srazu perehodit k sleduyushchemu adresu.
function Do-DeadIps {
    W "=== MERTVYE IP (blokirovka po adresu) ==="
    Get-NetFirewallRule -DisplayName 'GameFix-deadip*' -EA SilentlyContinue | Remove-NetFirewallRule -EA SilentlyContinue
    $domains = @('discord.com','gateway.discord.gg','cdn.discordapp.com','discordapp.com') + @(Read-Hosts "${LISTS}hosts.txt")
    $dead = @(); $seen = @{}
    foreach ($d in ($domains | Select-Object -Unique)) {
        $ips = @(); try { $ips = @((Resolve-DnsName $d -Server 8.8.8.8 -Type A -EA SilentlyContinue | Where-Object { $_.Type -eq 'A' -and $_.IPAddress }).IPAddress | Where-Object { $_ }) } catch {}
        $alive = 0; $bad = @()
        foreach ($ip in $ips) { if ($seen.ContainsKey($ip)) { continue }; $seen[$ip] = 1; if (TcpOk $ip) { $alive++ } else { $bad += $ip } }
        # zakryvaem tolko esli u domena est zhivye adresa - inache zakryvat nechego (blokirovan celikom)
        if ($bad.Count -and $alive -gt 0) { $dead += $bad; W ("  {0,-40} mertvye: {1}" -f $d, ($bad -join ', ')) }
        elseif ($bad.Count) { W ("  {0,-40} VSE adresa mertvy ({1}) - tolko VPN" -f $d, $bad.Count) }
    }
    if ($dead.Count) {
        New-NetFirewallRule -DisplayName 'GameFix-deadip' -Direction Outbound -Action Block -RemoteAddress ($dead | Select-Object -Unique) -Profile Any -Description 'GameFix: zablokirovannye provayderom IP, chtoby prilozheniya srazu brali sleduyushchiy adres' -EA SilentlyContinue | Out-Null
        W ("  zakryto lokalno: " + $dead.Count + " IP (pravilo brandmauera GameFix-deadip)")
    } else { W "  mertvyh IP ne naydeno" }
}

function Do-Autotest {
    W "=== PODBOR STRATEGII (provayder) ==="
    Stop-Others
    $tun = Get-NetAdapter -EA SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and ($_.Name -match 'wwan|tun' -or $_.InterfaceDescription -match 'TUN|TAP|Wintun|WireGuard') }
    if ($tun) { W ("  !! VKLYUCHEN VPN (" + ($tun.Name -join ', ') + ") - vyklyuchi ego i zapusti snova, inache podbor nevernyy"); return $null }
    $svcHosts = Read-Hosts "${LISTS}hosts.txt"
    $hosts = Read-Hosts "${LISTS}test-hosts.txt"
    # Test idet s TEM ZHE spiskom, chto i sluzhba (hosts.txt), plyus kontrolnye domeny iz test-hosts.txt.
    # Ran'she test shel tolko po test-hosts.txt, a sluzhba - po hosts.txt, i rezultaty ne sovpadali.
    $testList = "${LISTS}autotest-hosts.txt"
    Write-List $testList (@($svcHosts) + @($hosts) | Select-Object -Unique)
    $base = @{}; foreach ($h in $hosts) { $base[$h] = Probe $h }
    $blocked = @($hosts | Where-Object { $base[$_] -eq '000' })
    W ("  bez obhoda: " + (($hosts | ForEach-Object { "$_=" + $base[$_] }) -join '  '))
    if ($blocked.Count -eq 0) { Remove-Item $testList -EA SilentlyContinue; $script:TestPassed = @(); W "  Nichego ne zablokirovano - obhod ne nuzhen. Stavlyu ALT11 na vsyakiy sluchay."; return 'ALT11' }
    $best = $null; $bestScore = -1; $bestOk = 0; $bestPassed = @()
    foreach ($name in $STRATEGIES.Keys) {
        $errf = "$ROOT\winws-test-err.txt"
        $p = Start-Process -FilePath "${BIN}winws.exe" -ArgumentList (Get-Args $name $testList) -WorkingDirectory $BIN -WindowStyle Hidden -PassThru -RedirectStandardError $errf -RedirectStandardOutput "$ROOT\winws-test-out.txt"
        Start-Sleep 3
        if ($p.HasExited) { $e = (Get-Content $errf -Tail 2 -EA SilentlyContinue) -join ' | '; W ("  {0,-14} ne zapustilsya: {1}" -f $name, $e); continue }
        # Domeny, kotorye obhodit sluzhba (Discord), vazhnee kontrolnyh (x.com): 2 balla protiv 1
        $ok = 0; $score = 0; $res = @(); $passed = @()
        foreach ($h in $blocked) { $c = Probe $h; if ($c -ne '000') { $ok++; $passed += $h; $score += $(if (Covered $h $svcHosts) { 2 } else { 1 }) }; $res += "$h=$c" }
        Stop-Process -Id $p.Id -Force -EA SilentlyContinue; Start-Sleep 1
        W ("  {0,-14} {1}/{2}  {3}" -f $name, $ok, $blocked.Count, ($res -join '  '))
        if ($score -gt $bestScore) { $bestScore = $score; $best = $name; $bestOk = $ok; $bestPassed = $passed }
        if ($ok -eq $blocked.Count) { break }
    }
    Remove-Item $testList -EA SilentlyContinue
    if ($bestOk -le 0) { W "  Ni odna strategiya ne srabotala. Vozmozhno, provayder blokiruet inache - napishi tomu, kto dal etot arhiv."; if (Get-Service $SVC -EA SilentlyContinue) { Start-Service $SVC -EA SilentlyContinue }; return $null }
    W ("  VYBRANA: " + $best + " (" + $bestOk + "/" + $blocked.Count + ")")
    $script:TestPassed = $bestPassed
    return $best
}

# Posle ustanovki: daet li sluzhba tot zhe rezultat, chto i podbor. Esli net - odin perezapusk i povtornaya proverka.
function Verify-Service {
    $svcHosts = Read-Hosts "${LISTS}hosts.txt"
    if ($script:TestPassed) { $check = @($script:TestPassed | Where-Object { Covered $_ $svcHosts }) }
    else { $check = @(Read-Hosts "${LISTS}test-hosts.txt" | Where-Object { Covered $_ $svcHosts }) }
    if (-not $check.Count) { return $true }
    for ($try = 1; $try -le 2; $try++) {
        $res = @(); $bad = 0
        foreach ($h in $check) { $c = Probe $h; $res += "$h=$c"; if ($c -eq '000') { $bad++ } }
        W ("  proverka sluzhby: " + ($res -join '  '))
        if ($bad -eq 0) { return $true }
        if ($try -eq 1) {
            W "  !! sluzhba ne povtoryaet rezultat podbora - perezapuskayu ee"
            Stop-Service $SVC -Force -EA SilentlyContinue; Start-Sleep 1
            Get-Process winws -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue; Start-Sleep 2
            Start-Service $SVC -EA SilentlyContinue; Start-Sleep 4
            W ("  process winws posle perezapuska: " + @(Get-Process winws -EA SilentlyContinue).Count)
        }
    }
    return $false
}

function Do-Install {
    W "=== USTANOVKA GameFix ==="
    Remove-Item "$ROOT\verdict.txt" -EA SilentlyContinue
    foreach ($f in 'winws.exe','WinDivert.dll','WinDivert64.sys','cygwin1.dll') { if (-not (Test-Path "$BIN$f")) { W "  NET FAYLA bin\$f - arhiv nepolnyy"; return } }
    if ($ROOT -match '\s') { W "  Put k papke soderzhit probel: $ROOT - peremesti papku, naprimer, v C:\GameFix"; return }
    Ensure-UdpExclude
    Fix-ListEncoding
    $script:TestPassed = $null
    $strategy = Get-Cfg 'strategy' ''
    if (-not $strategy -or -not $STRATEGIES.Contains($strategy)) { $strategy = Do-Autotest; if (-not $strategy) { return }; Set-Cfg 'strategy' $strategy }
    if (-not (Test-Path $CFG) -or -not (Get-Content $CFG | Where-Object { $_ -match '^udp=' })) { Set-Cfg 'udp' 'off' }
    W ("  strategiya: " + $strategy + ", igrovoy UDP-filtr: " + (Get-Cfg 'udp' 'off'))
    Stop-Others
    $s = Get-Service $SVC -EA SilentlyContinue
    if ($s) { Stop-Service $SVC -Force -EA SilentlyContinue; & sc.exe delete $SVC | Out-Null; Start-Sleep 2 }
    $bp = "${BIN}winws.exe " + (Get-Args $strategy "${LISTS}hosts.txt")
    $r = & sc.exe create $SVC binPath= $bp DisplayName= "GameFix" start= auto
    W ("  " + ($r -join ' '))
    & sc.exe description $SVC "GameFix: obhod DPI dlya igr i Discord (zapret/winws)" | Out-Null
    & sc.exe failure $SVC reset= 60 actions= restart/5000/restart/5000/restart/5000 | Out-Null
    & sc.exe start $SVC | Out-Null; Start-Sleep 3
    Do-DeadIps
    Do-Shortcut
    Do-Status
    if ((Get-Service $SVC -EA SilentlyContinue).Status -ne 'Running') { W "  Sluzhba ne zapustilas. Prishli fayl gamefix-log.txt tomu, kto dal arhiv."; return }
    if (Verify-Service) { W "  GOTOVO. GameFix rabotaet i budet vklyuchatsya vmeste s Windows." }
    else { W "  !! Sluzhba zapushchena, no ne otkryvaet to, chto otkryval podbor. Sobirayu diagnostiku."; Do-Diag -AfterInstall }
}

function Do-Shortcut {
    try {
        $desk = [Environment]::GetFolderPath('Desktop'); $lnk = "$desk\GameFix.lnk"
        $ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut($lnk)
        $s.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $s.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$ROOT\GameFix-ui.ps1`""
        $s.WorkingDirectory = $ROOT; $s.Description = 'GameFix'
        if (Test-Path "$ROOT\gamefix.ico") { $s.IconLocation = "$ROOT\gamefix.ico,0" }
        $s.Save()
        $b = [IO.File]::ReadAllBytes($lnk); $b[0x15] = $b[0x15] -bor 0x20; [IO.File]::WriteAllBytes($lnk, $b)   # "zapusk ot administratora"
        W "  yarlyk na rabochem stole: GameFix"
    } catch { W ("  yarlyk ne sozdan: " + $_.Exception.Message) }
}

function Do-Diag([switch]$AfterInstall) {
    W "=== DIAGNOSTIKA ==="
    $R = New-Object System.Collections.ArrayList
    function A($s) { [void]$R.Add($s); W ("  " + $s) }
    $os = Get-CimInstance Win32_OperatingSystem
    A ("GameFix otchet " + (Get-Date -Format 'yyyy-MM-dd HH:mm') + " | " + $os.Caption + " " + $os.Version + " | papka: " + $ROOT)

    # --- sluzhba, winws, drayver ---
    $svc = Get-Service $SVC -EA SilentlyContinue
    $wp = @(Get-CimInstance Win32_Process -Filter "Name='winws.exe'" -EA SilentlyContinue)
    $wpOurs = @($wp | Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($ROOT, [StringComparison]::OrdinalIgnoreCase) })
    $cfgLine = if (Test-Path $CFG) { (Get-Content $CFG | Where-Object { $_.Trim() }) -join ' ' } else { 'config net' }
    A ("sluzhba: " + $(if ($svc) { $svc.Status } else { 'ne ustanovlena' }) + " | winws nash: " + $(if ($wpOurs.Count) { 'rabotaet' } else { 'net' }) + " | " + $cfgLine)
    if ($wp.Count -gt 1 -or $wp.Count -ne $wpOurs.Count) { A ("winws zapushcheno: " + $wp.Count + " -> " + (($wp | ForEach-Object { "pid " + $_.ProcessId + " " + $_.ExecutablePath }) -join '; ')) }
    $cmdOk = $null
    $svcCim = Get-CimInstance Win32_Service -Filter "Name='$SVC'" -EA SilentlyContinue
    $st = Get-Cfg 'strategy' ''
    if ($svcCim -and $svcCim.PathName -and $st -and $STRATEGIES.Contains($st)) {
        $exp = "${BIN}winws.exe " + (Get-Args $st "${LISTS}hosts.txt")
        $cmdOk = (($svcCim.PathName -replace '"', '').Trim() -eq ($exp -replace '"', '').Trim())
        A ("komanda sluzhby: " + $(if ($cmdOk) { 'sovpadaet s nastroykami' } else { 'NE sovpadaet (papku peremeshchali ili menyali config.txt)' }))
    }
    $wd = @(Get-CimInstance Win32_SystemDriver -EA SilentlyContinue | Where-Object { $_.Name -match 'divert' })
    if ($wd.Count) { A ("WinDivert: " + (($wd | ForEach-Object { $_.Name + " " + $_.State + " " + $_.PathName }) -join '; ')) }
    $wdForeign = @($wd | Where-Object { $_.State -eq 'Running' -and $_.PathName -and $_.PathName.IndexOf($ROOT, [StringComparison]::OrdinalIgnoreCase) -lt 0 -and $_.PathName -notmatch 'GameFix' })
    $hostsEnc = if (Test-Path "${LISTS}hosts.txt") { Has-Bom "${LISTS}hosts.txt" } else { 'net fayla' }
    A ("hosts.txt: " + (Read-Hosts "${LISTS}hosts.txt").Count + " domenov, kodirovka " + $(if ($hostsEnc) { $hostsEnc } else { 'OK' }))

    # --- VPN i drugie obhodchiki/uskoriteli ---
    $vpn = Get-NetAdapter -EA SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and ($_.Name -match 'wwan|tun' -or $_.InterfaceDescription -match 'TUN|TAP|Wintun|WireGuard') }
    A ("VPN-adapter: " + $(if ($vpn) { ($vpn.Name -join ', ') } else { 'net' }))
    $procs = @(Get-Process -EA SilentlyContinue)
    $others = @($procs | Where-Object { $_.ProcessName -match '^(winws|goodbyedpi|ciadpi|byedpi|spoofdpi|gearup|exitlag|wgc)' -and $_.Path -notlike "$ROOT*" })
    $osvc = @(Get-Service -EA SilentlyContinue | Where-Object { $_.Name -match '^(zapret|GoodbyeDPI|GMzapret)$' -and $_.Status -eq 'Running' })
    $otherNames = @(@($others | ForEach-Object { $_.ProcessName }) + @($osvc | ForEach-Object { 'sluzhba ' + $_.Name }) + @($wdForeign | ForEach-Object { 'drayver WinDivert iz ' + $_.PathName }) | Select-Object -Unique)
    A ("drugie obhodchiki/uskoriteli: " + $(if ($otherNames.Count) { $otherNames -join ', ' } else { 'net' }))
    $sus = @()
    foreach ($pr in ($procs | Select-Object -ExpandProperty ProcessName -Unique)) { foreach ($x in $SUSPECTS) { if ($pr -match $x[0]) { $sus += "$pr ($($x[1]))"; break } } }
    A ("mogut vliyat na ping: " + $(if ($sus.Count) { $sus -join ', ' } else { 'net' }))
    $heavy = @(Get-NetTCPConnection -State Established -EA SilentlyContinue | Group-Object OwningProcess | Where-Object { $_.Count -ge 40 } | Sort-Object Count -Descending | Select-Object -First 3 | ForEach-Object { (Get-Process -Id ([int]$_.Name) -EA SilentlyContinue).ProcessName + " (" + $_.Count + ")" })
    if ($heavy.Count) { A ("mnogo soedineniy: " + ($heavy -join ', ')) }
    $dns = (Get-DnsClientServerAddress -AddressFamily IPv4 -EA SilentlyContinue | Where-Object { $_.ServerAddresses } | Select-Object -First 1).ServerAddresses -join ', '
    A ("DNS: " + $dns)

    # --- dostupnost: tolko to, chto obhodit sluzhba (Discord) + servery igry ---
    $svcHosts = Read-Hosts "${LISTS}hosts.txt"
    $hosts = @(@(Read-Hosts "${LISTS}test-hosts.txt" | Where-Object { Covered $_ $svcHosts }) + @('gateway.discord.gg','cdn.discordapp.com','live.wardogs.bulkhead.pragmaengine.com','api.epicgames.dev','unity.vivox.com') | Select-Object -Unique)
    $bad = @(); $good = @(); $badDpi = @(); $badIp = @(); $badDns = @()
    foreach ($h in $hosts) {
        $c = Probe $h; $kind = ''
        if ($c -eq '000') {
            $bad += $h; $kind = Block-Kind $h
            if ($kind -eq 'ip') { $badIp += $h } elseif ($kind -eq 'dns') { $badDns += $h } else { $badDpi += $h }
        } else { $good += $h }
        $note = if ($kind -eq 'ip') { '  (blokirovka po IP)' } elseif ($kind -eq 'dns') { '  (DNS ne nahodit adres)' } elseif ($kind) { '  (rezhet DPI)' } else { '' }
        A ("  {0,-42} HTTP {1}{2}" -f $h, $c, $note)
    }

    # --- set: podklyuchenie, nagruzka, ping i poteri ---
    $ipc = Get-NetIPConfiguration -EA SilentlyContinue | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
    $gw = $null; $ad = $null; $wifi = $false; $sig = ''
    if ($ipc) { $gw = @($ipc.IPv4DefaultGateway)[0].NextHop; $ad = $ipc.NetAdapter; $wifi = [bool]($ad.PhysicalMediaType -match '802\.11|Wireless|Wi-?Fi') }
    if ($wifi) { $m = @(netsh wlan show interfaces) | Select-String '^\s*\S[^:]*:\s*(\d{1,3})\s*%\s*$' | Select-Object -First 1; if ($m) { $sig = $m.Matches[0].Groups[1].Value } }
    A ("podklyuchenie: " + $(if ($ad) { $(if ($wifi) { 'Wi-Fi' + $(if ($sig) { " (signal $sig%)" } else { '' }) } else { 'kabel' }) + ", " + $ad.LinkSpeed + " | shlyuz " + $gw } else { 'ne opredeleno' }))
    $gt = Get-Cfg 'pingtarget' $DEFAULT_PINGTARGET
    $targets = @(@($gw, '1.1.1.1', $gt) | Where-Object { $_ } | Select-Object -Unique)
    $st1 = $null; if ($ad) { $st1 = Get-NetAdapterStatistics -Name $ad.Name -EA SilentlyContinue }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $P = Ping-Many $targets 40
    $down = $null; $up = $null
    if ($st1) {
        $st2 = Get-NetAdapterStatistics -Name $ad.Name -EA SilentlyContinue; $sec = [math]::Max(1, $sw.Elapsed.TotalSeconds)
        $down = [math]::Round(($st2.ReceivedBytes - $st1.ReceivedBytes) * 8 / $sec / 1e6, 1); $up = [math]::Round(($st2.SentBytes - $st1.SentBytes) * 8 / $sec / 1e6, 1)
        A ("nagruzka seti vo vremya proverki: priem $down Mbit/s, otdacha $up Mbit/s")
    }
    foreach ($t in $targets) {
        $x = $P[$t]; $lbl = if ($t -eq $gw) { 'router' } elseif ($t -eq $gt) { 'server igry' } else { 'internet' }
        if ($x.Got -eq 0) { A ("ping {0,-12} {1,-16} ne otvechaet" -f $lbl, $t) }
        else { A ("ping {0,-12} {1,-16} poteri {2}%  sred {3} ms  maks {4} ms  dzhitter {5} ms" -f $lbl, $t, $x.Loss, $x.Avg, $x.Max, $x.Jit) }
    }

    # --- verdikt: blokirovki ---
    $v = New-Object System.Collections.ArrayList
    if ($vpn) { [void]$v.Add("Включён VPN ($($vpn.Name -join ', ')). GameFix работает только без VPN (или игру нужно исключить из VPN). Выключи VPN и проверь снова.") }
    elseif ($otherNames.Count) { [void]$v.Add("Запущен другой обходчик или ускоритель (" + ($otherNames -join ', ') + "). Вместе с GameFix они мешают друг другу и могут портить пинг. Закрой его полностью (выход через значок в трее) или выключи GameFix — одновременно что-то одно.") }
    elseif (-not $svc) { [void]$v.Add("GameFix не установлен. Нажми большую кнопку.") }
    elseif ($svc.Status -ne 'Running' -or -not $wpOurs.Count) { [void]$v.Add("Защита выключена. Нажми большую кнопку, чтобы включить.") }
    elseif ($wp.Count -gt 1) { [void]$v.Add("Запущено несколько winws ($($wp.Count)) — они мешают друг другу. Нажми большую кнопку два раза (выключить и включить) или перезагрузи компьютер.") }
    elseif ($cmdOk -eq $false) { [void]$v.Add("Служба запущена со старыми настройками (папку перемещали или меняли config.txt). Нажми «Подобрать».") }
    elseif ($hostsEnc -eq 'UTF-16') { [void]$v.Add("Файл lists\hosts.txt сохранён в UTF-16 — winws его не понимает. Нажми «Подобрать», GameFix пересохранит его сам.") }
    elseif ($good.Count -eq 0) { [void]$v.Add("Ничего не открывается даже с обходом. Либо нет интернета, либо провайдер блокирует иначе. Нажми «Подобрать» — переберём стратегии; если не поможет, отправь файл GameFix-report.txt.") }
    else {
        if ($badDpi.Count) {
            if ($AfterInstall -and $script:TestPassed) { [void]$v.Add("Подбор нашёл рабочую стратегию, но служба с ней не открывает: " + ($badDpi -join ', ') + ". Перезагрузи компьютер и нажми «Диагностика». Если снова так — отправь файл GameFix-report.txt.") }
            else { [void]$v.Add("Не открываются: " + ($badDpi -join ', ') + ". Нажми «Подобрать» (1–3 мин). Если не поможет — отправь файл GameFix-report.txt.") }
        }
        if ($badIp.Count) { [void]$v.Add("Заблокированы по адресу: " + ($badIp -join ', ') + " — обход тут бессилен, для них нужен VPN (можно только для игры).") }
        if ($badDns.Count) { [void]$v.Add("Не находится адрес: " + ($badDns -join ', ') + " — проблема с DNS. Пропиши DNS 1.1.1.1 и 8.8.8.8 в настройках сети или роутера.") }
        if (-not $bad.Count) { [void]$v.Add("Обход работает: Discord и серверы игры открываются. Если игра или Discord всё равно не работают — перезапусти их (Discord — выход через значок в трее).") }
    }

    # --- verdikt: ping i poteri ---
    $gwP = if ($gw) { $P[$gw] } else { $null }
    $gtP = $P[$gt]; $inP = $P['1.1.1.1']
    $ext = if ($gtP -and $gtP.Got -gt 0) { $gtP } else { $inP }
    $homeBad = [bool]($gwP -and $gwP.Got -gt 0 -and ($gwP.Loss -ge 5 -or $gwP.Jit -ge 8 -or $gwP.Max -ge 80))
    $extBad = [bool]($ext -and $ext.Got -gt 0 -and ($ext.Loss -ge 5 -or $ext.Jit -ge 15))
    # Nagruzka - problema, tolko esli ping pri etom plohoy ili kanal zabit silno: na bystrom internete neskolko Mbit/s ne meshayut
    $loadSome = [bool]($null -ne $down -and ($down -ge 10 -or $up -ge 2))
    $loadBig = [bool]($null -ne $down -and ($down -ge 50 -or $up -ge 20))
    $loadBad = [bool](($loadSome -and ($homeBad -or $extBad)) -or $loadBig)
    if ($homeBad) { [void]$v.Add("Сеть: потери или скачки уже до роутера ($($gwP.Loss)% потерь, до $($gwP.Max) мс)" + $(if ($wifi) { " — это Wi-Fi. Подключи кабель или сядь ближе к роутеру." } else { " — проверь кабель и перезагрузи роутер." })) }
    elseif ($extBad) { [void]$v.Add("Сеть: до роутера чисто, а дальше $($ext.Loss)% потерь и скачки до $($ext.Max) мс. Это линия провайдера или кто-то в сети качает. Если так и вечером — иди в поддержку провайдера с этим отчётом.") }
    if ($loadBad) { [void]$v.Add("Во время проверки компьютер качал $down Мбит/с и отдавал $up Мбит/с. Если это торренты или загрузки — закрой их, они поднимают пинг. Кто качает, видно в «Мониторе ресурсов» → вкладка «Сеть».") }
    if ($sus.Count) { [void]$v.Add("Запущено то, что может влиять на пинг: " + ($sus -join ', ') + ".") }
    if ((Get-Cfg 'udp' 'off') -eq 'on') { [void]$v.Add("Игровой UDP-фильтр включён — весь игровой трафик идёт через winws. Если лагает, выключи его: в config.txt udp=off, потом install.bat.") }
    if ($gtP -and $gtP.Got -eq 0 -and $inP -and $inP.Got -gt 0) { [void]$v.Add("Сервер игры $gt не отвечает на ping — возможно, адрес сменился (свой можно вписать в config.txt: pingtarget=IP).") }
    if (-not $homeBad -and -not $extBad -and -not $loadBad -and $ext -and $ext.Got -gt 0) { [void]$v.Add("Сеть в порядке: до " + $(if ($ext -eq $gtP) { "сервера игры" } else { "интернета" }) + " $($ext.Avg) мс, потерь нет. Если в игре всё равно лаги — это сам сервер игры или нагрузка на компьютер, GameFix тут не поможет.") }

    $verdict = ($v -join "`r`n`r`n")
    A ("VERDICT: " + $verdict)
    [IO.File]::WriteAllText("$ROOT\verdict.txt", $verdict, (New-Object System.Text.UTF8Encoding($true)))
    $rep = @("=== GameFix report ===") + $R + @("", "=== poslednie 40 strok loga ===") + @(Get-Content $LOG -Tail 40 -EA SilentlyContinue)
    [IO.File]::WriteAllText("$ROOT\GameFix-report.txt", ($rep -join "`r`n"), (New-Object System.Text.UTF8Encoding($true)))
    W "  otchet: $ROOT\GameFix-report.txt"
}

function Do-Uninstall {
    W "=== UDALENIE GameFix ==="
    Remove-Item ([Environment]::GetFolderPath('Desktop') + '\GameFix.lnk') -EA SilentlyContinue
    Stop-Service $SVC -Force -EA SilentlyContinue
    Get-Process winws -EA SilentlyContinue | Where-Object { $_.Path -like "$ROOT*" } | Stop-Process -Force -EA SilentlyContinue
    $r = & sc.exe delete $SVC 2>&1; W ("  " + ($r -join ' '))
    Get-NetFirewallRule -DisplayName 'GameFix-deadip*' -EA SilentlyContinue | Remove-NetFirewallRule -EA SilentlyContinue
    W "  pravila brandmauera GameFix-deadip snyaty"
    Remove-Item $CFG -EA SilentlyContinue
    W "  Sluzhba udalena. Papku mozhno prosto sterat."
}

function Do-Status {
    $s = Get-Service $SVC -EA SilentlyContinue
    W ("  sluzhba GameFix: " + $(if ($s) { $s.Status } else { 'ne ustanovlena' }))
    $p = @(Get-Process winws -EA SilentlyContinue)
    W ("  process winws: " + $(if ($p.Count) { 'rabotaet (pid ' + ($p.Id -join ',') + ')' } else { 'net' }) + $(if ($p.Count -gt 1) { '  !! NESKOLKO - meshayut drug drugu' } else { '' }))
    if (Test-Path $CFG) { W ("  config: " + ((Get-Content $CFG | Where-Object { $_.Trim() }) -join ' ')) }
    $fw = Get-NetFirewallRule -DisplayName 'GameFix-deadip' -EA SilentlyContinue
    if ($fw) { W ("  zakrytye IP: " + (($fw | Get-NetFirewallAddressFilter).RemoteAddress -join ', ')) }
}

function Do-Test {
    W "=== PROVERKA ==="
    Do-Status
    $svcHosts = Read-Hosts "${LISTS}hosts.txt"
    foreach ($h in (Read-Hosts "${LISTS}test-hosts.txt")) { W ("  {0,-30} HTTP {1}{2}" -f $h, (Probe $h), $(if (Covered $h $svcHosts) { '' } else { '  (kontrolnyy, sluzhba ego ne obhodit)' })) }
    W "  (000 = ne otkryvaetsya; lyuboy drugoy kod = obhod rabotaet)"
}

switch ($Action) {
    'install'   { Do-Install }
    'uninstall' { Do-Uninstall }
    'status'    { Do-Status }
    'test'      { Do-Test }
    'retest'    { if (Test-Path $CFG) { Set-Content -Path $CFG -Value @(Get-Content $CFG | Where-Object { $_.Trim() -and $_ -notmatch '^strategy=' }) }; Do-Install }
    'deadips'   { Do-DeadIps }
    'diag'      { Do-Diag }
    'shortcut'  { Do-Shortcut }
    'run'       { Ensure-UdpExclude; Stop-Others; $st = Get-Cfg 'strategy' 'ALT11'; Start-Process -FilePath "${BIN}winws.exe" -ArgumentList (Get-Args $st "${LISTS}hosts.txt") -WorkingDirectory $BIN }
}
Finish
