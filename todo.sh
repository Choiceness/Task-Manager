#!/bin/bash

# Text Format part

set_style() {
    local style="$1"
    local color="$2"

    case "$style" in
        "base") tput sgr0 ;;
        "bold") tput bold ;;
        "sous") tput smul ;;
        "blink") tput blink ;;
        "blinkbold"|"boldblink") tput blink; tput bold ;;
        "boldsous"|"sousbold") tput smul; tput bold;;
        *) return;;
    esac

    case "$color" in
        "black") tput setaf 0 ;;
        "red") tput setaf 1 ;;
        "green") tput setaf 2 ;;
        "yellow") tput setaf 3 ;;
        "blue") tput setaf 4 ;;
        "magenta") tput setaf 5 ;;
        "cyan") tput setaf 6 ;;
        "white") tput setaf 7 ;;
        *) return ;;
    esac
}

# If the file doesn't exist

if [ ! -e "ToDo.csv" ]; then
    echo "ID,Title,Description,Location,Due_Date,Completion" > ToDo.csv
fi

# Function to check the due date (Used in Create and Update)

Date_format () {
    local date="$1"
    
    if date -d "$date" +"%Y-%m-%d %H:%M" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

Valid_Date () {
    local date="$1"

    # Check the date format

    if ! Date_format "$date"; then
        return 1
    fi
    
    # Check if the current date and compare it with the due date

    if [ "$(date -d "$date" +%s)" -lt "$(date +%s)" ]; then
        return 1
    fi

    # Check if the date is valid (In the calendar)

    if ! date -d "$date" >/dev/null 2>&1; then
        return 1
    fi

    # If everything is alright
    
    return 0
}

# Function to create a task

Create () {
    
    # Title part (required)
    
    while true; do    
        set_style "bold" "blue"; echo "Task Title : " ; set_style "base"  
        read -r Title
        
        if [ ! -n "$Title" ]; then
            set_style "bold" "red"; echo "The title is required !" ; set_style "base"
        else
            break
        fi
    done

    # In case the Title is already in the file
    
    number=$(grep -o -E ",$Title[0-9]*," ToDo.csv | wc -l)
    if [ ! "$number" -eq 0 ]; then        
        set_style "sous" "red"; echo -e "$Title is already mentionned we will create a task named $Title$((number+1))" ; set_style "base"
        Title="$Title$((number+1))"
    fi
    
    # Description part (Optional)

    set_style "bold" "blue"; echo "Task Description :" ; set_style "base"
    read -r Description

    # Location part (Optional)

    set_style "bold" "blue" ; echo "Task Location : (If you want the current city you're actually in, press ctrl+A)" ; set_style "base"
    read -n1 -s -r resp

    if [ "$resp" == $'\x01' ]; then
        information=$(curl -s ipinfo.io)
        if [ $? -eq 0 ]; then
            Location=$(echo "$information" | grep -o '"city": "[^"]*"' | cut -d'"' -f4)
            echo -e "\nYour current location will be added ! ($Location)"
        else
            echo -e "\nYou have to retrieve your location manually, check your wifi"
        fi
    else
        set_style "bold" "blue"; echo "Task Location : " ; set_style "base"
        read -r Location
    fi

    # Due Date and Time (required)

    while true; do
        set_style "bold" "blue"; echo "Due Time : (Format YYYY-MM-DD HH:MM)" ; set_style "base"
        read -r Due_Date
        
        if Valid_Date "$Due_Date"; then
            break
        fi

        set_style "bold" "red"; echo -e "The date is not correct !\n" ; set_style "base"
    done

    # Completion Marker (Should be not completed if it's a new task)
    
    mark="Not completed"

    # Creating the new task

    nbr_line=$(wc -l < ToDo.csv)

    if [ $nbr_line -eq 1 ]; then
        echo "1,$Title,$Description,$Location,$Due_Date,$mark" >> ToDo.csv
    else
        last_id=$(tail -1 ToDo.csv | cut -d',' -f1)
        new_id=$(($last_id + 1))
        echo "$new_id,$Title,$Description,$Location,$Due_Date,$mark" >> ToDo.csv
    fi

}

# Function to update a task

Update() {

    # You can choose between two option to update his task (ID/Title)

    while true; do

        set_style "bold" "blue"; echo "How would you like to update the task ? (Title/ID)"; set_style "base"
        read -r method

        # Finding the task information

        case $method in 
            "Title"|"TITLE"|"title") # Finding the line with the title
                set_style "bold" "blue"; echo "Enter the title of the task you want to update : "; set_style "base"
                read -r Title
                
                info=$(grep -i -m 1 -E "^[0-9]+,$Title" ToDo.csv)

                if [ -z "$info" ]; then
                    set_style "bold" "red"; echo "The task cannot be found !!" ; set_style "base"
                else
                    break
                fi
                ;;
            "ID"|"id"|"Id") # Finding the line with the id
                set_style "bold" "blue"; echo "Enter the ID of the task you want to update : "; set_style "base"
                read -r ID
                
                info=$(grep "^$ID," ToDo.csv)
                
                if [ -z "$info" ]; then
                    set_style "bold" "red"; echo "The task cannot be found !!"; set_style "base"
                else
                    break
                fi
                ;;
            *) # Not one of the method
                set_style "bold" "red"; echo "Invalid update method !!"; set_style "base"
                ;;
        esac
    done

    # Extractoing the task information
    
    task_id=$(echo "$info" | cut -d ',' -f1)
    task_title=$(echo "$info" | cut  -d ',' -f2)
    task_description=$(echo "$info" | cut  -d ',' -f3)
    task_location=$(echo "$info" | cut  -d ',' -f4)
    task_due_time=$(echo "$info" | cut  -d ',' -f5)
    task_completion=$(echo "$info" | cut  -d ',' -f6)

    # Prompt the user about the thing he want to update
    
    set_style "bold" "blue"; echo "Do you want to update the task information or just the completion mark ? (All/Completion) "; set_style "base"
    read -r update_type

    # Update task information based on user choice
    
    case $update_type in
        "All"|"all"|"ALL") # If the user choose to update all the task information
            
            set_style "boldblink" "green"; echo "Updating Task Information"; set_style "base"
            set_style "boldblink" "green"; echo "Leave blank to keep the current value !"; set_style "base"

            # Title part
            
            set_style "bold" "blue"; echo "New Task Title : "; set_style "base"
            read -r new_title

            if [ -n "$new_title" ]; then
                
                number=$(grep -o -E ",$Title[0-9]*," ToDo.csv | wc -l)
                if [ ! "$number" -eq 1 ]; then
                    set_style "sous" "red"; echo -e "$Title is already mentionned we will create a task named $Title$((number+1))" ; set_style "base"
                    task_title="$new_title$((number+1))"
                else
                    task_title=$new_title
                fi
            fi

            # Description part
            
            set_style "bold" "blue"; echo "New Task Description : "; set_style "base"
            read -r new_description

            if [ -n "$new_description" ]; then
                task_description="$new_description"
            fi

            # Location part

            set_style "bold" "blue"; echo "New task Location : "; set_style "base"
            read -r new_location
            if [ -n "$new_description" ]; then
                task_description="$new_description"
            fi

            # Due Date and time part
            
            while true;do
                set_style "bold" "blue"; echo "New Due Time : (Format YYYY-MM-DD HH:MM)" ; set_style "base"
                read -r new_due_time

                if [ -n "$new_due_time" ]; then

                    if Valid_Date "$new_due_time"; then
                        task_due_time=$new_due_time
                        break
                    fi

                    set_style "bold" "red"; echo -e "The date is not correct !\n" ; set_style "base"
                else
                    break
                fi
            done
            ;;
        "Completion"|"completion") # If the user choose the completion mark only

            # Completion mark part    
            
            set_style "bold" "green"; echo "Update Completion Mark ? (Y/N)" ; set_style "base"
            read -r update_completion

            if [ "$update_completion" = "Y" ] || [ "$update_completion" = "y" ]; then
                task_completion="Completed"
                set_style "boldblink" "green"; echo "Completion Mark Updated !"; set_style "base"
            fi
            ;;
        *)
            set_style "bold" "red" ; echo "Invalid update type !"; set_style "base"
            return
            ;;
    esac

    # Updating the file
    
    sed -i "s/^$task_id,.*$/$task_id,$task_title,$task_description,$task_location,$task_due_time,$task_completion/" ToDo.csv

}

