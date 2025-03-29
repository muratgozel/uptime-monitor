#!/usr/bin/env bash

debounce() {
    local timeout=$1
    shift
    local command="$*"

    # Create a portable hash using a combination of built-in bash methods
    local hash=$(printf "%s" "$command" | awk '{sum=0; for(i=1;i<=length;i++) sum+=substr($0,i,1)} END{print sum}')
    local lock_file="/tmp/debounce_${hash}.lock"

    # Check if lock file exists and is recent
    if [[ -f "$lock_file" ]]; then
        local last_run=$(stat -c %Y "$lock_file" 2>/dev/null || stat -f %m "$lock_file")
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_run))

        # If within timeout period, exit
        if [[ $time_diff -lt $timeout ]]; then
            return 1
        fi
    fi

    # Execute the command
    "$@"

    # Create/update lock file
    touch "$lock_file"
}

notify() {
    local url="$1"
    local status_code="$2"

    # Debounce notifications for 1 hour (3600 seconds) per URL
    debounce 3600 _notify_helper "$url" "$status_code"
}

# Send Email via Postmark
send_postmark_email() {
    local url="$1"
    local status_code="$2"

    # Ensure required variables are set
    if [[ -z "$POSTMARK_API_TOKEN" ]] || [[ -z "$NOTIFICATION_EMAIL_RECIPIENTS" ]]; then
        echo "Postmark API token or recipients not configured" >&2
        return 1
    fi

    local payload=$(jq -n \
        --arg from "$POSTMARK_SENDER" \
        --arg to "$NOTIFICATION_EMAIL_RECIPIENTS" \
        --arg subject "Service Down Alert" \
        --arg textBody "URL $url is DOWN. Status code: $status_code" \
        '{
            "From": $from,
            "To": $to,
            "Subject": $subject,
            "TextBody": $textBody,
            "MessageStream": "outbound"
        }')

    curl -X POST "https://api.postmarkapp.com/email" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "X-Postmark-Server-Token: $POSTMARK_API_TOKEN" \
        -d "$payload"
}

_notify_helper() {
    local url="$1"
    local status_code="$2"

    # Example notification methods - you can customize these
    echo "ALERT: $url is DOWN! Status code: $status_code"

    # Send email
    send_postmark_email "$url" "$status_code"

    # Log to a file
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $url is DOWN. Status: $status_code" >> /tmp/url_health_check.log
}

check_urls() {
    # Check if URLs file exists and is readable
    if [[ ! -f "$URLS_FILE" ]]; then
        echo "ERROR: URLs file not found at $URLS_FILE" >&2
        return 1
    fi

    # Read URLs from file, ignoring comments and empty lines
    local urls=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and lines starting with #
        [[ -z "$line" || "$line" =~ ^\s*# ]] && continue

        # Trim whitespace
        line=$(echo "$line" | xargs)

        # Validate URL format (basic check)
        if [[ "$line" =~ ^https?:// ]]; then
            urls+=("$line")
        else
            echo "WARNING: Invalid URL format - $line" >&2
        fi
    done < "$URLS_FILE"

    # If no valid URLs found, exit
    if [[ ${#urls[@]} -eq 0 ]]; then
        echo "ERROR: No valid URLs found in $URLS_FILE" >&2
        return 1
    fi

    local timeout=10  # Timeout in seconds
    local max_retries=3

    for url in "${urls[@]}"; do
        local attempts=0
        local is_up=false

        while [[ $attempts -lt $max_retries ]]; do
            # Use curl with various checks
            response=$(curl -o /dev/null \
                      -s \
                      -w "%{http_code}" \
                      -m $timeout \
                      --connect-timeout $timeout \
                      "$url")

            # Check if response starts with 2 or 3 (successful or redirection codes)
            if [[ $response =~ ^[23][0-9]{2}$ ]]; then
                is_up=true
                break
            fi

            ((attempts++))
            sleep 2  # Wait between retries
        done

        # If URL is down after all attempts, notify
        if [[ $is_up == false ]]; then
            notify "$url" "$response"
        fi
    done
}

main() {
    check_urls
}

[[ "$0" == "$BASH_SOURCE" ]] && main
