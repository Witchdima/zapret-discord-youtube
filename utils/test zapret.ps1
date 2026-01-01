$hasErrors = $false

$rootDir = Split-Path $PSScriptRoot
$listsDir = Join-Path $rootDir "lists"
$utilsDir = Join-Path $rootDir "utils"
$resultsDir = Join-Path $utilsDir "test results"
$batDir = Join-Path $rootDir "bat"
if (-not (Test-Path $resultsDir)) { New-Item -ItemType Directory -Path $resultsDir | Out-Null }

# Определение функций заранее
function Get-IpsetStatus {
    $listFile = Join-Path $listsDir "ipset-general.txt"
    if (-not (Test-Path $listFile)) { return "none" }
    $lineCount = (Get-Content $listFile | Measure-Object -Line).Lines
    if ($lineCount -eq 0) { return "any" }
    $hasDummy = Get-Content $listFile | Select-String -Pattern "203\.0\.113\.113/32" -Quiet
    if ($hasDummy) { return "none" } else { return "loaded" }
}

function Set-IpsetMode {
    param([string]$mode)
    $listFile = Join-Path $listsDir "ipset-general.txt"
    $backupFile = Join-Path $listsDir "ipset-general.test-backup.txt"
    if ($mode -eq "any") {
        # Всегда создаем резервную копию текущего файла (даже если его нет)
        if (Test-Path $listFile) {
            Copy-Item $listFile $backupFile -Force
        } else {
            # Если файла нет, создаем пустую резервную копию
            "" | Out-File $backupFile -Encoding UTF8
        }
        # Создаем пустой файл
        "" | Out-File $listFile -Encoding UTF8
    } elseif ($mode -eq "restore") {
        if (Test-Path $backupFile) {
            Move-Item $backupFile $listFile -Force
        }
    }
}

trap {
    Write-Host "[ОШИБКА] Скрипт прерван. Восстанавливаю режим фильтра айпи..." -ForegroundColor Red
    if ($originalIpsetStatus -and $originalIpsetStatus -ne "any") {
        Set-IpsetMode -mode "restore"
    }
    Remove-Item -Path $ipsetFlagFile -ErrorAction SilentlyContinue
    break
}

function New-OrderedDict { New-Object System.Collections.Specialized.OrderedDictionary }
function Add-OrSet {
    param($dict, $key, $val)
    if ($dict.Contains($key)) { $dict[$key] = $val } else { $dict.Add($key, $val) }
}

# Преобразование сырого значения цели в структурированный объект (поддержка PING:ip для целей только с пингом)
function Convert-Target {
    param(
        [string]$Name,
        [string]$Value
    )

    if ($Value -like "PING:*") {
        $ping = $Value -replace '^PING:\s*', ''
        $url = $null
        $pingTarget = $ping
    } else {
        $url = $Value
        $pingTarget = $url -replace "^https?://", "" -replace "/.*$", ""
    }

    return (New-Object PSObject -Property @{
        Name       = $Name
        Url        = $url
        PingTarget = $pingTarget
    })
}

