@echo off
chcp 1251 > nul
set "LOCAL_VERSION=1.9.0b"

:: ==================== ПУТИ ОБРАЩЕНИЯ ====================
set "BIN_PATH=%~dp0bin\"
set "LISTS_PATH=%~dp0lists\"
set "BAT_PATH=%~dp0bat\"
Set "CONFIG_PATH=%~dp0config\"

:: ==================== ВНЕШНИЕ КОМАНДЫ ====================
if "%~1"=="status_zapret" (
    call :test_service zapret soft
    call :tcp_enable
    exit /b
)

if "%~1"=="check_updates" (
    if not "%~2"=="soft" (
        start /b service check_updates soft
    ) else (
        call :service_check_updates soft
    )
    exit /b
)

if "%~1"=="load_game_filter" (
    call :game_switch_status
    exit /b
)

:: ==================== ПРОВЕРКА ПРАВ АДМИНИСТРАТОРА ====================
if "%1"=="admin" (
    echo Запуск от имени администратора
) else (
    echo Запрос прав администратора...
    powershell -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
    exit
)

:: ==================== ГЛАВНОЕ МЕНЮ ====================
setlocal EnableDelayedExpansion
:menu
cls
call :game_switch_status

set "menu_choice=null"
echo =========  Версия !LOCAL_VERSION!  =========
echo 1. Установка службы
echo 2. Установка конфига
echo 3. Удалить службу
echo 4. Проверить статус
echo 5. Запустить диагностику 
echo 6. Проверить обновления
echo 7. Переключить игровой фильтр (%GameFilterStatus%)
echo 8. Фильтры айпи
echo 0. Выйти
set /p menu_choice=Введите параметр (0-9): 

if "%menu_choice%"=="1" goto service_install_bat
if "%menu_choice%"=="2" goto service_install_config
if "%menu_choice%"=="3" goto service_remove
if "%menu_choice%"=="4" goto service_status
if "%menu_choice%"=="5" goto service_diagnostics
if "%menu_choice%"=="6" goto service_check_updates
if "%menu_choice%"=="7" goto game_switch
if "%menu_choice%"=="8" goto menu_ip
if "%menu_choice%"=="8" goto ipset_switch_general
if "%menu_choice%"=="9" goto ipset_update_general
if "%menu_choice%"=="0" exit /b
goto menu

:: ==================== АЙПИ МЕНЮ ====================
:menu_ip
cls
call :ipset_switch_status_general
call :ipset_switch_status_gaming

set "menu_choice=null"
echo =========  Версия !LOCAL_VERSION!  =========
echo 1. Смена фильтра айпи основного (%IPsetStatusGeneral%) 
echo 2. Смена фильтра айпи игровой (%IPsetStatusGaming%) 
echo 3. Обновление списков айпи
echo 0. Выйти
set /p menu_choice=Введите параметр (0-3): 

if "%menu_choice%"=="1" goto ipset_switch_general
if "%menu_choice%"=="2" goto ipset_switch_gaming
if "%menu_choice%"=="3" goto ipset_update_both
if "%menu_choice%"=="0" exit /b
goto menu
:: ==================== УСТАНОВКА СЛУЖБ ====================
:: Для *BAT файлов
:service_install_bat
cls
chcp 1251 > nul
cd /d "%~dp0"

:: Поиск файлов *bat в текущей папке, за исключением файлов, которые начинаются с "service"
echo Выберите один из вариантов:
set "count=0"
for %%f in (*.bat) do (
    set "filename=%%~nxf"
    if /i not "!filename:~0,7!"=="service" (
        set /a count+=1
        echo !count!. %%f
        set "file!count!=%%f"
    )
)

:: Поиск в папке bat
if exist "!BAT_PATH!" (
    for %%f in ("!BAT_PATH!*.bat") do (
        set "filename=%%~nxf"
        if /i not "!filename:~0,7!"=="service" (
            set /a count+=1
            echo !count!. %%~nxf
            set "file!count!=%%f"
        )
    )
)

:: Выбор файла
set "choice="
set /p "choice=Индекс файла (номер): "
if "!choice!"=="" goto :eof

set "selectedFile=!file%choice%!"
if not defined selectedFile (
    echo Неверный индекс, выход...
    pause
    goto menu
)
:: Вызов функции разбора аргументов
call :parse_arguments

:: Установка службы для bat файлов
goto create_service_bat

