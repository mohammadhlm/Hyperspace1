#!/bin/bash

# Script save path
SCRIPT_PATH="$HOME/Hyperspace.sh"

# Main menu function
function main_menu() {
    while true; do
        clear
        echo "Script developed by the Dadu Community hahaha, Twitter @ferdie_jhovie, free and open-source, do not trust paid versions"
        echo "If you have any issues, contact via Twitter, only one account available"
        echo "================================================================"
        echo "To exit the script, press Ctrl + C on your keyboard"
        echo "Please select an operation to perform:"
        echo "1. Deploy Hyperspace Node"
        echo "2. View Logs"
        echo "3. View Points"
        echo "4. Delete Node (Stop Node)"
        echo "5. Enable Log Monitoring"
        echo "6. Exit Script"
        echo "================================================================"
        read -p "Please enter your choice (1/2/3/4/5/6): " choice

        case $choice in
            1)  deploy_hyperspace_node ;;
            2)  view_logs ;; 
            3)  view_points ;;
            4)  delete_node ;;
            5)  start_log_monitor ;;
            6)  exit_script ;;
            *)  echo "Invalid choice, please try again!"; sleep 2 ;;
        esac
    done
}

# Deploy Hyperspace Node
function deploy_hyperspace_node() {
    # Execute installation command
    echo "Executing installation command: curl https://download.hyper.space/api/install | bash"
    curl https://download.hyper.space/api/install | bash

    # Get the newly added PATH after installation
    NEW_PATH=$(bash -c 'source /root/.bashrc && echo $PATH')
    
    # Update the current shell's PATH
    export PATH="$NEW_PATH"

    # Verify if aios-cli is available
    if ! command -v aios-cli &> /dev/null; then
        echo "aios-cli command not found, retrying..."
        sleep 3
        # Attempt to update PATH again
        export PATH="$PATH:/root/.local/bin"
        if ! command -v aios-cli &> /dev/null; then
            echo "Cannot find aios-cli command, please manually run 'source /root/.bashrc' and try again"
            read -n 1 -s -r -p "Press any key to return to the main menu..."
            return
        fi
    fi

    # Prompt for screen name, default is 'hyper'
    read -p "Please enter the screen name (default: hyper): " screen_name
    screen_name=${screen_name:-hyper}
    echo "Using screen name: $screen_name"

    # Clean up existing 'hyper' screen sessions
    echo "Checking and cleaning existing '$screen_name' screen sessions..."
    screen -ls | grep "$screen_name" &>/dev/null
    if [ $? -eq 0 ]; then
        echo "Found existing '$screen_name' screen session, stopping and deleting..."
        screen -S "$screen_name" -X quit
        sleep 2
    else
        echo "No existing '$screen_name' screen session found."
    fi

    # Create a new screen session
    echo "Creating a screen session named '$screen_name'..."
    screen -S "$screen_name" -dm

    # Run aios-cli start in the screen session
    echo "Running 'aios-cli start' command in screen session '$screen_name'..."
    screen -S "$screen_name" -X stuff "aios-cli start\n"

    # Wait a few seconds to ensure the command executes
    sleep 5

    # Detach from the screen session
    echo "Detaching from screen session '$screen_name'..."
    screen -S "$screen_name" -X detach
    sleep 5
    
    # Ensure environment variables are updated
    echo "Ensuring environment variables are updated..."
    source /root/.bashrc
    sleep 4  # Wait for 4 seconds to ensure environment variables are loaded

    # Print current PATH to ensure aios-cli is included
    echo "Current PATH: $PATH"

    # Prompt user to enter private key and save it as my.pem file
    echo "Please enter your private key (press CTRL+D to finish):"
    cat > my.pem

    # Use the my.pem file to run the import-keys command
    echo "Running import-keys command using my.pem file..."
    
    # Execute import-keys command
    aios-cli hive import-keys ./my.pem
    sleep 5

    # Define model variable
    model="hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf"

    # Add model and retry if necessary
    echo "Adding model using 'aios-cli models add' command..."
    while true; do
        if aios-cli models add "$model"; then
            echo "Model added successfully and downloaded!"
            break
        else
            echo "Error adding model, retrying..."
            sleep 3
        fi
    done

    # Log in and select tier
    echo "Logging in and selecting tier..."

    # Log in to Hive
    aios-cli hive login

    # Prompt user to select tier
    echo "Please select a tier (1-5):"
    select tier in 1 2 3 4 5; do
        case $tier in
            1|2|3|4|5)
                echo "You selected tier $tier"
                aios-cli hive select-tier $tier
                break
                ;;
            *)
                echo "Invalid selection, please enter a number between 1 and 5."
                ;;
        esac
    done

    # Connect to Hive
    aios-cli hive connect
    sleep 5

    # Stop the aios-cli process
    echo "Stopping 'aios-cli start' process using 'aios-cli kill'..."
    aios-cli kill

    # Run aios-cli start in the screen session and redirect output to log file
    echo "Running 'aios-cli start --connect' in screen session '$screen_name' and redirecting output to '/root/aios-cli.log'..."
    screen -S "$screen_name" -X stuff "aios-cli start --connect >> /root/aios-cli.log 2>&1\n"

    echo "Hyperspace node deployment completed, 'aios-cli start --connect' is running in the screen session, and the system has been detached."

    # Prompt user to press any key to return to the main menu
    read -n 1 -s -r -p "Press any key to return to the main menu..."
    main_menu
}