function Get-DpiSuite {
    # Набор заимствован из monitor.ps1 (DPI TCP 16-20)
    return @(
        @{ Id = "US.CF-01"; Provider = "Cloudflare"; Url = "https://cdn.cookielaw.org/scripttemplates/202501.2.0/otBannerSdk.js"; Times = 1 }
        @{ Id = "US.CF-02"; Provider = "Cloudflare"; Url = "https://genshin.jmp.blue/characters/all#"; Times = 1 }
        @{ Id = "US.CF-03"; Provider = "Cloudflare"; Url = "https://api.frankfurter.dev/v1/2000-01-01..2002-12-31"; Times = 1 }
        @{ Id = "US.DO-01"; Provider = "DigitalOcean"; Url = "https://genderize.io/"; Times = 2 }
        @{ Id = "DE.HE-01"; Provider = "Hetzner"; Url = "https://j.dejure.org/jcg/doctrine/doctrine_banner.webp"; Times = 1 }
        @{ Id = "FI.HE-01"; Provider = "Hetzner"; Url = "https://tcp1620-01.dubybot.live/1MB.bin"; Times = 1 }
        @{ Id = "FI.HE-02"; Provider = "Hetzner"; Url = "https://tcp1620-02.dubybot.live/1MB.bin"; Times = 1 }
        @{ Id = "FI.HE-03"; Provider = "Hetzner"; Url = "https://tcp1620-05.dubybot.live/1MB.bin"; Times = 1 }
        @{ Id = "FI.HE-04"; Provider = "Hetzner"; Url = "https://tcp1620-06.dubybot.live/1MB.bin"; Times = 1 }
        @{ Id = "FR.OVH-01"; Provider = "OVH"; Url = "https://eu.api.ovh.com/console/rapidoc-min.js"; Times = 1 }
        @{ Id = "FR.OVH-02"; Provider = "OVH"; Url = "https://ovh.sfx.ovh/10M.bin"; Times = 1 }
        @{ Id = "SE.OR-01"; Provider = "Oracle"; Url = "https://oracle.sfx.ovh/10M.bin"; Times = 1 }
        @{ Id = "DE.AWS-01"; Provider = "AWS"; Url = "https://tms.delta.com/delta/dl_anderson/Bootstrap.js"; Times = 1 }
        @{ Id = "US.AWS-01"; Provider = "AWS"; Url = "https://corp.kaltura.com/wp-content/cache/min/1/wp-content/themes/airfleet/dist/styles/theme.css"; Times = 1 }
        @{ Id = "US.GC-01"; Provider = "Google Cloud"; Url = "https://api.usercentrics.eu/gvl/v3/en.json"; Times = 1 }
        @{ Id = "US.FST-01"; Provider = "Fastly"; Url = "https://openoffice.apache.org/images/blog/rejected.png"; Times = 1 }
        @{ Id = "US.FST-02"; Provider = "Fastly"; Url = "https://www.juniper.net/etc.clientlibs/juniper/clientlibs/clientlib-site/resources/fonts/lato/Lato-Regular.woff2"; Times = 1 }
        @{ Id = "PL.AKM-01"; Provider = "Akamai"; Url = "https://www.lg.com/lg5-common-gp/library/jquery.min.js"; Times = 1 }
        @{ Id = "PL.AKM-02"; Provider = "Akamai"; Url = "https://media-assets.stryker.com/is/image/stryker/gateway_1?$max_width_1410$"; Times = 1 }
        @{ Id = "US.CDN77-01"; Provider = "CDN77"; Url = "https://cdn.eso.org/images/banner1920/eso2520a.jpg"; Times = 1 }
        @{ Id = "DE.CNTB-01"; Provider = "Contabo"; Url = "https://cloudlets.io/wp-content/themes/Avada/includes/lib/assets/fonts/fontawesome/webfonts/fa-solid-900.woff2"; Times = 1 }
        @{ Id = "FR.SW-01"; Provider = "Scaleway"; Url = "https://renklisigorta.com.tr/teklif-al"; Times = 1 }
        @{ Id = "US.CNST-01"; Provider = "Constant"; Url = "https://cdn.xuansiwei.com/common/lib/font-awesome/4.7.0/fontawesome-webfont.woff2?v=4.7.0"; Times = 1 }
        # Локальный тестовый payload (требуется: запустить make-test-payload.ps1 и сервер python -m http.server 8000)
        # @{ Id = "LOCAL.TEST-16K"; Provider = "LocalTest"; Url = "http://127.0.0.1:8000/test-payload-16384b.bin"; Times = 1 }
    )
}

function Build-DpiTargets {
    param(
        [string]$CustomUrl
    )

    $suite = Get-DpiSuite
    $targets = @()

    if ($CustomUrl) {
        $targets += @{ Id = "CUSTOM"; Provider = "Custom"; Url = $CustomUrl }
    } else {
        foreach ($entry in $suite) {
            $repeat = $entry.Times
            if (-not $repeat -or $repeat -lt 1) { $repeat = 1 }
            for ($i = 0; $i -lt $repeat; $i++) {
                $suffix = ""
                if ($repeat -gt 1) { $suffix = "@$i" }
                $targets += @{ Id = "$($entry.Id)$suffix"; Provider = $entry.Provider; Url = $entry.Url }
            }
        }
    }

    return $targets
}