:: Установка конфигов =============================
:service_install_config
cls
chcp 1251 > nul
cd /d "%~dp0"

:: Поиск файлов *conf *config в текущей папке, за исключением файлов, которые начинаются с "service"
echo Выберите один из вариантов:
set "count=0"
for %%f in (*.conf *.config) do (
    set "filename=%%~nxf"
    if /i not "!filename:~0,7!"=="service" (
        set /a count+=1
        echo !count!. %%f
        set "file!count!=%%f"
    )
)

:: Поиск в папке config
if exist "!CONFIG_PATH!" (
    for %%f in ("!CONFIG_PATH!*.conf" "!CONFIG_PATH!*.config") do (
        set "filename=%%~nxf"
        if /i not "!filename:~0,7!"=="service" (
            set /a count+=1
            echo !count!. %%~nxf
            set "file!count!=%%f"
        )
    )
)

:: Выбор файла
set "choice="
set /p "choice=Индекс файла (номер): "
if "!choice!"=="" goto :eof

set "selectedFile=!file%choice%!"
if not defined selectedFile (
    echo Неверный индекс, выход...
    pause
    goto menu
)

:: Вызов функции разбора аргументов
call :parse_arguments

:: Установка службы для *config *conf файлов
goto create_service_config

:: Создание службы для *BAT файлов
:create_service_bat
call :tcp_enable

set ARGS=%args%
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
echo Итоговые аргументы: !ARGS!
set SRVCNAME=zapret

net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
sc create %SRVCNAME% binPath= "\"%BIN_PATH%winws.exe\" !ARGS!" DisplayName= "zapret" start= auto
sc description %SRVCNAME% "Zapret DPI bypass software"
sc start %SRVCNAME%
for %%F in ("!file%choice%!") do (
    set "filename=%%~nF"
)
reg add "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube /t REG_SZ /d "!filename!" /f

pause
goto menu

:: Создание службы для *config, *conf файлов
:create_service_config
call :tcp_enable

set ARGS=%args%
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
echo Итоговые аргументы: !ARGS!
set SRVCNAME2=zapret_config

net stop %SRVCNAME2% >nul 2>&1
sc delete %SRVCNAME2% >nul 2>&1
sc create %SRVCNAME2% binPath= "\"%BIN_PATH%winws.exe\" !ARGS!" DisplayName= "zapret_config" start= auto
sc description %SRVCNAME2% "Zapret DPI bypass software"
sc start %SRVCNAME2%
for %%F in ("!file%choice%!") do (
    set "filename=%%~nF"
)
reg add "HKLM\System\CurrentControlSet\Services\zapret_config" /v zapret-discord-youtube /t REG_SZ /d "!filename!" /f

pause
goto menu

:: ==================== УДАЛЕНИЕ СЛУЖБ ====================
:service_remove
cls
chcp 1251 > nul

:: Удаление службы zapret
set SRVCNAME=zapret
sc query "!SRVCNAME!" >nul 2>&1
if "!errorlevel!"=="0" (
    net stop %SRVCNAME%
    sc delete %SRVCNAME%
) else (
    echo Служба "%SRVCNAME%" не установлена.
)

:: Удаление службы zapret_config
set SRVCNAME2=zapret_config
sc query "!SRVCNAME2!" >nul 2>&1
if "!errorlevel!"=="0" (
    net stop %SRVCNAME2%
    sc delete %SRVCNAME2%
) else (
    echo Служба "%SRVCNAME2%" не установлена.
)

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if "!errorlevel!"=="0" (
    taskkill /IM winws.exe /F > nul
)

sc query "WinDivert" >nul 2>&1
if "!errorlevel!"=="0" (
    net stop "WinDivert"

    sc query "WinDivert" >nul 2>&1
    if "!errorlevel!"=="0" (
        sc delete "WinDivert"
    )
)
net stop "WinDivert14" >nul 2>&1
sc delete "WinDivert14" >nul 2>&1

pause
goto menu

:: ==================== СТАТУС СЛУЖБ ====================
:service_status
cls
chcp 1251 > nul

sc query "zapret" >nul 2>&1
if "!errorlevel!"=="0" (
    for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube 2^>nul') do echo Используется бат файл: "%%B"
)
call :test_service zapret

sc query "zapret_config" >nul 2>&1
if "!errorlevel!"=="0" (
    for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret_config" /v zapret-discord-youtube 2^>nul') do echo Используется конфиг файл: "%%B"
)

