@echo off
echo Installing PDL Fundamento Scheduler Windows Service...

REM Stop the service if it's running
sc stop "PDL Fundamento Scheduler Service" 2>nul

REM Delete the service if it exists
sc delete "PDL Fundamento Scheduler Service" 2>nul

REM Create the service
sc create "PDL Fundamento Scheduler Service" binPath= "%~dp0PDL.Fundamento.WindowsService.exe" start= auto DisplayName= "PDL Fundamento Scheduler Service"

REM Set service description
sc description "PDL Fundamento Scheduler Service" "PDL Fundamento Scheduler Service for processing EMI data and notifications"

REM Start the service
sc start "PDL Fundamento Scheduler Service"

echo Service installation completed.
pause
