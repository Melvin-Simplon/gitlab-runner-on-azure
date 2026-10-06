#!/usr/bin/env bash
# Interactive two-level menu built from the "##@" sections and "##" descriptions of the Makefiles.
set -euo pipefail
shopt -s extglob

: "${MAKE:=make}"

# Display order of the sections, unknown ones come last.
readonly SECTION_ORDER=("Setup" "Infra" "Cluster" "Runner" "Grafana" "Dev")
# Accent color (Mew pink), grey for descriptions and orange for warnings.
readonly ACCENT=212
readonly MUTED=245
readonly WARNING=214

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    COLOR=true
else
    COLOR=false
fi

SECTIONS=()
declare -A TARGETS_OF=()
declare -A DESCRIPTION_OF=()
MENU_SECTIONS=()
MENU_TARGETS=()
TARGETS=()
BOX_LINES=()

usage() {
    printf 'Usage: %s <makefile> [<makefile>...]\n' "$(basename "$0")" >&2
    exit 2
}

# Prints a color code, or nothing when colors are off.
fg() {
    [[ "${COLOR}" == "true" ]] && printf '\e[38;5;%sm' "$1"
    return 0
}

bold()  { [[ "${COLOR}" == "true" ]] && printf '\e[1m'; return 0; }

# Prints a title in bold accent color.
heading() {
    if [[ "${COLOR}" == "true" ]]; then
        printf '\e[1;38;5;%sm%s\e[0m' "${ACCENT}" "$1"
    else
        printf '%s' "$1"
    fi
}
reset() { [[ "${COLOR}" == "true" ]] && printf '\e[0m'; return 0; }