call :test_service zapret_config
call :test_service WinDivert

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if "!errorlevel!"=="0" (
    call :PrintGreen "Сервис (winws.exe) запущен"
) else (
    call :PrintRed "Сервис (winws.exe) не запущен"
)

pause
goto menu

:test_service
set "ServiceName=%~1"
set "ServiceStatus="

:: Проверка службы
sc query "%ServiceName%" | findstr /i "RUNNING" > nul
if "!errorlevel!"=="0" (
    set "ServiceStatus=RUNNING"
) else (
    sc query "%ServiceName%" | findstr /i "STOP_PENDING" > nul
    if "!errorlevel!"=="0" (
        set "ServiceStatus=STOP_PENDING"
    ) else (
        set "ServiceStatus=STOPPED"
    )
)

if "%ServiceStatus%"=="RUNNING" (
    if "%~2"=="soft" (
        echo "%ServiceName%" УЖЕ ЗАПУЩЕНА как служба. Используйте "service.bat" и выберите "Удалить службу" сначала, если хотите запустить обычный бат файл.
        pause
        exit /b
    ) else (
        call :PrintGreen "Служба "%ServiceName%" запущена."
    )
) else if "%ServiceStatus%"=="STOP_PENDING" (
    call :PrintYellow "!ServiceName! находится в состоянии ОСТАНОВКИ, это может быть вызвано конфликтом с другим обходом. Запустите диагностику для исправления конфликтов"
) else if not "%~2"=="soft" (
    call :PrintRed "Служба "%ServiceName%" не запущена."
)

exit /b

:: ==================== ДИАГНОСТИКА ====================
:service_diagnostics
chcp 1251 > nul
cls

:: Base Filtering Engine
sc query BFE | findstr /I "RUNNING" > nul
if "!errorlevel!"=="0" (
    call :PrintGreen "Проверка Службы базовой фильтрации пройдена"
) else (
    call :PrintRed "[X]  Служба базовой фильтрации не запущена. Она необходима для работы zapret"
)
echo:

:: Proxy check
set "proxyEnabled=0"
set "proxyServer="

for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable 2^>nul ^| findstr /i "ProxyEnable"') do (
    if "%%B"=="0x1" set "proxyEnabled=1"
)

if !proxyEnabled!==1 (
    for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer 2^>nul ^| findstr /i "ProxyServer"') do (
        set "proxyServer=%%B"
    )
    
    call :PrintYellow "[?] Системный прокси включен: !proxyServer!"
    call :PrintYellow Убедитесь, что он корректно настроен, или отключите его, если не используете прокси"
) else (
    call :PrintGreen "Проверка прокси пройдена"
)
echo:

:: TCP timestamps check
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul
if "!errorlevel!"=="0" (
    call :PrintGreen "Проверка TCP-меток времени пройдена"
) else (
    call :PrintYellow "[?] TCP-метки времени отключены. Включение меток времени......"
    netsh interface tcp set global timestamps=enabled > nul 2>&1
    if "!errorlevel!"=="0" (
        call :PrintGreen "TCP-метки времени успешно включены"
    ) else (
        call :PrintRed "[X]  Не удалось включить TCP-метки времени"
    )
)
echo:

:: AdguardSvc.exe
tasklist /FI "IMAGENAME eq AdguardSvc.exe" | find /I "AdguardSvc.exe" > nul
if "!errorlevel!"=="0" (
    call :PrintRed "[X] Обнаружен процесс Adguard. Adguard может вызывать проблемы с Discord"
    call :PrintRed "https://github.com/Flowseal/zapret-discord-youtube/issues/417"
) else (
    call :PrintGreen "Проверка Adguard пройдена"
)
echo:

:: Killer
sc query | findstr /I "Killer" > nul
if "!errorlevel!"=="0" (
    call :PrintRed "[X] Обнаружена служба Killer. Killer конфликтует с zapret"
    call :PrintRed "https://github.com/Flowseal/zapret-discord-youtube/issues/2512#issuecomment-2821119513"
) else (
    call :PrintGreen "Проверка Killer пройдена"
)
echo:

:: Intel Connectivity Network Service
sc query | findstr /I "Intel" | findstr /I "Connectivity" | findstr /I "Network" > nul
if "!errorlevel!"=="0" (
    call :PrintRed "[X] Обнаружена служба подключения Intel. Она конфликтует с zapret"
    call :PrintRed "https://github.com/ValdikSS/GoodbyeDPI/issues/541#issuecomment-2661670982"
) else (
    call :PrintGreen "Проверка подключения Intel пройдена"
)
echo:

