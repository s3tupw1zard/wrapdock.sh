#!/bin/bash

# Path to configuration file
WRAPDOCK_HOME="$HOME/.wrapdock"

# Function to display help information
show_help() {
    local command="$1"
    case "$command" in
        manage)
            cat << EOF
Manage Containers:

This command allows you to manage Docker containers.
Available options:
1. install - Install containers
2. update - Update containers
3. uninstall - Uninstall containers
4. restart - Restart containers
5. stop - Stop containers
6. recreate - Recreate containers

Usage: $0 manage [option]
EOF
            ;;
        backup)
            cat << EOF
Backup Containers:

This command allows you to backup Docker containers.
Available options:
1. backup - Backup containers
2. view - View backups
3. restore - Restore backups
4. delete - Delete backups

Usage: $0 backup [option]
EOF
            ;;
        settings)
            cat << EOF
Settings:

This command allows you to configure settings related to Docker and other components.
Available options:
1. show-disk-usage - Show Docker disk usage
2. traefik-setup - Traefik setup and management
3. authelia - Security with Authelia

Usage: $0 settings [option]
EOF
            ;;
        cleanup)
            cat << EOF
Cleanup:

This command allows you to perform cleanup operations.
Available options:
1. prune - Remove unused Docker images

Usage: $0 cleanup [option]
EOF
            ;;
        update)
            cat << EOF
Update WrapDock:

This command allows you to update the WrapDock script itself.

Usage: $0 update
EOF
            ;;
        uninstall)
            cat << EOF
Uninstall WrapDock:

This command allows you to uninstall the WrapDock script.

Usage: $0 uninstall
EOF
            ;;
        *)
            cat << EOF
Invalid command: $command

Usage: $0 [command] [option]
EOF
            ;;
    esac
}

# Function for the initial configuration
first_run_setup() {
    sudo apt install whiptail -y
    whiptail --title "Initial Configuration" --msgbox \
    "First time run. Please configure the environment variables on the next screens." 10 70
    
    # Entering the environment variables
    username=$(whiptail --inputbox "Please type in a username under which this script should always be run:" 10 70 2>&1 >/dev/tty)
    wrapdock_working_directory=$(whiptail --inputbox "Please type in your working directory for WebDock: example: /srv/$username/wrapdock" 10 70 2>&1 >/dev/tty)
    backup_folder=$(whiptail --inputbox "Please type in your preferred sub-folder for backups:" 10 70 2>&1 >/dev/tty)
    storage_folder=$(whiptail --inputbox "Please type in a subfolder, where downloads and media should be placed:" 10 70 2>&1 >/dev/tty)

    default_data_folder="$wrapdock_working_directory/data"
    whiptail --yesno "The default path for data is $default_data_folder. Would you like to customize this?" 10 70
    response=$?
    if [ $response -eq 0 ]; then
        data_folder=$(whiptail --inputbox "Please type in your preferred data folder location:" 10 70 2>&1 >/dev/tty)
    else
        data_folder=$default_data_folder
    fi

    # Creating folder to store the .wrapdock.env inside.
    mkdir -p $WRAPDOCK_HOME

    # Saving the environment variables
    cat <<EOF > "$WRAPDOCK_HOME/wrapdock.env"
USERNAME=$username
WEBDOCK_FOLDER=$wrapdock_working_directory
BACKUP_FOLDER=$backup_folder
STORAGE_FOLDER=$storage_folder
DATA_FOLDER=$data_folder
EOF

    whiptail --title "Configuration Saved" --msgbox \
    "Saved configuration. Continuing automatically in 10 seconds." 10 70

    # Installation and setup
    install_dependencies
    setup_folders
    set_script_user
}

# Dependency installation function
install_dependencies() {
    if [ -f "/etc/apt/sources.list.d/docker.list" ]; then
        whiptail --msgbox "Docker repository already installed, installing only packages without adding repository..." 10 70
        sudo apt-get update
        sudo apt-get install -y docker docker-compose-plugin docker-buildx-plugin
        whiptail --msgbox "Installed dependencies." 10 70
    else
        whiptail --msgbox "Docker repository not found, adding it including Docker packages using get.docker.com" 10 70
        sudo apt install curl -y
        curl -sSL https://get.docker.com/ | CHANNEL=stable bash
        whiptail --msgbox "Installed dependencies." 10 70
    fi
}

# Function for setting up the folder structure
setup_folders() {
    whiptail --msgbox "Setting up the folder structure..." 10 70
    mkdir -p "$wrapdock_working_directory" "$wrapdock_working_directory/$backup_folder" "$wrapdock_working_directory/$storage_folder/downloads" "$wrapdock_working_directory/$storage_folder/media" "$wrapdock_working_directory/$data_folder"
    whiptail --msgbox "Folder structure set up." 10 70
}

# Function to specify the user with which the script should always be executed
set_script_user() {
    whiptail --msgbox "Setting the user for this script..." 10 70
    sudo chown -R "$username":"$username" "$wrapdock_working_directory" "$HOME/.wrapdock"
    whiptail --msgbox "User set." 10 70
}

