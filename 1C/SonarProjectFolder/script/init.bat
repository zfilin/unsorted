@echo on

call settings.bat

cd %GITSYNC_WORKDIR%

git init
git config --local core.quotepath false

gitsync init

