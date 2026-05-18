# Shell Diagnostic Script
# Run this in Windows Command Prompt or PowerShell to check shell availability

echo === Checking Git Bash ===
if exist "C:\Program Files\Git\bin\bash.exe" (
    echo Found Git Bash at C:\Program Files\Git\bin\bash.exe
    "C:\Program Files\Git\bin\bash.exe" --version
) else (
    echo Git Bash NOT found at default location
)

echo.
echo === Checking WSL ===
wsl --status 2>nul || echo WSL not available

echo.
echo === Checking PowerShell ===
pwsh -Version

echo.
echo === Checking PATH for Git ===
where git 2>nul || echo git not in PATH

echo.
echo === System PATH (Git-related) ===
echo %PATH% | findstr /i "git" || echo No Git in PATH