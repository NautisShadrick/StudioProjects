@echo off
setlocal enabledelayedexpansion

:: Initialize total line count
set totalLines=0

:: Loop through all .lua files
for /R %%F in (*.lua) do (
    for /f "usebackq delims=" %%L in ("%%F") do (
        set "line=%%L"
        :: Remove leading spaces
        set "line=!line:~0,1!!line:~1!"
        call :trim line

        :: Check if line is NOT blank and does NOT start with --
        if not "!line!"=="" (
            if "!line:~0,2!" NEQ "--" (
                set /a totalLines+=1
            )
        )
    )
)

echo Total non-blank, non-comment lines in all .lua files: !totalLines!
pause
exit /b

:: Function to trim leading/trailing spaces (basic approach)
:trim
setlocal EnableDelayedExpansion
set "str=!%1!"
:: Remove leading spaces
:trimLoop1
if "!str:~0,1!"==" " set "str=!str:~1!" & goto :trimLoop1
:: Remove trailing spaces
:trimLoop2
if not "!str!"=="" if "!str:~-1!"==" " set "str=!str:~0,-1!" & goto :trimLoop2
endlocal & set "%1=%str%"
exit /b