install_container_env_list() {
    # TODO: Update to reflect the actual .wrapdock folder the user chose
    template_url="https://raw.githubusercontent.com/s3tupw1zard/wrapdock.sh/main/env/containers.env.template"
    local_file="$HOME/.wrapdock/containers.env"

    # Download the template file from the URL and save it into the .wrapdock folder
    curl -s "$template_url" > "$local_file"
    }

update_container_env_list() {
    # TODO: Update to reflect the actual .wrapdock folder the user chose
    template_url="https://raw.githubusercontent.com/s3tupw1zard/wrapdock.sh/main/env/containers.env.template"
    local_file="$HOME/.wrapdock/containers.env"
    output_file="/tmp/containers.env.merged"

    # Download the template file from the URL and save it in a temporary folder
    temp_template_file=$(mktemp)
    curl -s "$template_url" > "$temp_template_file"

    # Copy the local version to the output file
    cp "$local_file" "$output_file"

    # Loop over each line in the template file
    while IFS= read -r template_line; do
        # Check if the line already exists in the local file
        if ! grep -qF "$template_line" "$local_file"; then
            # Add the line to the output file if it does not exist
            echo "$template_line" >> "$output_file"
        fi
    done < "$temp_template_file"

    # Delete the temporary template file
    rm "$temp_template_file"

    echo "Merging completed. Result in $output_file"

    # Moving $output_file to $local_file
    mv $local_file $HOME/.wrapdock/containers.env.bak-$(date +"%Y-%m-%d")
    mv $output_file $local_file
    rm $output_file
    echo "$local_file updated."
    }

# Manage Containers menu
manage_containers_menu() {
    if [ "$1" = "help" ]; then
        show_help "manage"
        exit 0
    fi

    choice=$(whiptail --title "Manage Containers" --menu "Choose an option:" 15 70 6 \
        "1" "Install containers" \
        "2" "Update containers" \
        "3" "Uninstall containers" \
        "4" "Restart containers" \
        "5" "Stop containers" \
        "6" "Recreate containers" \
        3>&1 1>&2 2>&3)
    clear
    case $choice in
        1) install_containers_menu;;
        2) update_containers_menu;;
        3) uninstall_containers_menu;;
        4) restart_containers_menu;;
        5) stop_containers_menu;;
        6) recreate_containers_menu;;
        *) exit 0;;
    esac
}

# Install containers submenu
install_containers_menu() {
    if [ "$1" = "help" ]; then
        show_help "manage"
        exit 0
    fi

    choice=$(whiptail --title "Install Containers" --menu "Choose an option:" 15 70 3 \
        "1" "All" \
        "2" "By Category" \
        "3" "Back to previous menu" \
        3>&1 1>&2 2>&3)
    clear
    case $choice in
        1) install_all_containers;;
        2) install_containers_by_category;;
        3) manage_containers_menu;;
        *) exit 0;;
    esac
}

# Update containers submenu
update_containers_menu() {
    if [ "$1" = "help" ]; then
        show_help "manage"
        exit 0
    fi

    choice=$(whiptail --title "Update Containers" --menu "Choose an option:" 15 70 3 \
        "1" "All" \
        "2" "By Category" \
        "3" "Back to previous menu" \
        3>&1 1>&2 2>&3)
    clear
    case $choice in
        1) update_all_containers;;
        2) update_containers_by_category;;
        3) manage_containers_menu;;
        *) exit 0;;
    esac
}

# Uninstall containers submenu
uninstall_containers_menu() {
    if [ "$1" = "help" ]; then
        show_help "manage"
        exit 0
    fi

    choice=$(whiptail --title "Uninstall Containers" --menu "Choose an option:" 15 70 3 \
        "1" "All" \
        "2" "By Category" \
        "3" "Back to previous menu" \
        3>&1 1>&2 2>&3)
    clear
    case $choice in
        1) uninstall_all_containers;;
        2) uninstall_containers_by_category;;
        3) manage_containers_menu;;
        *) exit 0;;
    esac
}

# Restart containers submenu
restart_containers_menu() {
    if [ "$1" = "help" ]; then
        show_help "manage"
        exit 0
    fi

    choice=$(whiptail --title "Restart Containers" --menu "Choose an option:" 15 70 3 \
        "1" "All" \
        "2" "By Category" \
        "3" "Back to previous menu" \
        3>&1 1>&2 2>&3)
    clear
    case $choice in
        1) restart_all_containers;;
        2) restart_containers_by_category;;
        3) manage_containers_menu;;
        *) exit 0;;
    esac
}

# Stop containers submenu
stop_containers_menu() {
    if [ "$1" = "help" ]; then
        show_help "manage"
        exit 0
    fi

    choice=$(whiptail --title "Stop Containers" --menu "Choose an option:" 15 70 3 \
        "1" "All" \
        "2" "By Category" \
        "3" "Back to previous menu" \
        3>&1 1>&2 2>&3)
    clear
    case $choice in
        1) stop_all_containers;;
        2) stop_containers_by_category;;
        3) manage_containers_menu;;
        *) exit 0;;
    esac
}

