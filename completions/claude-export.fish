complete -c claude-export -f
complete -c claude-export -k -a '(__fish_complete_suffix .json)'
complete -c claude-export -s f -l from -x -a '(__fish_complete_directories)' -d 'Folder the browser saves downloads to'
complete -c claude-export -s t -l timeout -x -d 'Seconds to wait for each download'
complete -c claude-export -s h -l help -d 'Show help'
complete -c claude-export -s V -l version -d 'Show version'
