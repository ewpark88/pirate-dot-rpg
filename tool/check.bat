@echo off
rem Runs every harness check on Windows. Logic lives in tool\check.dart.
cd /d "%~dp0.."
dart run tool/check.dart %*
