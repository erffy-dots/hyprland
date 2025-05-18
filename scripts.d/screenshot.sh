#!/usr/bin/env bash
# Screenshot script for Wayland (Hyprland) environments

# Configuration
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
CLIPBOARD=true  # Set to false to disable clipboard copy
OPEN_AFTER=false  # Set to true to open screenshot after taking it
DEFAULT_MODE="region"  # Default screenshot mode: region, output, window
QUALITY=100  # Image quality (1-100)
DELAY=0  # Delay in seconds before taking screenshot
NOTIFY_TIMEOUT=5000  # Notification timeout in milliseconds
EDITOR="gimp"  # Image editor to use if editing is requested

# Create screenshot directory if it doesn't exist
mkdir -p "$SCREENSHOT_DIR"

# Enable debug mode to help troubleshoot
DEBUG=false

# Debug function
debug() {
    if [ "$DEBUG" = true ]; then
        echo "[DEBUG] $1" >&2
    fi
}

# Log important information
log_info() {
    echo "[INFO] $1" >&2
}

# Show error message
show_error() {
    echo "[ERROR] $1" >&2
    notify-send -t "$NOTIFY_TIMEOUT" "❌ Screenshot Error" "$1"
}

# Help function
show_help() {
    echo "Screenshot script usage:"
    echo "  -m, --mode MODE    Screenshot mode: region, output, window (default: $DEFAULT_MODE)"
    echo "  -c, --clipboard    Copy to clipboard only, don't save file"
    echo "  -s, --save         Save file only, don't copy to clipboard"
    echo "  -e, --edit         Open screenshot in editor after taking"
    echo "  -d, --delay SECS   Delay screenshot by SECS seconds"
    echo "  -q, --quality NUM  JPEG/PNG quality (1-100, default: $QUALITY)"
    echo "  -o, --open         Open screenshot after taking"
    echo "  --debug            Enable debug output"
    echo "  -h, --help         Show this help"
    exit 0
}

# Process arguments
MODE="$DEFAULT_MODE"
SAVE_FILE=true
EDIT_AFTER=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode)
            if [[ "$2" =~ ^(region|output|window)$ ]]; then
                MODE="$2"
                shift 2
            else
                echo "Invalid mode: $2"
                echo "Valid modes: region, output, window"
                exit 1
            fi
            ;;
        -c|--clipboard)
            SAVE_FILE=false
            CLIPBOARD=true
            shift
            ;;
        -s|--save)
            SAVE_FILE=true
            CLIPBOARD=false
            shift
            ;;
        -e|--edit)
            EDIT_AFTER=true
            shift
            ;;
        -o|--open)
            OPEN_AFTER=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        -d|--delay)
            if [[ "$2" =~ ^[0-9]+$ ]]; then
                DELAY="$2"
                shift 2
            else
                echo "Invalid delay: $2. Must be a number."
                exit 1
            fi
            ;;
        -q|--quality)
            if [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -ge 1 ] && [ "$2" -le 100 ]; then
                QUALITY="$2"
                shift 2
            else
                echo "Invalid quality: $2. Must be between 1 and 100."
                exit 1
            fi
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Check for required commands
if ! command -v hyprshot &>/dev/null; then
    show_error "hyprshot is not installed. Please install it first."
    exit 1
fi

# Check hyprshot version
HYPRSHOT_VERSION=$(hyprshot --version 2>&1 || echo "Unknown")
debug "Using hyprshot version: $HYPRSHOT_VERSION"

if [ "$CLIPBOARD" = true ] && ! command -v wl-copy &>/dev/null; then
    log_info "Warning: wl-copy not found. Clipboard functionality will be disabled."
    CLIPBOARD=false
fi

# Print debug information
debug "Screenshot mode: $MODE"
debug "Save file: $SAVE_FILE"
debug "Copy to clipboard: $CLIPBOARD"
debug "Screenshot directory: $SCREENSHOT_DIR"

# Handle delay if specified
if [ "$DELAY" -gt 0 ]; then
    notify-send -t 2000 "Screenshot" "Taking screenshot in ${DELAY} seconds..."
    sleep "$DELAY"
fi

# Generate filename with timestamp
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILENAME="Screenshot-${TIMESTAMP}.png"
FILEPATH="${SCREENSHOT_DIR}/${FILENAME}"