# Function to delete a task

Delete () {

    # Ask the user to choose a delete method
    while true; do
        set_style "bold" "blue"; echo "How would you like to delete the task ? (ID/Title)"; set_style "base"
        read -r method

        case $method in
            "Title"|"title"|"TITLE") # If he choose the title
                set_style "bold" "blue"; echo "Enter the title of the task you want to delete : "; set_style "base"
                read -r Title
                task_info=$(grep -q -i -E "^.*,$Title," ToDo.csv)
                if [ -z "$task_info" ]; then
                    set_style "bold" "red"; echo "The task with the title '$Title' couldn't be found ! " ; set_style "base"
                else
                    set_style "bold" "blue"; echo "Are you sure you want to delete this task ? (Y/N)" ; set_style "base"
                    read -r confirm
                    if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
                        grep -v -i -E "^.*,$Title," ToDo.csv > temp.csv
                        mv temp.csv ToDo.csv

                        # Useless part :x
                        clear
                        for((i=0;i<2;i++)); do
                            set_style "boldblink" "green"; echo -n "Deleting the task"
                            for ((i=0;i<3;i++)); do
                                echo -n " ."
                                sleep 1
                            done
                            clear
                        done
                        set_style "base"

                        set_style "bold" "green"; echo "Task deleted successfully ! " ; set_style "base"
                    else
                        set_style "bold" "red"; echo "Task deletion canceled."; set_style "base"
                    fi
                    return
                fi
                ;;
            "ID"|"id"|"Id") # If he choose the ID
                set_style "bold" "blue"; echo "Enter the ID of the task you want to delete : "; set_style "base"
                read -r ID
                task_info=$(sed -n "/$ID,.*/p" ToDo.csv)
                if [ -z "$task_info" ]; then
                    set_style "bold" "red"; echo "The task with the ID '$ID' couldn't be found ! "; set_style "base"
                else
                    set_style "bold" "blue"; echo "Are you sure you want to delete this task ? (Y/N)" ; set_style "base"
                    read -r confirm
                    if [ "$confirm" = "Y" ] || [ "$confirm" = "y" ]; then
                        awk -v id="$ID" -F ',' '$1 != id' ToDo.csv > temp.csv
                        mv temp.csv ToDo.csv

                        # Useless part :x
                        clear
                        for((i=0;i<2;i++)); do
                            set_style "boldblink" "green"; echo -n "Deleting the task"
                            for ((i=0;i<3;i++)); do
                                echo -n " ."
                                sleep 1
                            done
                            clear
                        done
                        set_style "base"

                        set_style "bold" "green"; echo "Task deleted successfully ! " ; set_style "base"
                    else
                        set_style "bold" "red"; echo "Task deletion cancelled."; set_style "base"
                    fi
                    return
                fi
                ;;
            *) # if he choose anything else
                set_style "bold" "red"; echo "Invalid delete method !"; set_style "base"
                ;;
        esac
    done
}