function Invoke-DpiSuite {
    param(
        [array]$Targets,
        [int]$TimeoutSeconds,
        [int]$RangeBytes,
        [int]$WarnMinKB,
        [int]$WarnMaxKB,
        [int]$MaxParallel
    )

    $tests = @(
        @{ Label = "HTTP";   Args = @("--http1.1") },
        @{ Label = "TLS1.2"; Args = @("--tlsv1.2", "--tls-max", "1.2") },
        @{ Label = "TLS1.3"; Args = @("--tlsv1.3", "--tls-max", "1.3") }
    )

    $rangeSpec = "0-$($RangeBytes - 1)"
    $warnDetected = $false

    Write-Host "[СВЕДЕНИЯ] Цели: $($Targets.Count) (custom URL переопределяет набор). Диапазон: $rangeSpec байт; Таймаут: $TimeoutSeconds с; Предупреждение: $WarnMinKB-$WarnMaxKB КБ" -ForegroundColor Cyan
    Write-Host "[СВЕДЕНИЯ] Запуск проверок DPI TCP 16-20 (параллельно: $MaxParallel)..." -ForegroundColor DarkGray

    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxParallel)
    $runspacePool.Open()

    $scriptBlock = {
        param($target, $tests, $rangeSpec, $TimeoutSeconds, $WarnMinKB, $WarnMaxKB)

        $warned = $false
        $lines = @()

        foreach ($test in $tests) {
            $curlArgs = @(
                "-L",
                "--range", $rangeSpec,
                "-m", $TimeoutSeconds,
                "-w", "%{http_code} %{size_download}",
                "-o", "NUL",
                "-s"
            ) + $test.Args + @($target.Url)

            $output = & curl.exe @curlArgs 2>&1
            $exit = $LASTEXITCODE
            $text = ($output | Out-String).Trim()

            $code = "NA"
            $sizeBytes = 0

            if ($text -match '^(?<code>\d{3})\s+(?<size>\d+)$') {
                $code = $matches['code']
                $sizeBytes = [int64]$matches['size']
            } elseif (($exit -eq 35) -or ($text -match "not supported|does not support|protocol\s+'.+'\s+not\s+supported|protocol\s+.+\s+not\s+supported|unsupported protocol|TLS.not supported|Unrecognized option|Unknown option|unsupported option|unsupported feature|schannel|SSL")) {
                $code = "UNSUP"
            } elseif ($text) {
                $code = "ERR"
            }

            $sizeKB = [math]::Round($sizeBytes / 1024, 1)
            $status = "OK"
            $color = "Green"

            if ($code -eq "UNSUP") {
                $status = "UNSUPPORTED"
                $color = "Yellow"
            } elseif ($exit -ne 0 -or $code -eq "ERR" -or $code -eq "NA") {
                $status = "FAIL"
                $color = "Red"
            }

            if (($sizeKB -ge $WarnMinKB) -and ($sizeKB -le $WarnMaxKB) -and ($exit -ne 0)) {
                $status = "LIKELY_BLOCKED"
                $color = "Yellow"
                $warned = $true
            }

            $lines += [PSCustomObject]@{
                TargetId   = $target.Id
                Provider   = $target.Provider
                TestLabel  = $test.Label
                Code       = $code
                SizeBytes  = $sizeBytes
                SizeKB     = $sizeKB
                Status     = $status
                Color      = $color
                Warned     = $warned
            }
        }

        return [PSCustomObject]@{
            TargetId = $target.Id
            Provider = $target.Provider
            Lines    = $lines
            Warned   = $warned
        }
    }

    $runspaces = @()
    foreach ($target in $Targets) {
        $powershell = [powershell]::Create().AddScript($scriptBlock)
        [void]$powershell.AddArgument($target)
        [void]$powershell.AddArgument($tests)
        [void]$powershell.AddArgument($rangeSpec)
        [void]$powershell.AddArgument($TimeoutSeconds)
        [void]$powershell.AddArgument($WarnMinKB)
        [void]$powershell.AddArgument($WarnMaxKB)
        $powershell.RunspacePool = $runspacePool

        $runspaces += [PSCustomObject]@{
            Powershell = $powershell
            Handle     = $powershell.BeginInvoke()
        }
    }

    $results = @()
    foreach ($rs in $runspaces) {
        # Ожидание завершения runspace с небольшим запасом времени сверх таймаута curl
        try {
            $waitMs = ([int]$TimeoutSeconds + 5) * 1000
            $handle = $rs.Handle
            if ($handle -and $handle.AsyncWaitHandle) {
                $completed = $handle.AsyncWaitHandle.WaitOne($waitMs)
                if (-not $completed) {
                    Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Runspace for target timed out after $waitMs ms; stopping runspace..." -ForegroundColor Yellow
                    try { $rs.Powershell.Stop() } catch {}
                }
            }
        } catch {
            # игнорировать ошибки ожидания и попытаться выполнить EndInvoke
        }

        try {
            $results += $rs.Powershell.EndInvoke($rs.Handle)
        } catch {
            Write-Host "[ПРЕДУПРЕЖДЕНИЕ] EndInvoke failed for a runspace; treating as failure." -ForegroundColor Yellow
            $failedLine = [PSCustomObject]@{
                TestLabel  = 'RUNSPACE'
                Code       = 'ERR'
                SizeBytes  = 0
                SizeKB     = 0
                Status     = 'FAIL'
                Color      = 'Red'
                Warned     = $false
            }
            $results += [PSCustomObject]@{ TargetId = 'UNKNOWN'; Provider = 'UNKNOWN'; Lines = @($failedLine); Warned = $false }
        }
        $rs.Powershell.Dispose()
    }
    $runspacePool.Close()
    $runspacePool.Dispose()

    foreach ($res in $results) {
        Write-Host "`n=== $($res.TargetId) [$($res.Provider)] ===" -ForegroundColor DarkCyan

        foreach ($line in $res.Lines) {
            $msg = "[{0}][{1}] code={2} size={3} bytes ({4} KB) status={5}" -f $line.TargetId, $line.TestLabel, $line.Code, $line.SizeBytes, $line.SizeKB, $line.Status
            Write-Host $msg -ForegroundColor $line.Color
            if ($line.Status -eq "LIKELY_BLOCKED") {
                Write-Host "  Шаблон соответствует заморозке 16-20КБ; цензура, вероятно, блокирует эту стратегию." -ForegroundColor Yellow
            }
        }

        if (-not $res.Warned) {
            Write-Host "  Шаблон заморозки 16-20КБ не обнаружен для этой цели." -ForegroundColor Green
        } else {
            $warnDetected = $true
        }
    }

    if ($warnDetected) {
        Write-Host ""
        Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Обнаружена возможная блокировка DPI TCP 16-20 на одной или нескольких целях. Рекомендуется изменить стратегию/SNI/IP." -ForegroundColor Red
    } else {
        Write-Host ""
        Write-Host "[OK]  Шаблон заморозки 16-20КБ не обнаружен на всех целях." -ForegroundColor Green
    }

    return $results
}

function Test-ZapretServiceConflict {
    return [bool](Get-Service -Name "zapret" -ErrorAction SilentlyContinue)
}

# Проверка прав администратора
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ОШИБКА] Запустите скрипт от имени администратора для выполнения тестов" -ForegroundColor Red
    $hasErrors = $true
} else {
    Write-Host "[OK] Обнаружены права Администратора" -ForegroundColor Green
}

