# bash completion for tomato-play (tp/tomatoplay)

_tomatoplay() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="-s --source -c --continue -f --file -T --trending -L --lucky-tomato -d --download -D --delete -H --history --stats --sources -l --logview -q --quality -v --vlc -V --version -h --help -e --episode -r --range -a --audio --dub --rofi --dmenu --no-detach --exit-after-play -n --next --preview --cache-info --clear-cache --no-cache -U --update"

    case "$prev" in
        -s | --source)
            opts="all anidb aniwatch gogoanime 9anime animeplanet anisearch youtube bilibili nyaa"
            ;;
        -a | --audio)
            opts="sub dub"
            ;;
    esac

    COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    return 0
}

complete -F _tomatoplay tp tomatoplay