:: Check Point
set "checkpointFound=0"
sc query | findstr /I "TracSrvWrapper" > nul
if "!errorlevel!"=="0" (
    set "checkpointFound=1"
)

sc query | findstr /I "EPWD" > nul
if "!errorlevel!"=="0" (
    set "checkpointFound=1"
)

if !checkpointFound!==1 (
    call :PrintRed "[X] Обнаружена служба Check Point. Check Point конфликтует с zapret"
    call :PrintRed "Попробуйте удалить Check Point"
) else (
    call :PrintGreen "Проверка Check Point пройдена"
)
echo:

:: SmartByte
sc query | findstr /I "SmartByte" > nul
if "!errorlevel!"=="0" (
    call :PrintRed "[X] Обнаружена служба SmartByte. SmartByte конфликтует с zapret"
    call :PrintRed "Попробуйте удалить или отключить SmartByte через services.msc"
) else (
    call :PrintGreen "Проверка SmartByte пройдена"
)
echo:

:: VPN
sc query | findstr /I "VPN" > nul
if "!errorlevel!"=="0" (
    call :PrintYellow "[?] Обнаружены некоторые VPN-службы. Некоторые VPN могут конфликтовать с zapret"
    call :PrintYellow "Убедитесь, что все VPN отключены"
) else (
    call :PrintGreen "Проверка VPN пройдена"
)
echo:

:: DNS
set "dohfound=0"
for /f "delims=" %%a in ('powershell -Command "Get-ChildItem -Recurse -Path 'HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\' | Get-ItemProperty | Where-Object { $_.DohFlags -gt 0 } | Measure-Object | Select-Object -ExpandProperty Count"') do (
    if %%a gtr 0 (
        set "dohfound=1"
    )
)
if !dohfound!==0 (
    call :PrintYellow "[?] Убедитесь, что вы настроили безопасный DNS в браузере с использованием стороннего DNS-провайдера,"
    call :PrintYellow "Если вы используете Windows 11, вы можете настроить зашифрованный DNS в Параметрах, чтобы скрыть это предупреждение"
) else (
    call :PrintGreen "Проверка безопасного DNS пройдена"
)
echo:

:: Конфликтующий WinDivert 
tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
set "winws_running=!errorlevel!"

sc query "WinDivert" | findstr /I "RUNNING STOP_PENDING" > nul
set "windivert_running=!errorlevel!"

if !winws_running! neq 0 if !windivert_running!==0 (
    call :PrintYellow "[?] winws.exe не запущен, но служба WinDivert активна. Попытка удалить WinDivert..."
    
    net stop "WinDivert" >nul 2>&1
    sc delete "WinDivert" >nul 2>&1
    sc query "WinDivert" >nul 2>&1
    if "!errorlevel!"=="0" (
        call :PrintRed "[X] Не удалось удалить WinDivert. Проверка конфликтующих служб..."
        
        set "conflicting_services=GoodbyeDPI"
        set "found_conflict=0"
        
        for %%s in (!conflicting_services!) do (
            sc query "%%s" >nul 2>&1
            if "!errorlevel!"=="0" (
                call :PrintYellow "[?] Найдена конфликтующая служба: %%s. Остановка и удаление..."
                net stop "%%s" >nul 2>&1
                sc delete "%%s" >nul 2>&1
                if "!errorlevel!"=="0" (
                    call :PrintGreen "Служба успешно удалена: %%s"
                ) else (
                    call :PrintRed "[X] Не удалось удалить службу: %%s"
                )
                set "found_conflict=1"
            )
        )
        
        if !found_conflict!==0 (
            call :PrintRed "[X] Конфликтующие службы не найдены. Проверьте вручную, не использует ли другой обход WinDivert."
        ) else (
            call :PrintYellow "[?] Повторная попытка удалить WinDivert..."

            net stop "WinDivert" >nul 2>&1
            sc delete "WinDivert" >nul 2>&1
            sc query "WinDivert" >nul 2>&1
            if !errorlevel! neq 0 (
                call :PrintGreen "WinDivert успешно удален после удаления конфликтующих служб"
            ) else (
                call :PrintRed "[X] WinDivert все еще не может быть удален. Проверьте вручную, не использует ли другой обход WinDivert."
            )
        )
    ) else (
        call :PrintGreen "WinDivert успешно удален"
    )
    
    echo:
)