# Reads every makefile and merges a section declared in several files.
parse_targets() {
    local file line section="Other" target
    for file in "$@"; do
        [[ -f "${file}" ]] || continue
        while IFS= read -r line; do
            if [[ "${line}" =~ ^##@\ (.+)$ ]]; then
                section="${BASH_REMATCH[1]}"
                [[ -v "TARGETS_OF[${section}]" ]] || { SECTIONS+=("${section}"); TARGETS_OF["${section}"]=""; }
            elif [[ "${line}" =~ ^([a-zA-Z0-9_-]+):[^#]*##\ (.+)$ ]]; then
                target="${BASH_REMATCH[1]}"
                [[ "${target}" == "menu" ]] && continue
                [[ -v "TARGETS_OF[${section}]" ]] || { SECTIONS+=("${section}"); TARGETS_OF["${section}"]=""; }
                TARGETS_OF["${section}"]+="${target} "
                DESCRIPTION_OF["${target}"]="${BASH_REMATCH[2]}"
            fi
        done < "${file}"
    done
}

# Sections of SECTION_ORDER first, then the others as found.
ordered_sections() {
    local section known known_section
    for section in "${SECTION_ORDER[@]}"; do
        [[ -v "TARGETS_OF[${section}]" ]] && printf '%s\n' "${section}"
    done
    for section in "${SECTIONS[@]}"; do
        known=false
        for known_section in "${SECTION_ORDER[@]}"; do
            [[ "${section}" == "${known_section}" ]] && known=true
        done
        [[ "${known}" == "true" ]] || printf '%s\n' "${section}"
    done
}

# Braille art drawn on the left of the menu when the terminal is wide enough.
readonly ART_WIDTH=25
# Gradient of the art from top to bottom, in the pinks of Mew.
readonly ART_GRADIENT=(205 211 212 218 219 225)
mapfile -t ART <<'EOF'
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡴⠞⢳⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡔⠋⠀⢰⠎⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⢆⣤⡞⠃⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⢠⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢀⣀⣾⢳⠀⠀⠀⠀⢸⢠⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⣀⡤⠴⠊⠉⠀⠀⠈⠳⡀⠀⠀⠘⢎⠢⣀⣀⣀⠀⠀⠀⠀⠀⠀⠀
⠳⣄⠀⠀⡠⡤⡀⠀⠘⣇⡀⠀⠀⠀⠉⠓⠒⠺⠭⢵⣦⡀⠀⠀⠀
⠀⢹⡆⠀⢷⡇⠁⠀⠀⣸⠇⠀⠀⠀⠀⠀⢠⢤⠀⠀⠘⢷⣆⡀⠀
⠀⠀⠘⠒⢤⡄⠖⢾⣭⣤⣄⠀⡔⢢⠀⡀⠎⣸⠀⠀⠀⠀⠹⣿⡀
⠀⠀⢀⡤⠜⠃⠀⠀⠘⠛⣿⢸⠀⡼⢠⠃⣤⡟⠀⠀⠀⠀⠀⣿⡇
⠀⠀⠸⠶⠖⢏⠀⠀⢀⡤⠤⠇⣴⠏⡾⢱⡏⠁⠀⠀⠀⠀⢠⣿⠃
⠀⠀⠀⠀⠀⠈⣇⡀⠿⠀⠀⠀⡽⣰⢶⡼⠇⠀⠀⠀⠀⣠⣿⠟⠀
⠀⠀⠀⠀⠀⠀⠈⠳⢤⣀⡶⠤⣷⣅⡀⠀⠀⠀⣀⡠⢔⠕⠁⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⠫⠿⠿⠿⠛⠋⠁⠀⠀⠀⠀
EOF
readonly ART

# Colors one art row with its gradient step.
art_row() {
    local color="${ART_GRADIENT[$1 * ${#ART_GRADIENT[@]} / ${#ART[@]}]:-${ACCENT}}"
    if [[ "${COLOR}" == "true" ]]; then
        printf '\e[1;38;5;%sm%s\e[0m' "${color}" "$2"
    else
        printf '%s' "$2"
    fi
}

# Infra facts shown above the menu, read once when it opens.
INFO_CLUSTER=""
INFO_IP=""

load_infra_info() {
    local nodes ready
    if nodes="$(kubectl --context "${CLUSTER_NAME:-}" get nodes --no-headers --request-timeout=3s 2> /dev/null)"; then
        ready="$(grep -c ' Ready ' <<< "${nodes}" || true)"
        INFO_CLUSTER="${CLUSTER_NAME:-?}, ${ready}/$(grep -c . <<< "${nodes}") nodes ready"
    else
        INFO_CLUSTER="$(fg "${WARNING}")${CLUSTER_NAME:-?} unreachable$(reset)"
    fi
    INFO_IP="$(getent hosts "${DOMAIN:-}" 2> /dev/null | awk '{ print $1; exit }')"
    : "${INFO_IP:=unknown}"
}

# Prints one infra fact with its label.
info_line() {
    printf ' %s%-8s%s %s' "$(fg "${ACCENT}")" "$1" "$(reset)" "$2"
}

# Prints the infra facts and the given lines next to the art.
render() {
    local lines=() line plain width=0 i rows columns blank offset
    lines=("$(info_line Cluster "${INFO_CLUSTER}")"
        "$(info_line Grafana "https://${DOMAIN:-?}")"
        "$(info_line "LB IP" "${INFO_IP}")"
        "" "$@")
    for line in "${lines[@]}"; do
        plain="${line//$'\e'\[*([0-9;])m/}"
        (( ${#plain} > width )) && width="${#plain}"
    done
    columns="$(tput cols 2> /dev/null || printf '80')"

    printf '\n'
    if (( columns < 2 + ART_WIDTH + 3 + width )); then
        printf '  %s\n' "${lines[@]}"
    else
        # Center the menu vertically next to the art.
        offset=$(( (${#ART[@]} - ${#lines[@]}) / 2 ))
        if (( offset > 0 )); then
            for (( i = 0; i < offset; i++ )); do lines=("" "${lines[@]}"); done
        fi
        rows=$(( ${#lines[@]} > ${#ART[@]} ? ${#lines[@]} : ${#ART[@]} ))
        # Pad under the art with braille blanks, the same glyph as the art.
        blank=""
        for (( i = 0; i < ART_WIDTH; i++ )); do blank+="⠀"; done
        for (( i = 0; i < rows; i++ )); do
            printf '  %s   %s\n' "$(art_row "${i}" "${ART[i]:-${blank}}")" "${lines[i]:-}"
        done
    fi
    printf '\n'
}

# Draws a thin frame around the given lines, with the title in the top border.
box() {
    local title="$1" line plain width pad
    shift
    width=$(( ${#title} + 2 ))
    for line in "$@"; do
        plain="${line//$'\e'\[*([0-9;])m/}"
        (( ${#plain} > width )) && width="${#plain}"
    done
    BOX_LINES=("$(fg "${ACCENT}")┌─ $(reset)$(heading "${title}")$(fg "${ACCENT}") $(repeat ─ $(( width - ${#title} - 2 )))─┐$(reset)")
    for line in "$@"; do
        plain="${line//$'\e'\[*([0-9;])m/}"
        pad=$(( width - ${#plain} ))
        BOX_LINES+=("$(fg "${ACCENT}")│$(reset) ${line}$(repeat ' ' "${pad}") $(fg "${ACCENT}")│$(reset)")
    done
    BOX_LINES+=("$(fg "${ACCENT}")└$(repeat ─ $(( width + 2 )))┘$(reset)")
}

# Prints a character the given number of times.
repeat() {
    local out
    printf -v out '%*s' "$2" ''
    printf '%s' "${out// /$1}"
}

# Prints one numbered command with its description.
item_line() {
    printf '%s%2d%s  %-20s %s%s%s' "$(fg "${ACCENT}")" "$1" "$(reset)" "$2" "$(fg "${MUTED}")" "$3" "$(reset)"
}

# Loads the commands of one section.
section_targets() {
    read -ra TARGETS <<< "${TARGETS_OF[$1]}"
}

# Main menu on two columns, with an empty line between rows.
print_main() {
    local section lines=() number=0 half width=0 i left
    MENU_SECTIONS=()
    while IFS= read -r section; do
        MENU_SECTIONS+=("${section}")
        (( ${#section} > width )) && width="${#section}"
    done < <(ordered_sections)
    half=$(( (${#MENU_SECTIONS[@]} + 1) / 2 ))
    for (( i = 0; i < half; i++ )); do
        (( i > 0 )) && lines+=("")
        left="$(printf '%s%2d%s  %-*s' "$(fg "${ACCENT}")" $(( i + 1 )) "$(reset)" "${width}" "${MENU_SECTIONS[i]}")"
        if (( i + half < ${#MENU_SECTIONS[@]} )); then
            left+="$(printf '     %s%2d%s  %s' "$(fg "${ACCENT}")" $(( i + half + 1 )) "$(reset)" "${MENU_SECTIONS[i + half]}")"
        fi
        lines+=("${left}")
    done
    box "Menu" "${lines[@]}"
    render "${BOX_LINES[@]}"
}

# Sub-menu with the targets of one section, with an empty line between choices.
print_section() {
    local target lines=() number=0
    MENU_TARGETS=()
    section_targets "$1"
    for target in "${TARGETS[@]}"; do
        number=$(( number + 1 ))
        MENU_TARGETS+=("${target}")
        (( number > 1 )) && lines+=("")
        lines+=("$(item_line "${number}" "${target}" "${DESCRIPTION_OF[${target}]}")")
    done
    box "$1" "${lines[@]}"
    render "${BOX_LINES[@]}"
}

# Full list without numbers, used when there is no terminal.
print_all() {
    local section target
    while IFS= read -r section; do
        printf '\n  %s\n' "${section}"
        section_targets "${section}"
        for target in "${TARGETS[@]}"; do
            printf '    %-20s %s\n' "${target}" "${DESCRIPTION_OF[${target}]}"
        done
    done < <(ordered_sections)
    printf '\n'
}

# Prints the chosen number, "b" to go back or "q" to quit.
ask() {
    local max="$1" level="$2" answer prompt
    if [[ "${level}" == "main" ]]; then
        prompt="Choose a theme (q to quit): "
    else
        prompt="Choose a command (b to go back, q to quit): "
    fi
    while true; do
        read -r -p "  $(fg "${ACCENT}")${prompt}$(reset)" answer < /dev/tty || { printf 'q'; return 0; }
        answer="${answer//[[:space:]]/}"
        case "${answer,,}" in
            q) printf 'q'; return 0 ;;
            "")
                if [[ "${level}" == "main" ]]; then printf 'q'; else printf 'b'; fi
                return 0
                ;;
            b)
                if [[ "${level}" == "sub" ]]; then printf 'b'; return 0; fi
                ;;
        esac
        if [[ "${answer}" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= max )); then
            printf '%s' "${answer}"
            return 0
        fi
        printf '  %sNothing at %s, pick 1 to %d.%s\n' "$(fg "${MUTED}")" "${answer}" "${max}" "$(reset)" >&2
    done
}

run_target() {
    printf '\n  %s> make %s%s\n' "$(fg "${ACCENT}")" "$1" "$(reset)"
    # Ctrl+C stops the target and comes back to the menu.
    "${MAKE}" --no-print-directory "$1" || true
    read -r -p "  $(fg "${MUTED}")Press Enter to go back $(reset)" _ < /dev/tty || true
}

# Clears the screen, ignoring the error when TERM is unset.
clear_screen() {
    clear 2> /dev/null || true
}

# Loops on one section and returns 1 when the user quits.
sub_menu() {
    local choice
    while true; do
        clear_screen
        print_section "$1"
        choice="$(ask "${#MENU_TARGETS[@]}" sub)"
        case "${choice}" in
            q) return 1 ;;
            b) return 0 ;;
        esac
        run_target "${MENU_TARGETS[choice - 1]}"
    done
}

main() {
    (( $# >= 1 )) || usage
    parse_targets "$@"

    if [[ ! -t 0 || ! -t 1 ]]; then
        print_all
        return 0
    fi

    trap 'printf "\n"' INT
    load_infra_info
    local choice
    while true; do
        clear_screen
        print_main
        choice="$(ask "${#MENU_SECTIONS[@]}" main)"
        [[ "${choice}" == "q" ]] && break
        sub_menu "${MENU_SECTIONS[choice - 1]}" || break
    done
}

main "$@"