# Проверка curl
if (-not (Get-Command "curl.exe" -ErrorAction SilentlyContinue)) {
    Write-Host "[ОШИБКА] curl.exe не найден" -ForegroundColor Red
    Write-Host "Установите curl или добавьте его в ПУТЬ" -ForegroundColor Yellow
    $hasErrors = $true
} else {
    Write-Host "[OK] curl.exe найден" -ForegroundColor Green
}

# Проверка флага переключения ipset из предыдущего прерванного запуска
$ipsetFlagFile = Join-Path $rootDir "ipset_switched.flag"
if (Test-Path $ipsetFlagFile) {
    Write-Host "[СВЕДЕНИЯ] Обнаружен оставшийся флаг переключения режима фильтра айпи. Восстанавливаю режим фильтра айпи..." -ForegroundColor Yellow
    Set-IpsetMode -mode "restore"
    Remove-Item -Path $ipsetFlagFile -ErrorAction SilentlyContinue
}

# Получение оригинального статуса фильтра режима айпи заранее
$originalIpsetStatus = Get-IpsetStatus

# Предупреждение о переключении режима фильтра айпи и поведении кнопки X
if ($originalIpsetStatus -ne "any") {
    Write-Host "[СВЕДЕНИЯ] Текущий статус режима фильтра айпи: $originalIpsetStatus" -ForegroundColor Cyan
    Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Режим фильтра айпи будет переключен в режим 'любой' для точных тестов DPI." -ForegroundColor Yellow
    Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Если вы закроете окно кнопкой X, режим фильтра айпи НЕ восстановится сразу." -ForegroundColor Yellow
    Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Он будет восстановлен автоматически при следующем запуске скрипта." -ForegroundColor Yellow
}

# Проверка установлена ли служба запрет
if (Test-ZapretServiceConflict) {
    Write-Host "[ОШИБКА] Установлена служба 'zapret' в Windows" -ForegroundColor Red
    Write-Host "         Удалите службу перед запуском тестов" -ForegroundColor Yellow
    Write-Host "         Откройте service.bat и выберите 'Удалить службу'" -ForegroundColor Yellow
    $hasErrors = $true
}

if ($hasErrors) {
    Write-Host ""
    Write-Host "Исправьте ошибки выше и перезапустите." -ForegroundColor Yellow
    Write-Host "Нажмите любую клавишу для выхода..." -ForegroundColor Yellow
    [void][System.Console]::ReadKey($true)
    exit 1
}

# Настройки проверки DPI по умолчанию (переопределяются через переменные среды MONITOR_* как в monitor.ps1)
$dpiTimeoutSeconds = 5
$dpiRangeBytes = 262144
$dpiWarnMinKB = 14
$dpiWarnMaxKB = 22
$dpiMaxParallel = 8
$dpiCustomUrl = $env:MONITOR_URL
if ($env:MONITOR_TIMEOUT) { [int]$dpiTimeoutSeconds = $env:MONITOR_TIMEOUT }
if ($env:MONITOR_RANGE) { [int]$dpiRangeBytes = $env:MONITOR_RANGE }
if ($env:MONITOR_WARN_MINKB) { [int]$dpiWarnMinKB = $env:MONITOR_WARN_MINKB }
if ($env:MONITOR_WARN_MAXKB) { [int]$dpiWarnMaxKB = $env:MONITOR_WARN_MAXKB }
if ($env:MONITOR_MAX_PARALLEL) { [int]$dpiMaxParallel = $env:MONITOR_MAX_PARALLEL }
$dpiTargets = Build-DpiTargets -CustomUrl $dpiCustomUrl

# Конфигурация
$targetDir = $rootDir
if (-not $targetDir) { $targetDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$batFiles = Get-ChildItem -Path $batDir -Filter "*.bat" | Where-Object { $_.Name -notlike "service*" } | Sort-Object Name

$globalResults = @()

# Выбор типа теста (стандартные или проверка DPI)
function Read-TestType {
    while ($true) {
        Write-Host ""
        Write-Host "Выберите тип теста:" -ForegroundColor Cyan
        Write-Host "  [1] Стандартные тесты (HTTP/Пинг))" -ForegroundColor Gray
        Write-Host "  [2] Проверка DPI (TCP 16-20 заморозки)" -ForegroundColor Gray
        $choice = Read-Host "Введите 1 или 2"
        switch ($choice) {
            '1' { return 'standard' }
            '2' { return 'dpi' }
            default { Write-Host "Некорректный ввод. Попробуйте снова." -ForegroundColor Yellow }
        }
    }
}

# Выбор режима тестирования: все конфигурации или выбранные
function Read-ModeSelection {
    while ($true) {
        Write-Host ""
        Write-Host "Выберите режим тестирования:" -ForegroundColor Cyan
        Write-Host "  [1] Все конфигурации" -ForegroundColor Gray
        Write-Host "  [2] Выбранные конфигурации" -ForegroundColor Gray
        $choice = Read-Host "Введите 1 или 2"
        switch ($choice) {
            '1' { return 'all' }
            '2' { return 'select' }
            default { Write-Host "Некорректный ввод. Попробуйте снова." -ForegroundColor Yellow }
        }
    }
}

function Read-ConfigSelection {
    param([array]$allFiles)

    while ($true) {
        Write-Host "" 
        Write-Host "Доступные конфигурации:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $allFiles.Count; $i++) {
            $idx = $i + 1
            Write-Host "  [$idx] $($allFiles[$i].Name)" -ForegroundColor Gray
        }

        $selectionInput = Read-Host "Введите числа через запятую (например, 1,3,5) или '0' для запуска всех"
        $trimmed = $selectionInput.Trim()
        if ($trimmed -eq '0') {
            return $allFiles
        }

        $numbers = $selectionInput -split "[\,\s]+" | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
        $valid = $numbers | Where-Object { $_ -ge 1 -and $_ -le $allFiles.Count } | Select-Object -Unique

        if (-not $valid -or $valid.Count -eq 0) {
            Write-Host ""
            Write-Host "Конфигурации не выбраны. Попробуйте снова." -ForegroundColor Yellow
            continue
        }

        return $valid | ForEach-Object { $allFiles[$_ - 1] }
    }
}