:: Конфликтующие обходы
set "conflicting_services=GoodbyeDPI discordfix_zapret winws1 winws2"
set "found_any_conflict=0"
set "found_conflicts="

for %%s in (!conflicting_services!) do (
    sc query "%%s" >nul 2>&1
    if "!errorlevel!"=="0" (
        if "!found_conflicts!"=="" (
            set "found_conflicts=%%s"
        ) else (
            set "found_conflicts=!found_conflicts! %%s"
        )
        set "found_any_conflict=1"
    )
)

if !found_any_conflict!==1 (
    call :PrintRed "[X] Обнаружены конфликтующие службы обхода: !found_conflicts!"
    
    set "CHOICE="
    set /p "CHOICE=Вы хотите удалить эти конфликтующие службы? (Y/N) (по умолчанию: N) "
    if "!CHOICE!"=="" set "CHOICE=N"
    if "!CHOICE!"=="y" set "CHOICE=Y"
    
    if /i "!CHOICE!"=="Y" (
        for %%s in (!found_conflicts!) do (
            call :PrintYellow "Остановка и удаление службы: %%s"
            net stop "%%s" >nul 2>&1
            sc delete "%%s" >nul 2>&1
            if "!errorlevel!"=="0" (
                call :PrintGreen "Служба успешно удалена: %%s"
            ) else (
                call :PrintRed "[X] Не удалось удалить службу: %%s"
            )
        )

        net stop "WinDivert" >nul 2>&1
        sc delete "WinDivert" >nul 2>&1
        net stop "WinDivert14" >nul 2>&1
        sc delete "WinDivert14" >nul 2>&1
    )
    
    echo:
)

:: Очистка кэша Discord
set "CHOICE="
set /p "CHOICE=Вы хотите очистить кэш Discord? (Y/N) (по умолчанию: Y)  "
if "!CHOICE!"=="" set "CHOICE=Y"
if "!CHOICE!"=="y" set "CHOICE=Y"

if /i "!CHOICE!"=="Y" (
    tasklist /FI "IMAGENAME eq Discord.exe" | findstr /I "Discord.exe" > nul
    if "!errorlevel!"=="0" (
        echo Discord запущен, закрываем...
        taskkill /IM Discord.exe /F > nul
        if !errorlevel! == 0 (
            call :PrintGreen "Discord успешно закрыт."
        ) else (
            call :PrintRed "Не удалось закрыть Discord"
        )
    )

    set "discordCacheDir=%appdata%\discord"

    for %%d in ("Cache" "Code Cache" "GPUCache") do (
        set "dirPath=!discordCacheDir!\%%~d"
        if exist "!dirPath!" (
            rd /s /q "!dirPath!"
            if "!errorlevel!"=="0" (
                call :PrintGreen "Успешно удалено !dirPath!"
            ) else (
                call :PrintRed "Не удалось удалить !dirPath!"
            )
        ) else (
            call :PrintRed "!dirPath! не существует "
        )
    )
)
echo:

pause
goto menu


:: ==================== РАЗБОР АРГУМЕНТОВ ====================
:parse_arguments
set "args_with_value=sni host altorder"
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="

