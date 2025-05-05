@echo off

set "ASM=bin/asm6f/asm6f_64.exe"
set "FCEUX=bin/fceux/fceux64.exe"

echo %ASM%

"%ASM%" src/main.S -c nesbp.nes

"%FCEUX%" nesbp.nes