# Function to show a task

ShowTaskInfo() {

    # Ask the user to choose the search method

    while true; do
        set_style "bold" "blue" ; echo "How would you like to search for the task ? (ID/Title)"; set_style "base"
        read -r method
        # You can remove less if you want to see it in the prompt
        case $method in
            "Title"|"title"|"TITLE")
                set_style "bold" "blue"; echo "Enter the Title of the task you want to view : "; set_style "base"
                read -r Title
                task_info=$(grep -i -m 1 -E "^[0-9]+,$Title" ToDo.csv)
                if [ -z "$task_info" ]; then
                    set_style "bold" "red"; set_style "bold" "red"; echo "The task with the title '$Title' couldn't be found ! " ; set_style "base"
                else 
                    set_style "bold" "cyan"; echo -e "Task Information :\n\
+------+----------------------+-------------------------------------------------------------------------+--------------------------+----------------------+----------------------+\n\
| ID   | Title                | Description                                                             | Location                 | Due Date             | Completion           |\n\
+------+----------------------+-------------------------------------------------------------------------+--------------------------+----------------------+----------------------+\n\
$(echo "$task_info" | awk -F ',' '{ printf("| %-4s | %-20s | %-71s | %-24s | %-20s | %-20s |\n", $1, $2, substr($3, 1, 68) (length($3) > 68 ? "..." : ""), $4, $5, $6) }')\n\
+------+----------------------+-------------------------------------------------------------------------+--------------------------+----------------------+----------------------+\n" | less
                    set_style "base"
                    return
                fi
                ;;
            "ID"|"id"|"Id")
                set_style "bold" "blue"; echo "Enter the ID of the task you want to view : "; set_style "base"
                read -r ID
                task_info=$(sed -n "/^$ID,/p" ToDo.csv)
                if [ -z "$task_info" ]; then
                    set_style "bold" "red"; set_style "bold" "red"; echo "The task with the title '$ID' couldn't be found ! " ; set_style "base"
                else
                    set_style "bold" "cyan"; echo -e "Task Information :\n\
+------+----------------------+-------------------------------------------------------------------------+--------------------------+----------------------+----------------------+\n\
| ID   | Title                | Description                                                             | Location                 | Due Date             | Completion           |\n\
+------+----------------------+-------------------------------------------------------------------------+--------------------------+----------------------+----------------------+\n\
$(echo "$task_info" | awk -F ',' '{ printf("| %-4s | %-20s | %-71s | %-24s | %-20s | %-20s |\n", $1, $2, substr($3, 1, 68) (length($3) > 68 ? "..." : ""), $4, $5, $6) }')\n\
+------+----------------------+-------------------------------------------------------------------------+--------------------------+----------------------+----------------------+\n" | less
                    set_style "base"
                    return
                fi
                ;;
            *)
                set_style "bold" "red"; echo "Invalid search method !!"; set_style "base"
                ;;
        esac
    done
}