for /f "tokens=*" %%a in ('type "!selectedFile!"') do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"

    echo !line! | findstr /i "%BIN%winws.exe" >nul
    if not errorlevel 1 (
        set "capture=1"
    )

    if !capture!==1 (
        if not defined args (
            set "line=!line:*%BIN%winws.exe"=!"
        )

        set "temp_args="
        for %%i in (!line!) do (
            set "arg=%%i"

            if not "!arg!"=="^" (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 (
                    set "mergeargs=0"
                )

                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"

                    echo !arg! | findstr ":" >nul
                    if "!errorlevel!"=="0" (
                        set "arg=\!QUOTE!!arg!\!QUOTE!"
                    ) else if "!arg:~0,1!"=="@" (
                        set "arg=\!QUOTE!@%~dp0!arg:~1!\!QUOTE!"
                    ) else if "!arg:~0,5!"=="%%BIN%%" (
                        set "arg=\!QUOTE!!BIN_PATH!!arg:~5!\!QUOTE!"
                    ) else if "!arg:~0,7!"=="%%LISTS%%" (
                        set "arg=\!QUOTE!!LISTS_PATH!!arg:~7!\!QUOTE!"
                    ) else (
                        set "arg=\!QUOTE!%~dp0!arg!\!QUOTE!"
                    )
                ) else if "!arg:~0,12!" EQU "%%GameFilter%%" (
                    set "arg=%GameFilter%"
                )

                if !mergeargs!==1 (
                    set "temp_args=!temp_args!,!arg!"
                ) else if !mergeargs!==3 (
                    set "temp_args=!temp_args!=!arg!"
                    set "mergeargs=1"
                ) else (
                    set "temp_args=!temp_args! !arg!"
                )

                if "!arg:~0,2!" EQU "--" (
                    set "mergeargs=2"
                ) else if !mergeargs! GEQ 1 (
                    if !mergeargs!==2 set "mergeargs=1"

                    for %%x in (!args_with_value!) do (
                        if /i "%%x"=="!arg!" (
                            set "mergeargs=3"
                        )
                    )
                )
            )
        )

        if not "!temp_args!"=="" (
            set "args=!args! !temp_args!"
        )
    )
)

:: ==================== СЛУЖЕБНЫЕ ФУНКЦИИ ====================
:: Игровые фильтры
:game_switch_status
chcp 1251 > nul

set "gameFlagFile=%~dp0bin\game_filter.enabled"

if exist "%gameFlagFile%" (
    set "GameFilterStatus=Включен"
    set "GameFilter=1024-65535"
) else (
    set "GameFilterStatus=Выключен"
    set "GameFilter=12"
)
exit /b

:game_switch
chcp 1251 > nul
cls

if not exist "%gameFlagFile%" (
    echo Включение игрового фильтра...
    echo ENABLED > "%gameFlagFile%"
    call :PrintYellow "Переустановите службу или перезапустите запрет для применения изменений"
) else (
    echo Выключение игрового фильтра...
    del /f /q "%gameFlagFile%"
    call :PrintYellow "Переустановите службу или перезапустите запрет для применения изменений"
)

pause
goto menu

:: Фильтр айпи general
:ipset_switch_status_general
chcp 1251 > nul

set "listFile=%~dp0lists\ipset-general.txt"
for /f %%i in ('type "%listFile%" 2^>nul ^| find /c /v ""') do set "lineCount=%%i"

if !lineCount!==0 (
    set "IPsetStatusGeneral=Любой"
) else (
    findstr /R "^203\.0\.113\.113/32$" "%listFile%" >nul
    if "!errorlevel!"=="0" (
        set "IPsetStatusGeneral=Нет"
    ) else (
        set "IPsetStatusGeneral=Загружен"
    )
)
exit /b

:ipset_switch_general
chcp 1251 > nul
cls

set "listFile=%~dp0lists\ipset-general.txt"
set "backupFile=%listFile%.backup"

if "%IPsetStatusGeneral%"=="Загружен" (
    echo Смена на режим Нет...
    
    if not exist "%backupFile%" (
        ren "%listFile%" "ipset-general.txt.backup"
    ) else (
        del /f /q "%backupFile%"
        ren "%listFile%" "ipset-general.txt.backup"
    )
    
    >"%listFile%" (
        echo 203.0.113.113/32
    )
    
) else if "%IPsetStatusGeneral%"=="Нет" (
    echo Смена на режим Любой...
    
    >"%listFile%" (
        rem Creating empty file
    )
    
) else if "%IPsetStatusGeneral%"=="Любой" (
    echo Смена на режим Загружен...
    
    if exist "%backupFile%" (
        del /f /q "%listFile%"
        ren "%backupFile%" "ipset-general.txt"
    ) else (
        echo Ошибка: нет резервной копии для восстановления. Сначала обновите список в меню
        pause
        goto menu_ip
    )
    
)

call :ipset_switch_status_general
pause
goto menu_ip

:: Обновление списка айпи general
:ipset_update_general
set "listFile=%~dp0lists\ipset-general.txt"
set "url=https://raw.githubusercontent.com/Witchdima/zapret-discord-youtube/refs/heads/main/.assets/ipset-generalupd.txt"