# Recreate containers submenu
recreate_containers_menu() {
    if [ "$1" = "help" ]; then
        show_help "manage"
        exit 0
    fi

    choice=$(whiptail --title "Recreate Containers" --menu "Choose an option:" 15 70 3 \
        "1" "All" \
        "2" "By Category" \
        "3" "Back to previous menu" \
        3>&1 1>&2 2>&3)
    clear
    case $choice in
        1) recreate_all_containers;;
        2) recreate_containers_by_category;;
        3) manage_containers_menu;;
        *) exit 0;;
    esac
}

# Backup containers submenu
backup_containers_menu() {
    if [ "$1" = "help" ]; then
        show_help "backup"
        exit 0
    fi

    choice=$(whiptail --title "Backup Containers" --menu "Choose an option:" 15 70 4 \
        "1" "Backup" \
        "2" "View backups" \
        "3" "Restore backups" \
        "4" "Delete backups" \
        3>&1 1>&2 2>&3)
    clear
    case $choice in
        1) backup;;
        2) view_backups;;
        3) restore_backups;;
        4) delete_backups;;
        *) exit 0;;
    esac
}

# Settings menu
settings_menu() {
    if [ "$1" = "help" ]; then
        show_help "settings"
        exit 0
    fi

    choice=$(whiptail --title "Settings" --menu "Choose an option:" 15 70 4 \
        "1" "Show Docker disk usage" \
        "2" "Traefik setup and management" \
        "3" "Security with Authelia" \
        "4" "Back to main menu" \
        3>&1 1>&2 2>&3)
    clear
    case $choice in
        1) show_docker_disk_usage;;
        2) traefik_setup;;
        3) authelia_security;;
        4) return;;
        *) exit 0;;
    esac
}

# Cleanup menu
cleanup_menu() {
    if [ "$1" = "help" ]; then
        show_help "cleanup"
        exit 0
    fi

    choice=$(whiptail --title "Cleanup" --menu "Choose an option:" 15 70 2 \
        "1" "Remove unused Docker images" \
        "2" "Back to main menu" \
        3>&1 1>&2 2>&3)
    clear
    case $choice in
        1) prune_unused_images;;
        2) return;;
        *) exit 0;;
    esac
}

# Update WrapDock script
update_script() {
    if [ "$1" = "help" ]; then
        show_help "update"
        exit 0
    fi

    whiptail --title "Update WrapDock" --msgbox \
    "Updating WrapDock script..." 10 70
    # Add update script logic here
    whiptail --msgbox "WrapDock script updated." 10 70
}

# Uninstall WrapDock script
uninstall_script() {
    if [ "$1" = "help" ]; then
        show_help "uninstall"
        exit 0
    fi

    whiptail --yesno "Are you sure you want to uninstall WrapDock?" 10 70
    response=$?
    if [ $response -eq 0 ]; then
        whiptail --msgbox "Uninstalling WrapDock script..." 10 70
        # Add uninstall script logic here
        whiptail --msgbox "WrapDock script uninstalled." 10 70
    else
        whiptail --msgbox "Uninstallation cancelled." 10 70
    fi
}

# Check if help option is provided
if [ "$1" = "help" ]; then
    show_help
    exit 0
fi

# Main menu entry point
main_menu() {
    if [ "$1" = "help" ]; then
        show_help
        exit 0
    fi

    while true; do
        choice=$(whiptail --title "Main Menu" --menu "Choose an option:" 15 70 7 \
            "1" "Manage containers" \
            "2" "Backup containers" \
            "3" "Settings" \
            "4" "Cleanup" \
            "5" "Update WrapDock" \
            "6" "Uninstall WrapDock" \
            "7" "Quit" \
            3>&1 1>&2 2>&3)
        clear
        case $choice in
            1) manage_containers_menu;;
            2) backup_containers_menu;;
            3) settings_menu;;
            4) cleanup_menu;;
            5) update_script;;
            6) uninstall_script;;
            7) break;;
            *) exit 0;;
        esac
    done
}

# Check if the configuration file exists
if [ ! -f "$WRAPDOCK_HOME/wrapdock.env" ]; then
    first_run_setup
else
    source "$WRAPDOCK_HOME/wrapdock.env"
fi

# Main menu entry point
if [ "$1" = "menu" ]; then
    main_menu "$@"
    exit 0
fi

# Display help if no arguments provided
show_menu_help() {
    cat << EOF
Command Help:
$0 manage [option]   -   Install, update, uninstall, restart, stop or recreate containers
$0 backup [option]   -   Backup containers, view them, restore or delete backups
$0 settings [option] -   Show disk usage, set up Traefik or authelia
$0 cleanup [option]  -   Cleanup all unused docker images
$0 update            -   Update WrapDock to the latest version
$0 uninstall         -   Uninstall WrapDock
EOF
}


# Display help if no arguments provided
if [ $# -eq 0 ]; then
    >&2 echo "No arguments provided, showing help:"
    >&2 echo "---------------------------------------------------------------------------------------------------"
    >&2 echo " "
    show_menu_help
    >&2 echo "---------------------------------------------------------------------------------------------------"
    exit 1
fi