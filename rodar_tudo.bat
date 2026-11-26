@echo off
chcp 65001 >nul
set PGCLIENTENCODING=UTF8
cd /d "%~dp0"

echo ==========================================
echo  SMI - cria o banco e carrega tudo
echo ==========================================
echo.

rem procura o psql.exe dentro de C:\Program Files\PostgreSQL\
set PSQL=
for /d %%D in ("C:\Program Files\PostgreSQL\*") do if exist "%%D\bin\psql.exe" set PSQL=%%D\bin\psql.exe

if "%PSQL%"=="" goto sem_psql

echo Usando: %PSQL%
echo.
set PGUSER=postgres
set /p PGPASSWORD=Senha do usuario postgres:
echo.

rem cria o banco industrial so se ainda nao existir
"%PSQL%" -d postgres -tAc "select 1 from pg_database where datname='industrial'" | find "1" >nul
if errorlevel 1 "%PSQL%" -d postgres -c "create database industrial"

echo.
echo --- rodando sql\01_schema.sql ---
"%PSQL%" -d industrial -v ON_ERROR_STOP=1 -q -f "sql\01_schema.sql"
if errorlevel 1 goto erro

echo.
echo --- rodando sql\02_dados.sql ---
"%PSQL%" -d industrial -v ON_ERROR_STOP=1 -q -f "sql\02_dados.sql"
if errorlevel 1 goto erro

echo.
echo ==========================================
echo  PRONTO. Banco industrial criado.
echo  Deve aparecer: leitura = 2424, alerta = 12
echo ==========================================
pause
exit /b 0

:sem_psql
echo Nao achei o psql.exe em C:\Program Files\PostgreSQL\
echo Confere se o PostgreSQL esta instalado.
pause
exit /b 1

:erro
echo.
echo ==========================================
echo  DEU ERRO. Tira print dessa tela e manda.
echo  (senha errada tambem cai aqui)
echo ==========================================
pause
exit /b 1
