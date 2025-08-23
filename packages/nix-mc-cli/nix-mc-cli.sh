#!/usr/bin/env bash

# nix-mc-cli - Minecraft Server CLI Tool
# Manages Minecraft servers via tmux sessions

set -euo pipefail

readonly SCRIPT_NAME="nix-mc-cli"
readonly SOCKET_DIR="/run/minecraft"
readonly VERSION="1.0.0"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

# Check if socket directory exists and is accessible
check_socket_dir() {
    if [[ ! -d "$SOCKET_DIR" ]]; then
        log_error "Socket directory $SOCKET_DIR does not exist"
        log_error "Make sure nix-mc NixOS module is properly configured"
        exit 1
    fi

    if [[ ! -r "$SOCKET_DIR" ]]; then
        log_error "Cannot access $SOCKET_DIR"
        log_error "Make sure you're in the 'minecraft' group"
        exit 1
    fi
}

# Get list of available servers from socket files
get_servers() {
    find "$SOCKET_DIR" -name "*.sock" -type S 2>/dev/null | \
        sed "s|$SOCKET_DIR/||g; s|\.sock$||g" | \
        sort
}

# Check if server exists
server_exists() {
    local server="$1"
    [[ -S "$SOCKET_DIR/$server.sock" ]]
}

# Check if tmux session is active
session_active() {
    local server="$1"
    tmux -S "$SOCKET_DIR/$server.sock" has-session -t "mc-$server" 2>/dev/null
}

# Get player count from server (if possible)
get_player_count() {
    local server="$1"
    if session_active "$server"; then
        # This is a simplified approach - in reality, parsing logs would be complex
        echo "?"
    else
        echo "-"
    fi
}

# Command: list - Show all servers with status
cmd_list() {
    check_socket_dir
    
    local servers
    servers=$(get_servers)
    
    if [[ -z "$servers" ]]; then
        log_warn "No Minecraft servers found"
        echo "Make sure servers are running and accessible"
        return 0
    fi

    echo "Available Minecraft servers:"
    echo
    printf "%-12s %-8s %s\n" "NAME" "STATUS" "INFO"
    printf "%-12s %-8s %s\n" "----" "------" "----"
    
    while IFS= read -r server; do
        if session_active "$server"; then
            local status="${GREEN}●${NC} Running"
            local players=$(get_player_count "$server")
            local info="($players players)"
        else
            local status="${RED}○${NC} Stopped"
            local info=""
        fi
        printf "%-12s %-16s %s\n" "$server" "$status" "$info"
    done <<< "$servers"
}

# Command: status - Show detailed server status
cmd_status() {
    local server="$1"
    
    if [[ -z "$server" ]]; then
        log_error "Server name required"
        echo "Usage: $SCRIPT_NAME status <server>"
        return 1
    fi
    
    check_socket_dir
    
    if ! server_exists "$server"; then
        log_error "Server '$server' not found"
        return 1
    fi
    
    echo "Server: mc-$server"
    echo "Socket: $SOCKET_DIR/$server.sock"
    
    if session_active "$server"; then
        echo "Status: ${GREEN}Running${NC}"
        echo "Session: Active"
        
        # Try to get additional info
        local players=$(get_player_count "$server")
        echo "Players: $players online"
    else
        echo "Status: ${RED}Stopped${NC}"
        echo "Session: Inactive"
    fi
}

# Command: send - Send command to server
cmd_send() {
    local server="$1"
    shift || {
        log_error "Server name and command required"
        echo "Usage: $SCRIPT_NAME send <server> <command>"
        return 1
    }
    
    local command="$*"
    
    if [[ -z "$command" ]]; then
        log_error "Command required"
        echo "Usage: $SCRIPT_NAME send <server> <command>"
        return 1
    fi
    
    check_socket_dir
    
    if ! server_exists "$server"; then
        log_error "Server '$server' not found"
        return 1
    fi
    
    if ! session_active "$server"; then
        log_error "Server '$server' is not running"
        return 1
    fi
    
    log_info "Sending command to mc-$server: $command"
    
    if tmux -S "$SOCKET_DIR/$server.sock" send-keys -t "mc-$server" "$command" Enter; then
        log_success "Command sent successfully"
    else
        log_error "Failed to send command"
        return 1
    fi
}

# Command: tail - Show recent logs
cmd_tail() {
    local server="$1"
    local lines="${2:-20}"
    
    if [[ -z "$server" ]]; then
        log_error "Server name required"
        echo "Usage: $SCRIPT_NAME tail <server> [lines]"
        return 1
    fi
    
    # Validate lines parameter
    if ! [[ "$lines" =~ ^[0-9]+$ ]]; then
        log_error "Lines parameter must be a number"
        return 1
    fi
    
    check_socket_dir
    
    if ! server_exists "$server"; then
        log_error "Server '$server' not found"
        return 1
    fi
    
    if ! session_active "$server"; then
        log_error "Server '$server' is not running"
        return 1
    fi
    
    log_info "Showing last $lines lines from mc-$server:"
    echo
    
    if tmux -S "$SOCKET_DIR/$server.sock" capture-pane -t "mc-$server" -p -S "-$lines"; then
        return 0
    else
        log_error "Failed to capture server output"
        return 1
    fi
}

# Command: connect - Connect to interactive session
cmd_connect() {
    local server="$1"
    
    if [[ -z "$server" ]]; then
        log_error "Server name required"
        echo "Usage: $SCRIPT_NAME connect <server>"
        return 1
    fi
    
    check_socket_dir
    
    if ! server_exists "$server"; then
        log_error "Server '$server' not found"
        return 1
    fi
    
    if ! session_active "$server"; then
        log_error "Server '$server' is not running"
        return 1
    fi
    
    log_info "Connecting to mc-$server session..."
    log_info "Press Ctrl+B then D to detach from session"
    echo
    
    exec tmux -S "$SOCKET_DIR/$server.sock" attach-session -t "mc-$server"
}

# Show help message
show_help() {
    cat << EOF
$SCRIPT_NAME v$VERSION - Minecraft Server CLI Tool

USAGE:
    $SCRIPT_NAME <command> [args...]

COMMANDS:
    list                    List all servers with status
    status <server>         Show detailed server status
    send <server> <command> Send command to server
    tail <server> [lines]   Show recent logs (default: 20 lines)
    connect <server>        Connect to interactive session

EXAMPLES:
    $SCRIPT_NAME list
    $SCRIPT_NAME status survival
    $SCRIPT_NAME send survival say Hello players!
    $SCRIPT_NAME tail survival 50
    $SCRIPT_NAME connect survival

For more information, see the README.md file.
EOF
}

# Main command dispatcher
main() {
    if [[ $# -eq 0 ]]; then
        show_help
        return 1
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        list)
            cmd_list "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        send)
            cmd_send "$@"
            ;;
        tail)
            cmd_tail "$@"
            ;;
        connect)
            cmd_connect "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        --version|-v)
            echo "$SCRIPT_NAME v$VERSION"
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            show_help
            return 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
