@echo off
REM Compila y testea BolsiCore en Windows.
REM
REM Swift en Windows usa el linker y el SDK de Visual Studio, asi que hay que entrar primero
REM al entorno de VS (vcvars64) y despues poner el toolchain en el PATH. El orden importa: si
REM se arma el PATH antes del `call`, cmd expande %PATH% en el estado viejo y `swift build`
REM no encuentra `link.exe`.
REM
REM Uso:  herramientas\swift-win.bat build
REM       herramientas\swift-win.bat test

set "VCVARS=C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
if not exist "%VCVARS%" (
  echo No se encontro vcvars64.bat. Revisa la ruta de Visual Studio en este script.
  exit /b 1
)

call "%VCVARS%" >nul 2>&1
set "PATH=%LOCALAPPDATA%\Programs\Swift\Toolchains\6.3.3+Asserts\usr\bin;%LOCALAPPDATA%\Programs\Swift\Runtimes\6.3.3\usr\bin;%PATH%"
REM El instalador deja SDKROOT en el registro del usuario, pero una consola abierta ANTES
REM de instalar no lo ve. Se fija aca para que el script funcione en cualquier sesion.
set "SDKROOT=%LOCALAPPDATA%\Programs\Swift\Platforms\6.3.3\Windows.platform\Developer\SDKs\Windows.sdk"

cd /d "%~dp0.."
swift %*
