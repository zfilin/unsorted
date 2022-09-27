@echo on

call settings.bat

set DT=%DATE:~6,4%_%DATE:~3,2%_%DATE:~0,2%
call :main >> %WORKDIR%\log\log_%DT%.txt 2>&1
exit /b

:main
@echo ---( %DATE% %TIME% )--------------------------------------------------------------------------------------------------------------

set "GITSYNC_WORKDIR_BS=%GITSYNC_WORKDIR:\=/%"
%GITSYNC_GIT_PATH% config --get-all safe.directory | findstr %GITSYNC_WORKDIR_BS%
if errorlevel 1 (
	%GITSYNC_GIT_PATH% config --global --add safe.directory %GITSYNC_WORKDIR_BS%
	%GITSYNC_GIT_PATH% config --global core.autocrlf false
)

oscript.exe %GITSYNC_SCRIPT_PATH% plugins list | findstr increment
if errorlevel 1 (
	oscript.exe %GITSYNC_SCRIPT_PATH% plugins init
	oscript.exe %GITSYNC_SCRIPT_PATH% plugins enable increment
	oscript.exe %GITSYNC_SCRIPT_PATH% plugins enable unpackForm
	oscript.exe %GITSYNC_SCRIPT_PATH% plugins enable disable-support
)

copy /Y %WORKDIR%\src\VERSION %WORKDIR%\script

oscript.exe %GITSYNC_SCRIPT_PATH% sync

rd /S /Q %GITSYNC_TEMP%
mkdir %GITSYNC_TEMP%

forfiles -p "%WORKDIR%\log" -s -m *.txt -d -10 -c "cmd /c del /F /Q @path"

fc %WORKDIR%\src\VERSION %WORKDIR%\script\VERSION >nul
if errorlevel 1 (
	echo sonar
)

echo done