# View Points
function view_points() {
    echo "Viewing points..."
    source /root/.bashrc
    aios-cli hive points
    sleep 2
}

# Delete Node (Stop Node)
function delete_node() {
    echo "Stopping node using 'aios-cli kill'..."

    # Execute aios-cli kill to stop the node
    aios-cli kill
    sleep 2
    
    echo "'aios-cli kill' executed successfully, node has been stopped."

    # Prompt user to press any key to return to the main menu
    read -n 1 -s -r -p "Press any key to return to the main menu..."
    main_menu
}

# Enable Log Monitoring
function start_log_monitor() {
    echo "Starting log monitoring..."

    # Create monitoring script file
    cat > /root/monitor.sh << 'EOL'
#!/bin/bash
LOG_FILE="/root/aios-cli.log"
SCREEN_NAME="hyper"
LAST_RESTART=$(date +%s)
MIN_RESTART_INTERVAL=300

while true; do
    current_time=$(date +%s)
    
    # Trigger restart on the following conditions
    if (tail -n 4 "$LOG_FILE" | grep -q "Last pong received.*Sending reconnect signal" || \
        tail -n 4 "$LOG_FILE" | grep -q "Failed to authenticate" || \
        tail -n 4 "$LOG_FILE" | grep -q "Failed to connect to Hive" || \
        tail -n 4 "$LOG_FILE" | grep -q "Another instance is already running" || \
        tail -n 4 "$LOG_FILE" | grep -q "\"message\": \"Internal server error\"" || \
        tail -n 4 "$LOG_FILE" | grep -q "thread 'main' panicked at aios-cli/src/main.rs:181:39: called \`Option::unwrap()\` on a \`None\` value") && \
       [ $((current_time - LAST_RESTART)) -gt $MIN_RESTART_INTERVAL ]; then
        echo "$(date): Detected connection issues, authentication failure, failed to connect to Hive, instance already running, internal server error, or 'Option::unwrap()' error, restarting service..." >> /root/monitor.log
        
        # Send Ctrl+C first
        screen -S "$SCREEN_NAME" -X stuff $'\003'
        sleep 5
        
        # Execute aios-cli kill
        screen -S "$SCREEN_NAME" -X stuff "aios-cli kill\n"
        sleep 5
        
        echo "$(date): Cleaning old logs..." > "$LOG_FILE"
        
        # Restart the service
        screen -S "$SCREEN_NAME" -X stuff "aios-cli start --connect >> /root/aios-cli.log 2>&1\n"
        
        LAST_RESTART=$current_time
        echo "$(date): Service restarted" >> /root/monitor.log
    fi
    sleep 30
done
EOL

    # Add execute permissions
    chmod +x /root/monitor.sh

    # Start monitoring script in the background
    nohup /root/monitor.sh > /root/monitor.log 2>&1 &

    echo "Log monitoring started and running in the background."
    echo "You can check the monitoring status by viewing /root/monitor.log"
    sleep 2

    # Prompt user to press any key to return to the main menu
    read -n 1 -s -r -p "Press any key to return to the main menu..."
    main_menu
}

# View Logs
function view_logs() {
    echo "Viewing logs..."
    LOG_FILE="/root/aios-cli.log"   # Log file path

    if [ -f "$LOG_FILE" ]; then
        echo "Displaying the last 200 lines of the log:"
        tail -n 200 "$LOG_FILE"   # Display the last 200 lines of the log
    else
        echo "Log file does not exist: $LOG_FILE"
    fi

    # Prompt user to press any key to return to the main menu
    read -n 1 -s -r -p "Press any key to return to the main menu..."
    main_menu
}

# Exit Script
function exit_script() {
    echo "Exiting script..."
    exit 0
}

# Call the main menu function
main_menu
