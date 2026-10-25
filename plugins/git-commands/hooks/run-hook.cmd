: << 'CMDBLOCK'
@echo off
REM git-commands: roda um script de hook (bash) no Windows, no Mac e no Linux.
REM No Windows, o cmd roda este bloco; no bash, este bloco e ignorado.
REM Sem Git Bash, sai em silencio: o plugin continua funcionando, so sem o hook.
REM Ideia do run-hook.cmd do superpowers (licenca MIT).
setlocal
set "BASH_EXE="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH_EXE if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH_EXE if defined LOCALAPPDATA if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "BASH_EXE=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if not defined BASH_EXE exit /b 0
"%BASH_EXE%" "%~dp0%~1" %2 %3 %4 %5 %6 %7 %8 %9
exit /b %ERRORLEVEL%
CMDBLOCK

# Mac, Linux e Git Bash: roda o script pedido, que fica na mesma pasta deste arquivo.
case "$0" in
  */*|*\\*) gc_dir="${0%[/\\]*}" ;;
  *) gc_dir=. ;;
esac
gc_script="$1"
shift
exec "${BASH:-bash}" "$gc_dir/$gc_script" "$@"
