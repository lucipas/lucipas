clear

echo "currentsong`nclose" | curl.exe -s telnet://127.0.0.1:6600 | grep -E '(^Title:|^Artist:|^file:)'