echo Загрузка основного списка айпи...
if exist "%SystemRoot%\System32\curl.exe" (
    curl -L -o "%listFile%" "%url%"
) else (
    powershell -Command ^
        "$url = '%url%';" ^
        "$out = '%listFile%';" ^
        "$dir = Split-Path -Parent $out;" ^
        "if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null };" ^
        "Write-Host 'Скачивание...' -NoNewline;" ^
        "$res = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing;" ^
        "if ($res.StatusCode -eq 200) { $res.Content | Out-File -FilePath $out -Encoding UTF8; Write-Host ' OK' -ForegroundColor Green } else { Write-Host ' ОШИБКА' -ForegroundColor Red; exit 1 }"
)

if !errorlevel!==0 (
    echo - Основной список обновлен
) else (
    echo - Ошибка при обновлении основного списка
)
call :ipset_switch_status_general
exit /b
:: Фильтр айпи gaming
:ipset_switch_status_gaming
chcp 1251 > nul

set "listFile=%~dp0lists\ipset-gaming.txt"
for /f %%i in ('type "%listFile%" 2^>nul ^| find /c /v ""') do set "lineCount=%%i"

if !lineCount!==0 (
    set "IPsetStatusGaming=Любой"
) else (
    findstr /R "^203\.0\.113\.113/32$" "%listFile%" >nul
    if "!errorlevel!"=="0" (
        set "IPsetStatusGaming=Нет"
    ) else (
        set "IPsetStatusGaming=Загружен"
    )
)
exit /b

:ipset_switch_gaming
chcp 1251 > nul
cls

set "listFile=%~dp0lists\ipset-gaming.txt"
set "backupFile=%listFile%.backup"

if "%IPsetStatusGaming%"=="Загружен" (
    echo Смена на режим Нет...
    
    if not exist "%backupFile%" (
        ren "%listFile%" "ipset-gaming.txt.backup"
    ) else (
        del /f /q "%backupFile%"
        ren "%listFile%" "ipset-gaming.txt.backup"
    )
    
    >"%listFile%" (
        echo 203.0.113.113/32
    )
    
) else if "%IPsetStatusGaming%"=="Нет" (
    echo Смена на режим Любой...
    
    >"%listFile%" (
        rem Creating empty file
    )
    
) else if "%IPsetStatusGaming%"=="Любой" (
    echo Смена на режим Загружен...
    
    if exist "%backupFile%" (
        del /f /q "%listFile%"
        ren "%backupFile%" "ipset-gaming.txt"
    ) else (
        echo Ошибка: нет резервной копии для восстановления. Сначала обновите список в меню
        pause
        goto menu_ip
    )
    
)

call :ipset_switch_status_gaming
pause
goto menu_ip

:: Обновление списка айпи gaming
:ipset_update_gaming
set "listFile=%~dp0lists\ipset-gaming.txt"
set "url=https://raw.githubusercontent.com/Witchdima/zapret-discord-youtube/refs/heads/main/.assets/ipset-gamingupd.txt"

echo Загрузка игрового списка айпи...
if exist "%SystemRoot%\System32\curl.exe" (
    curl -L -o "%listFile%" "%url%"
) else (
    powershell -Command ^
        "$url = '%url%';" ^
        "$out = '%listFile%';" ^
        "$dir = Split-Path -Parent $out;" ^
        "if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null };" ^
        "Write-Host 'Скачивание...' -NoNewline;" ^
        "$res = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing;" ^
        "if ($res.StatusCode -eq 200) { $res.Content | Out-File -FilePath $out -Encoding UTF8; Write-Host ' OK' -ForegroundColor Green } else { Write-Host ' ОШИБКА' -ForegroundColor Red; exit 1 }"
)

if !errorlevel!==0 (
    echo - Игровой список обновлен
) else (
    echo - Ошибка при обновлении игрового списка
)
call :ipset_switch_status_gaming
exit /b

:: Обновление обоих списков айпи
:ipset_update_both
chcp 1251 > nul
cls
echo Обновление обоих списков айпи...
call :ipset_update_general
call :ipset_update_gaming
echo - Все списки обновлены!
pause
goto menu_ip

:: Включение TCP
:tcp_enable
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul || netsh interface tcp set global timestamps=enabled > nul 2>&1
exit /b

:: Цветные обозначение
:PrintGreen
powershell -Command "Write-Host \"%~1\" -ForegroundColor Green"
exit /b

:PrintRed
powershell -Command "Write-Host \"%~1\" -ForegroundColor Red"
exit /b

:PrintYellow
powershell -Command "Write-Host \"%~1\" -ForegroundColor Yellow"
exit /b