# Function to show the completed and uncompleted task of a given day

ShowAllTask() {
    
    
    if [ -n "$1" ]; then
        Ndate=$(date -d "$1" +"%Y-%m-%d" 2>/dev/null)
    fi

    while true; do
        if [ -z "$Ndate" ]; then
            set_style "bold" "blue"; echo "Enter the date (Format: YYYY-MM-DD) : "; set_style "base"
            read -r Ndate
        fi

        if [ -z "$Ndate" ]; then
            set_style "bold" "red"; echo "Please enter a date !"; set_style "base"
        else
            if date -d "$Ndate" >/dev/null 2>&1; then
                break
            else
                set_style "bold" "red"; echo "Invalid date format !!"; set_style "base"
                Ndate=""
            fi
        fi
    done

    completed=$(awk -F ',' -v date="$Ndate" '$5 ~ "^" date && $6 == "Completed" {print $2}' ToDo.csv)
    uncompleted=$(awk -F ',' -v date="$Ndate" '$5 ~ "^" date && $6 != "Completed" {print $2}' ToDo.csv)
    
    merge=$(paste <(echo "$completed") <(echo "$uncompleted"))
    # With the help of Prof. Youssef

    merge=${merge//$'\t'/','}
    
    if [ -n "$completed" ] && [ -n "$uncompleted" ]; then # Showing a table with the completed and uncompleted Task
        set_style "bold" "blue"; echo "Tasks:"; set_style "bold" "cyan"
        echo -e "\n\
+----------------------------------+----------------------------------+\n\
| Completed Task                   | Uncompleted Task                 |\n\
+----------------------------------+----------------------------------+"
while IFS=',' read -r completed uncompleted; do
        printf "| %-32s | %-32s |\n" "${completed//','/}" "${uncompleted//','/}"
done <<< "$merge"
echo -e "+----------------------------------+----------------------------------+\n"
        set_style "base"
        return


    elif [ -z "$completed" ] && [ -n "$uncompleted" ]; then # Showing a table with the uncompleted Task
        set_style "bold" "blue"; echo "Tasks:"; set_style "bold" "cyan"
        echo -e "\n\
+----------------------------------+\n\
| Uncompleted Task                 |\n\
+----------------------------------+\n\
$(printf "| %-32s |\n" "$uncompleted")\n\
+----------------------------------+\n"
    echo -e  "There's no completed task !"
    set_style "base"
    return

    elif [ -z "$uncompleted" ] && [ -n "$completed" ]; then # Showing a table with the completed Task
        set_style "bold" "blue"; echo "Tasks:"; set_style "bold" "cyan"
        echo -e "\n\
+----------------------------------+\n\
| Completed Task                   |\n\
+----------------------------------+\n\
$(printf "| %-32s |\n" "$completed")\n\
+----------------------------------+\n"
        echo -e "You have completed all the task !!!!!"
        set_style "base"
        return
    fi     

    set_style "bold" "red"; echo "No task for this day !"; set_style "base"
}

# Function with the menu

Menu () {

    while true; do
        clear
        set_style "bold" "cyan"; echo -e "\n\
████████  █████  ███████ ██   ██     ███    ███  █████  ███    ██  █████   ██████  ███████ ██████ \n \
   ██    ██   ██ ██      ██  ██      ████  ████ ██   ██ ████   ██ ██   ██ ██       ██      ██   ██\n \
   ██    ███████ ███████ █████       ██ ████ ██ ███████ ██ ██  ██ ███████ ██   ███ █████   ██████ \n \
   ██    ██   ██      ██ ██  ██      ██  ██  ██ ██   ██ ██  ██ ██ ██   ██ ██    ██ ██      ██   ██\n \
   ██    ██   ██ ███████ ██   ██     ██      ██ ██   ██ ██   ████ ██   ██  ██████  ███████ ██   ██\n\n"

echo "                                  1 - Create a Task."
echo "                                  2 - Update a Task."
echo "                                  3 - Delete a Task."    
echo "                              4 - Show info about a Task."
echo "                     5 - Display the completed and uncompleted Task."
echo "                                        6- Quit."
        read -r choice
        
        case "$choice" in
            "1")
                clear
                Create
                read -s
                ;;
            "2")
                clear
                Update
                read -s
                ;;
            "3")
                clear
                Delete
                read -s
                ;;
            "4")
                clear
                ShowTaskInfo
                ;;
            "5")
                clear
                ShowAllTask
                read -s
                ;;
            "6")
                clear
                break
                ;;
            *)
               clear
               set_style "bold" "red"; echo "Invalid option !"; set_style "base"
               read -s
       esac
   done
}
                                                                                                   