# Take the screenshot
if [ "$SAVE_FILE" = true ]; then
    # Take screenshot and save to file
    # Note: hyprshot might determine its own output path format
    # Let hyprshot handle the file naming
    OUTPUT_RESULT=$(hyprshot -m "$MODE" -o "$SCREENSHOT_DIR" -z --quality "$QUALITY" 2>&1)
    EXIT_CODE=$?
    
    # Get the actual file path from hyprshot output if possible
    if [ $EXIT_CODE -eq 0 ]; then
        # Try to extract the filepath from hyprshot output
        if [[ "$OUTPUT_RESULT" =~ Screenshot\ saved\ to:\ (.*) ]]; then
            FILEPATH="${BASH_REMATCH[1]}"
        fi
        
        # Double check if file exists now
        if [ ! -f "$FILEPATH" ]; then
            # Try finding most recent file in screenshot directory as fallback
            FILEPATH=$(find "$SCREENSHOT_DIR" -type f -name "*.png" -printf "%T@ %p\n" | sort -n | tail -1 | cut -f2- -d" ")
        fi
        
        # Still no file found
        if [ ! -f "$FILEPATH" ]; then
            notify-send -t "$NOTIFY_TIMEOUT" "❌ Screenshot failed" "File was not created."
            exit 1
        fi
        
        # Copy to clipboard if enabled
        CLIP_MSG=""
        if [ "$CLIPBOARD" = true ]; then
            if command -v wl-copy &>/dev/null; then
                debug "Copying to clipboard: $FILEPATH"
                if wl-copy < "$FILEPATH"; then
                    CLIP_MSG=" and copied to clipboard"
                    debug "Clipboard copy successful"
                else
                    CLIP_MSG=" (clipboard copy failed)"
                    debug "Clipboard copy failed"
                fi
            fi
        fi
        
        # Show notification with preview
        debug "Sending notification with filepath: $FILEPATH"
        notify-send -t "$NOTIFY_TIMEOUT" -i "$FILEPATH" "📸 Screenshot saved" "$FILEPATH$CLIP_MSG"
        
        # Open or edit if requested
        if [ "$EDIT_AFTER" = true ] && [ -f "$FILEPATH" ]; then
            if command -v "$EDITOR" &>/dev/null; then
                debug "Opening in editor: $EDITOR $FILEPATH"
                "$EDITOR" "$FILEPATH" &
            else
                notify-send -t "$NOTIFY_TIMEOUT" "⚠️ Warning" "Editor $EDITOR not found. Screenshot not opened for editing."
            fi
        elif [ "$OPEN_AFTER" = true ] && [ -f "$FILEPATH" ]; then
            debug "Opening with xdg-open: $FILEPATH"
            xdg-open "$FILEPATH" &
        fi
    elif [ $EXIT_CODE -eq 130 ]; then
        # User canceled the screenshot (SIGINT)
        debug "User canceled screenshot (SIGINT)"
        notify-send -t "$NOTIFY_TIMEOUT" "Screenshot canceled" "Operation canceled by user"
        exit 0
    else
        show_error "hyprshot exited with code: $EXIT_CODE"
        exit $EXIT_CODE
    fi
else
    # Clipboard-only mode
    debug "Running clipboard-only mode"
    debug "Command: hyprshot -m \"$MODE\" -z --quality \"$QUALITY\" --clipboard-only"
    
    OUTPUT_RESULT=$(hyprshot -m "$MODE" -z --quality "$QUALITY" --clipboard-only 2>&1)
    EXIT_CODE=$?
    
    debug "hyprshot exit code: $EXIT_CODE"
    debug "hyprshot output: $OUTPUT_RESULT"
    
    if [ $EXIT_CODE -eq 0 ]; then
        notify-send -t "$NOTIFY_TIMEOUT" "📋 Screenshot copied" "Screenshot copied to clipboard"
    elif [ $EXIT_CODE -eq 130 ]; then
        # User canceled
        debug "User canceled screenshot (SIGINT)"
        notify-send -t "$NOTIFY_TIMEOUT" "Screenshot canceled" "Operation canceled by user"
        exit 0
    else
        show_error "hyprshot exited with code: $EXIT_CODE"
        exit $EXIT_CODE
    fi
fi

debug "Script completed successfully"
exit 0