while ($true) {
    $globalResults = @()
$testType = Read-TestType
$mode = Read-ModeSelection
if ($mode -eq 'select') {
    $selected = Read-ConfigSelection -allFiles $batFiles
    $batFiles = @($selected)
}

# Загрузка целей для стандартного режима (однократно)
$targetList = @()
$maxNameLen = 10
if ($testType -eq 'standard') {
    $targetsFile = Join-Path $utilsDir "targets.txt"
    $rawTargets = New-OrderedDict
    if (Test-Path $targetsFile) {
        Get-Content $targetsFile | ForEach-Object {
            if ($_ -match '^\s*(\w+)\s*=\s*"(.+)"\s*$') {
                Add-OrSet -dict $rawTargets -key $matches[1] -val $matches[2]
            }
        }
    }

    if ($rawTargets.Count -eq 0) {
        Write-Host "[СВЕДЕНИЯ] Файл targets.txt отсутствует или пуст. Используются цели по умолчанию." -ForegroundColor Gray
        Add-OrSet $rawTargets "Discord Main"           "https://discord.com"
        Add-OrSet $rawTargets "Discord Gateway"        "https://gateway.discord.gg"
        Add-OrSet $rawTargets "Discord CDN"            "https://cdn.discordapp.com"
        Add-OrSet $rawTargets "Discord Updates"        "https://updates.discord.com"
        Add-OrSet $rawTargets "YouTube Web"            "https://www.youtube.com"
        Add-OrSet $rawTargets "YouTube Short"          "https://youtu.be"
        Add-OrSet $rawTargets "YouTube Image"          "https://i.ytimg.com"
        Add-OrSet $rawTargets "YouTube Video Redirect" "https://redirector.googlevideo.com"
        Add-OrSet $rawTargets "Google Main"            "https://www.google.com"
        Add-OrSet $rawTargets "Google Gstatic"         "https://www.gstatic.com"
        Add-OrSet $rawTargets "Cloudflare Web"         "https://www.cloudflare.com"
        Add-OrSet $rawTargets "Cloudflare CDN"         "https://cdnjs.cloudflare.com"
        Add-OrSet $rawTargets "Cloudflare DNS 1.1.1.1" "PING:1.1.1.1"
        Add-OrSet $rawTargets "Cloudflare DNS 1.0.0.1" "PING:1.0.0.1"
        Add-OrSet $rawTargets "Google DNS 8.8.8.8"     "PING:8.8.8.8"
        Add-OrSet $rawTargets "Google DNS 8.8.4.4"     "PING:8.8.4.4"
        Add-OrSet $rawTargets "Quad9 DNS 9.9.9.9"      "PING:9.9.9.9"
    } else {
        Write-Host ""
        Write-Host "[СВЕДЕНИЯ] Загружены цели из targets.txt" -ForegroundColor Gray
        Write-Host "[СВЕДЕНИЯ] Загружено целей: $($rawTargets.Count)" -ForegroundColor Gray
    }

    foreach ($key in $rawTargets.Keys) {
        $targetList += Convert-Target -Name $key -Value $rawTargets[$key]
    }

    $maxNameLen = ($targetList | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum
    if (-not $maxNameLen -or $maxNameLen -lt 10) { $maxNameLen = 10 }
}

# Проверка наличия конфигураций для запуска
if (-not $batFiles -or $batFiles.Count -eq 0) {
    Write-Host "[ОШИБКА] Файлы *.bat не найдены" -ForegroundColor Red
    Write-Host "Нажмите любую клавишу для выхода..." -ForegroundColor Yellow
    [void][System.Console]::ReadKey($true)
    exit 1
}

# Остановка winws
function Stop-Zapret {
    Get-Process -Name "winws" -ErrorAction SilentlyContinue | Stop-Process -Force
}

# Захват/восстановление запущенных экземпляров winws для возврата пользовательского режима фильтра айпи/конфигурации
function Get-WinwsSnapshot {
    try {
        return Get-CimInstance Win32_Process -Filter "Name='winws.exe'" |
            Select-Object ProcessId, CommandLine, ExecutablePath
    } catch {
        return @()
    }
}

function Restore-WinwsSnapshot {
    param($snapshot)

    if (-not $snapshot -or $snapshot.Count -eq 0) { return }

    $current = @()
    try { $current = (Get-WinwsSnapshot).CommandLine } catch { $current = @() }

    Write-Host "[СВЕДЕНИЯ] Восстановление ранее запущенных экземпляров winws..." -ForegroundColor DarkGray
    foreach ($p in $snapshot) {
        if (-not $p.ExecutablePath) { continue }

        # Пропустить, если идентичная командная строка уже активна
        if ($current -and $current -contains $p.CommandLine) { continue }

        $exe = $p.ExecutablePath
        $args = ""
        if ($p.CommandLine) {
            $quotedExe = '"' + $exe + '"'
            if ($p.CommandLine.StartsWith($quotedExe)) {
                $args = $p.CommandLine.Substring($quotedExe.Length).Trim()
            } elseif ($p.CommandLine.StartsWith($exe)) {
                $args = $p.CommandLine.Substring($exe.Length).Trim()
            }
        }

        Start-Process -FilePath $exe -ArgumentList $args -WorkingDirectory (Split-Path $exe -Parent) -WindowStyle Minimized | Out-Null
    }
}

$originalWinws = Get-WinwsSnapshot

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                 ТЕСТЫ КОНФИГУРАЦИЙ ЗАПЕРТА" -ForegroundColor Cyan
Write-Host "                 Режим: $($testType.ToUpper())" -ForegroundColor Cyan
Write-Host "                 Всего конфигураций: $($batFiles.Count.ToString().PadLeft(2))" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

try {
    # Сохранение оригинального статуса фильтра айпи и переключение в 'любой' для точных тестов DPI
    if (($originalIpsetStatus -ne "any") -and ($testType -eq 'dpi')) {
        Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Режим фильтра айпи находится в режиме '$originalIpsetStatus'. Переключаю в 'любой' для точных тестов DPI..." -ForegroundColor Yellow
        Set-IpsetMode -mode "any"
        # Создание флагового файла для указания, что фильтр айпи был переключен
        "" | Out-File -FilePath $ipsetFlagFile -Encoding UTF8
    }
Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Тесты могут занять несколько минут. Пожалуйста, подождите..." -ForegroundColor Yellow

    $configNum = 0
    foreach ($file in $batFiles) {
    $configNum++
    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  [$configNum/$($batFiles.Count)] $($file.Name)" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
    
    # Очистка
    Stop-Zapret
    
    # Запуск конфигурации
    Write-Host "  > Запуск конфигурации..." -ForegroundColor Cyan
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$($file.FullName)`"" -WorkingDirectory $batDir -PassThru -WindowStyle Minimized
    
    # Ожидание инициализации
    Start-Sleep -Seconds 5
    
    if ($testType -eq 'standard') {
        $curlTimeoutSeconds = 5

        # Параллельная проверка целей через пул runspace (быстрее, чем задания)
        $maxParallel = 8
        $runspacePool = [runspacefactory]::CreateRunspacePool(1, $maxParallel)
        $runspacePool.Open()

        $scriptBlock = {
            param($t, $curlTimeoutSeconds)

            $httpPieces = @()

            if ($t.Url) {
                $tests = @(
                    @{ Label = "HTTP";   Args = @("--http1.1") },
                    @{ Label = "TLS1.2"; Args = @("--tlsv1.2", "--tls-max", "1.2") },
                    @{ Label = "TLS1.3"; Args = @("--tlsv1.3", "--tls-max", "1.3") }
                )

                $baseArgs = @("-I", "-s", "-m", $curlTimeoutSeconds, "-o", "NUL", "-w", "%{http_code}")
                foreach ($test in $tests) {
                    try {
                        $curlArgs = $baseArgs + $test.Args
                        $output = & curl.exe @curlArgs $t.Url 2>&1
                        $text = ($output | Out-String).Trim()
                        $unsupported = (($LASTEXITCODE -eq 35) -or ($text -match "does not support|not supported|protocol\s+'?.+'?\s+not\s+supported|unsupported protocol|TLS.*not supported|Unrecognized option|Unknown option|unsupported option|unsupported feature|schannel|SSL"))
                        if ($unsupported) {
                            $httpPieces += "$($test.Label):UNSUP"
                            continue
                        }

                        $ok = ($LASTEXITCODE -eq 0)
                        if ($ok) {
                            $httpPieces += "$($test.Label):OK   "
                        } else {
                            $httpPieces += "$($test.Label):ERROR"
                        }
                    } catch {
                        $httpPieces += "$($test.Label):ERROR"
                    }
                }
            }

            $pingResult = "n/a"
            if ($t.PingTarget) {
                try {
                    $pings = Test-Connection -ComputerName $t.PingTarget -Count 3 -ErrorAction Stop
                    $avg = ($pings | Measure-Object -Property ResponseTime -Average).Average
                    $pingResult = "{0:N0} ms" -f $avg
                } catch {
                    $pingResult = "Timeout"
                }
            }

            return (New-Object PSObject -Property @{
                Name       = $t.Name
                HttpTokens = $httpPieces
                PingResult = $pingResult
                IsUrl      = [bool]$t.Url
            })
        }

        $runspaces = @()
        foreach ($target in $targetList) {
            $ps = [powershell]::Create().AddScript($scriptBlock)
            [void]$ps.AddArgument($target)
            [void]$ps.AddArgument($curlTimeoutSeconds)
            $ps.RunspacePool = $runspacePool

            $runspaces += [PSCustomObject]@{
                Powershell = $ps
                Handle     = $ps.BeginInvoke()
            }
        }

        $script:currentLine = "  > Запуск тестов..."
        Write-Host $script:currentLine -ForegroundColor DarkGray

        $targetResults = @()
        foreach ($rs in $runspaces) {
            try {
                $waitMs = ([int]$curlTimeoutSeconds + 5) * 1000
                $handle = $rs.Handle
                if ($handle -and $handle.AsyncWaitHandle) {
                    $completed = $handle.AsyncWaitHandle.WaitOne($waitMs)
                    if (-not $completed) {
                        Write-Host "[ПРЕДУПРЕЖДЕНИЕ] Runspace для цели превысил время ожидания после $waitMs мс; останавливаю runspace..." -ForegroundColor Yellow
                        try { $rs.Powershell.Stop() } catch {}
                    }
                }
            } catch {
                # ignore
            }

            try {
                $targetResults += $rs.Powershell.EndInvoke($rs.Handle)
            } catch {
                Write-Host "[ПРЕДУПРЕЖДЕНИЕ] EndInvoke завершился ошибкой для runspace; рассматриваю как провал." -ForegroundColor Yellow
                $targetResults += [PSCustomObject]@{ Name = 'UNKNOWN'; HttpTokens = @('HTTP:ERROR'); PingResult = 'Timeout'; IsUrl = $true }
            }
            $rs.Powershell.Dispose()
        }

        $runspacePool.Close()
        $runspacePool.Dispose()

        $targetLookup = @{}
        foreach ($res in $targetResults) { $targetLookup[$res.Name] = $res }

        foreach ($target in $targetList) {
            $res = $targetLookup[$target.Name]
            if (-not $res) { continue }

            Write-Host "  $($target.Name.PadRight($maxNameLen))    " -NoNewline

            if ($res.IsUrl -and $res.HttpTokens) {
                foreach ($tok in $res.HttpTokens) {
                    $tokColor = "Green"
                    if ($tok -match "UNSUP") { $tokColor = "Yellow" }
                    elseif ($tok -match "ERR") { $tokColor = "Red" }
                    Write-Host " $tok" -NoNewline -ForegroundColor $tokColor
                }
                Write-Host " | Пинг: " -NoNewline -ForegroundColor DarkGray
                if ($res.PingResult -eq "Timeout") {
                    $pingColor = "Yellow"
                } else {
                    $pingColor = "Cyan"
                }
                Write-Host "$($res.PingResult)" -NoNewline -ForegroundColor $pingColor
                Write-Host ""
            } else {
                # Цель только с пингом
                Write-Host " Пинг: " -NoNewline -ForegroundColor DarkGray
                if ($res.PingResult -eq "Timeout") {
                    $pingColor = "Red"
                } else {
                    $pingColor = "Cyan"
                }
                Write-Host "$($res.PingResult)" -ForegroundColor $pingColor
            }

        }

        $globalResults += @{ Config = $file.Name; Type = 'standard'; Results = $targetResults }
    } else {
        Write-Host "  > Запуск проверки DPI..." -ForegroundColor DarkGray
        $dpiResults = Invoke-DpiSuite -Targets $dpiTargets -TimeoutSeconds $dpiTimeoutSeconds -RangeBytes $dpiRangeBytes -WarnMinKB $dpiWarnMinKB -WarnMaxKB $dpiWarnMaxKB -MaxParallel $dpiMaxParallel
        $globalResults += @{ Config = $file.Name; Type = 'dpi'; Results = $dpiResults }
    }
    
    # Остановка
    Stop-Zapret
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
}

    Write-Host ""
    Write-Host "Все тесты завершены." -ForegroundColor Green

    # Аналитика
    $analytics = @{}
    foreach ($res in $globalResults) {
        if ($res.Type -eq 'standard') {
            foreach ($targetRes in $res.Results) {
                $config = $res.Config
                if (-not $analytics.ContainsKey($config)) { $analytics[$config] = @{ OK = 0; ERROR = 0; UNSUP = 0; PingOK = 0; PingFail = 0 } }
                if ($targetRes.IsUrl) {
                    foreach ($tok in $targetRes.HttpTokens) {
                        if ($tok -match "OK") { $analytics[$config].OK++ }
                        elseif ($tok -match "ERROR") { $analytics[$config].ERROR++ }
                        elseif ($tok -match "UNSUP") { $analytics[$config].UNSUP++ }
                    }
                }
                if ($targetRes.PingResult -ne "Timeout" -and $targetRes.PingResult -ne "n/a") { $analytics[$config].PingOK++ } else { $analytics[$config].PingFail++ }
            }
        } elseif ($res.Type -eq 'dpi') {
            foreach ($targetRes in $res.Results) {
                $config = $res.Config
                if (-not $analytics.ContainsKey($config)) { $analytics[$config] = @{ OK = 0; FAIL = 0; UNSUPPORTED = 0; LIKELY_BLOCKED = 0 } }
                foreach ($line in $targetRes.Lines) {
                    if ($line.Status -eq "OK") { $analytics[$config].OK++ }
                    elseif ($line.Status -eq "FAIL") { $analytics[$config].FAIL++ }
                    elseif ($line.Status -eq "UNSUPPORTED") { $analytics[$config].UNSUPPORTED++ }
                    elseif ($line.Status -eq "LIKELY_BLOCKED") { $analytics[$config].LIKELY_BLOCKED++ }
                }
            }
        }
    }

    Write-Host ""
    Write-Host "=== АНАЛИТИКА ===" -ForegroundColor Cyan
    foreach ($config in $analytics.Keys) {
        $a = $analytics[$config]
        if ($a.ContainsKey('PingOK')) {
            Write-Host "$config : HTTP OK: $($a.OK), ОШИБОК: $($a.ERROR), НЕПОДДЕРЖИВАЕМО: $($a.UNSUP), Пинг OK: $($a.PingOK), Провалено: $($a.PingFail)" -ForegroundColor Yellow
        } else {
            Write-Host "$config : OK: $($a.OK), Провалено: $($a.FAIL), НЕПОДДЕРЖИВАЕМО: $($a.UNSUPPORTED), ВЕРОЯТНО ЗАБЛОКИРОВАНО: $($a.LIKELY_BLOCKED)" -ForegroundColor Yellow
        }
    }

    # Определение лучшей стратегии
    $bestConfig = $null
    $maxScore = 0
	$maxPing = -1
    foreach ($config in $analytics.Keys) {
        $a = $analytics[$config]
        $score = $a.OK
        $pingScore = 0
        if ($a.ContainsKey('PingOK')) {
            $pingScore = $a.PingOK
        }
        if ($score -gt $maxScore) {
            $maxScore = $score
            $maxPing = $pingScore
            $bestConfig = $config
        } elseif ($score -eq $maxScore) {
            if ($pingScore -gt $maxPing) {
                $maxPing = $pingScore
                $bestConfig = $config
            }
        }
    }
    Write-Host ""
    Write-Host "Лучшая конфигурация: $bestConfig" -ForegroundColor Green
    Write-Host ""

    # Сохранение в файл
    $dateStr = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $resultFile = Join-Path $resultsDir "test_results_$dateStr.txt"
    # Очистка файла
    "" | Out-File $resultFile -Encoding UTF8
    foreach ($res in $globalResults) {
        $config = $res.Config
        $type = $res.Type
        $results = $res.Results
        Add-Content $resultFile "Config: $config (Type: $type)"
        if ($type -eq 'standard') {
            foreach ($targetRes in $results) {
                $name = $targetRes.Name
                $http = $targetRes.HttpTokens -join ' '
                $ping = $targetRes.PingResult
                Add-Content $resultFile "  $name : $http | Ping: $ping"
            }
        } elseif ($type -eq 'dpi') {
            foreach ($targetRes in $results) {
                $id = $targetRes.TargetId
                $provider = $targetRes.Provider
                Add-Content $resultFile "  Target: $id ($provider)"
                foreach ($line in $targetRes.Lines) {
                    $test = $line.TestLabel
                    $code = $line.Code
                    $size = $line.SizeKB
                    $status = $line.Status
                    Add-Content $resultFile "    ${test}: code=${code} size=${size} KB status=${status}"
                }
            }
        }
        Add-Content $resultFile ""
    }

    # Добавление аналитики
    Add-Content $resultFile "=== АНАЛИТИКА ==="
    foreach ($config in $analytics.Keys) {
        $a = $analytics[$config]
        if ($a.ContainsKey('PingOK')) {
            Add-Content $resultFile "$config : HTTP OK: $($a.OK), ОШИБОК: $($a.ERROR), НЕПОДДЕРЖИВАЕМО: $($a.UNSUP), Пинг OK: $($a.PingOK), Провалено: $($a.PingFail)"
        } else {
            Add-Content $resultFile "$config : OK: $($a.OK), Провалено: $($a.FAIL), НЕПОДДЕРЖИВАЕМО: $($a.UNSUPPORTED), ВЕРОЯТНО ЗАБЛОКИРОВАНО: $($a.LIKELY_BLOCKED)"
        }
    }

    Add-Content $resultFile "Лучшая конфигурация: $bestConfig"

    Write-Host "Результаты сохранены в $resultFile" -ForegroundColor Green

} catch {
    Write-Host "[ОШИБКА] Произошла ошибка во время тестов. Восстанавливаю режим фильтра айпи..." -ForegroundColor Red
    if ($originalIpsetStatus -and $originalIpsetStatus -ne "any") {
        Set-IpsetMode -mode "restore"
    }
    Remove-Item -Path $ipsetFlagFile -ErrorAction SilentlyContinue
} finally {
    Stop-Zapret
    Restore-WinwsSnapshot -snapshot $originalWinws
    if ($originalIpsetStatus -ne "any") {
        Write-Host "[СВЕДЕНИЯ] Восстановление оригинального режима фильтра айпи..." -ForegroundColor DarkGray
        Set-IpsetMode -mode "restore"
    }
    Remove-Item -Path $ipsetFlagFile -ErrorAction SilentlyContinue
}

    Write-Host "Нажмите любую клавишу для закрытия..." -ForegroundColor Yellow
    [void][System.Console]::ReadKey($true)
    exit
}
