# Terminal menu adapters and top-level home menu.

menu() {
    _menu_program=$1
    _menu_prompt=$2
    _menu_multi=${3:-}
    _menu_flags=${4:-}
    case "$_menu_program" in
        fzf) fzf --reverse --cycle --ansi --prompt "$_menu_prompt" $_menu_multi $_menu_flags ;;
        rofi) rofi -sort -dmenu -i -p "$_menu_prompt" $_menu_multi $_menu_flags ;;
        dmenu) dmenu -l 20 -p "$_menu_prompt" $_menu_flags ;;
        *) "$_menu_program" $_menu_flags "$_menu_prompt" ;;
    esac
}

# Print the home menu and set _home_action to a stable action token.
# The main CLI owns the behavior for each action.
home_menu() {
    _home_action=
    while :; do
        printf "\n    \033[1;32mWhat'll it be?\033[0m\n"
        printf "      1) Search for an anime\n"
        printf "      2) Continue watching\n"
        printf "      3) View watch history\n"
        printf "      4) See what's Hot on the Vine\n"
        printf "      5) Lucky Tomato (surprise me!)\n"
        printf "      6) Play a local file\n"
        printf "      q) Quit\n"
        printf "\n    Choice [1-6/q]: "
        if ! read -r _home_choice; then
            return 1
        fi
        case "$_home_choice" in
            1|s|search) _home_action=search; return 0 ;;
            2|c|continue) _home_action=continue; return 0 ;;
            3|h|history) _home_action=history; return 0 ;;
            4|t|trending) _home_action=trending; return 0 ;;
            5|l|lucky) _home_action=lucky; return 0 ;;
            6|f|file|local) _home_action=files; return 0 ;;
            q|Q|e|quit|exit) _home_action=quit; return 0 ;;
            *) printf "\033[1;31m    Not a valid pick, try again.\033[0m\n" ;;
        esac
    done
}
