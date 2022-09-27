
set WORKDIR=D:\SonarProjectFolder

set GITSYNC_V8VERSION=8.3.18.1128
set GITSYNC_V8_PATH=C:\Program Files\1cv8\8.3.18.1128\bin\1cv8.exe
set GITSYNC_VERBOSE=true

set GITSYNC_STORAGE_PATH=tcp://server:1542/project
set GITSYNC_STORAGE_USER=robot
@set GITSYNC_STORAGE_PASSWORD=123456789

set GITSYNC_GIT_PATH="C:\Program Files\Git\bin\git.exe"

set GITSYNC_WORKDIR=%WORKDIR%\src
set GITSYNC_TEMP=%WORKDIR%\temp
set GITSYNC_IB_CONNECTION=/F"%WORKDIR%\db"
rem set GITSYNC_IB_USER=
rem @set GITSYNC_IB_PASSWORD=

set GITSYNC_SCRIPT_PATH="C:\Program Files\OneScript\lib\gitsync\src\cmd\gitsync.os"