case "$1" in
    "--menu"|"-m") # To Show the menu
        Menu
        ;;
    "--create"|"-c") # To create a Task
        Create
        ;;
    "--update"|"-u") # To update a Task
        Update
        ;;
    "--delete"|"-d") # To Delete a Task
        Delete
        ;;
    "--info"|"-i") # To Execute the ShowTaskInfo
        ShowTaskInfo
        ;;
    "--show"|"-s") # To Execute the ShowAllTask function
        if [ -n "$2" ]; then
            ShowAllTask "$2"
        else
            ShowAllTask
        fi
        ;;
    "")
        # If no argument is provided it execute ShowAllTask with the current date
        ShowAllTask "$(date +"%Y-%m-%d")"
        ;;
    "--help"|"-h") # To show all the options and their usage
        echo -e "Usage: todo [Option]\n\
Manage your task in a csv file with this command.\n\
Show completed task and uncompleted task if any of the option is specified.\n\n\
None of the option take an argument.\n\
    -m, --menu            Show you the menu that helps you manage your tasks.\n\
    -c, --create          Gather the information from the user to create the task.\n\
    -u, --update          Gather the information from the user to update a task.\n\
    -i, --info            Show information about a task.\n\
    -s, --show            Show All the completed and uncompleted task of a given day.\n\n\
The shell have to be in full screen to display correctly the output.\n\
The comma usage is inadequate as the program is not optimized for their implementation.\n\n\
Exit status:\n\
 0, if OK,\n\
 1, if an error occured.\n\n\
If any bug occurs report it to me\n"
 
        ;; 
    *)
        # If an invalid option is provided
        echo "todo: invalid option"
        echo "Use 'todo -help' for more information."
        ;;
esac


                    
