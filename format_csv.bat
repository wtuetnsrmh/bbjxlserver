
set csv_path="%cd%\csv"
set fmt_file=*.csv
for /f %%i in ('dir /b /a-d /s  %csv_path%\%fmt_file%') do dos2unix %%i
pause