@echo off
setlocal
cd /d "%~dp0"
echo PMM CoreR1 candidate-storage TESTS ONLY. Not the PMM application.
echo Synthetic files are created under TEMP. No game files are used.
set "PMM_R1_PACKAGE="
set "PMM_R1_PLAN_OUTPUT="
set "PMM_R1_CAPTURE_OUTPUT="
set "PMM_R1_MEMBERSHIP_OUTPUT="
set "PMM_R1_EXECUTION_OUTPUT="
set "PMM_R1_PUBLICATION_OUTPUT="
set "PMM_TEST_CANDIDATE_CRASH="
set "PMM_TEST_CANDIDATE_PARENT="
if not exist "CoreR1-tests.exe" (
 echo Missing CoreR1-tests.exe. Use the separate test kit, not PMM.exe.
 exit /b 2
)
"CoreR1-tests.exe" -test.v -test.run "Test(Publication|Candidate)" -test.timeout 60s > "Windows-publication-tests.txt" 2>&1
set "RC=%ERRORLEVEL%"
type "Windows-publication-tests.txt"
echo.
echo Exit code: %RC%. This does not validate the PMM application or Palworld.
pause
exit /b %RC%
