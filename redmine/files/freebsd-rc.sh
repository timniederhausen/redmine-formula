{%- from 'redmine/map.jinja' import redmine with context -%}
{%- set redmine_name = 'redmine' -%}
#! /bin/sh

# REDMINE {{ redmine_name }}
# Maintainer: @tim
# Authors: @tim

# PROVIDE: {{ redmine_name }}
# KEYWORD: shutdown

. /etc/rc.subr

name="{{ redmine_name }}"
rcvar="{{ redmine_name }}_enable"
extra_commands="status"

load_rc_config {{ redmine_name }}
: ${{ '{' }}{{ redmine_name }}_enable:="NO"}

required_dirs="{{ redmine.root_directory }}"

start_cmd="start_redmine"
stop_cmd="stop_redmine"
restart_cmd="restart_redmine"
status_cmd="print_status"

### Environment variables
RAILS_ENV="production"

# Script variable names should be lower-case not to conflict with
# internal /bin/sh variables such as PATH, EDITOR or SHELL.
app_user="{{ redmine.user }}"
app_root="{{ redmine.root_directory }}"
pid_path="$app_root/tmp/pids"
socket_path="$app_root/tmp/sockets"
web_server_pid_path="$pid_path/unicorn.pid"


redmine_execute(){
# Switch to the app_user if it is not he/she who is running the script.
if [ "$USER" != "$app_user" ]; then
  su {{ redmine.user }} -c "$1"
else
  eval "$1"
fi
}

# Switch to the Redmine path, exit on failure.
if ! cd "$app_root" ; then
 echo "Failed to cd into $app_root, exiting!";  exit 1
fi

### Init Script functions

## Gets the pids from the files
check_pids(){
  redmine_execute "mkdir -p \"$pid_path\""
  if [ "$?" != "0" ]; then
    echo "Could not create the path $pid_path needed to store the pids."
    exit 1
  fi
  # If there exists a file which should hold the value of the Unicorn pid: read it.
  if [ -f "$web_server_pid_path" ]; then
    wpid=$(cat "$web_server_pid_path")
  else
    wpid=0
  fi
}

## Called when we have started the two processes and are waiting for their pid files.
wait_for_pids(){
  i=0;
  while [ ! -f $web_server_pid_path ]; do
    sleep 0.1;
    i=$((i+1))
    if [ $((i%10)) = 0 ]; then
      echo -n "."
    elif [ $((i)) = 301 ]; then
      echo "Waited 30s for the processes to write their pids, something probably went wrong."
      exit 1;
    fi
  done
  echo
}

# We use the pids in so many parts of the script it makes sense to always check them.
# Only after start() is run should the pids change.
check_pids

## Checks whether the different parts of the service are already running or not.
check_status(){
  check_pids
  # If the web server is running kill -0 $wpid returns true, or rather 0.
  # Checks of *_status should only check for == 0 or != 0, never anything else.
  if [ $wpid -ne 0 ]; then
    kill -0 "$wpid" 2>/dev/null
    web_status="$?"
  else
    web_status="-1"
  fi
  if [ $web_status = 0 ]; then
    redmine_status=0
  else
    # http://refspecs.linuxbase.org/LSB_4.1.0/LSB-Core-generic/LSB-Core-generic/iniscrptact.html
    # code 3 means 'program is not running'
    redmine_status=3
  fi
}

## Check for stale pids and remove them if necessary.
check_stale_pids(){
  check_status
  # If there is a pid it is something else than 0, the service is running if
  # *_status is == 0.
  if [ "$wpid" != "0" ] && [ "$web_status" != "0" ]; then
    echo "Removing stale Unicorn web server pid. This is most likely caused by the web server crashing the last time it ran."
    if ! rm "$web_server_pid_path"; then
      echo "Unable to remove stale pid, exiting."
      exit 1
    fi
  fi
}

## If no parts of the service is running, bail out.
exit_if_not_running(){
  check_stale_pids
  if [ "$web_status" != "0" ]; then
    echo "Redmine is not running."
    exit
  fi
}

## Starts Unicorn if they're not running.
start_redmine() {
  check_stale_pids

  if [ "$web_status" != "0" ]; then
    echo "Starting Redmine Unicorn"
  fi

  # Then check if the service is running. If it is: don't start again.
  if [ "$web_status" = "0" ]; then
    echo "The Unicorn web server already running with pid $wpid, not restarting."
  else
    # Remove old socket if it exists
    rm -f "$socket_path"/redmine.socket 2>/dev/null
    # Start the web server
    redmine_execute "RAILS_ENV=$RAILS_ENV bin/web start"
  fi

  # Wait for the pids to be planted
  wait_for_pids
  # Finally check the status to tell wether or not Redmine is running
  print_status
}

## Asks Unicorn if they would be so kind as to stop, if not kills them.
stop_redmine() {
  exit_if_not_running

  if [ "$web_status" = "0" ]; then
    echo "Shutting down Redmine Unicorn"
    redmine_execute "RAILS_ENV=$RAILS_ENV bin/web stop"
  fi

  # If something needs to be stopped, lets wait for it to stop. Never use SIGKILL in a script.
  while [ "$web_status" = "0" ]; do
    sleep 1
    check_status
    printf "."
    if [ "$web_status" != "0" ]; then
      printf "\n"
      break
    fi
  done

  sleep 1
  # Cleaning up unused pids
  rm "$web_server_pid_path" 2>/dev/null

  print_status
}

print_status() {
  check_status
  if [ "$web_status" = "0" ]; then
      echo "The Redmine Unicorn web server with pid $wpid is running."
  else
      printf "The Redmine Unicorn web server is \033[31mnot running\033[0m.\n"
  fi
}

## Tells unicorn to reload it's config and Sidekiq to restart
reload_redmine(){
  exit_if_not_running
  if [ "$wpid" = "0" ];then
    echo "The Redmine Unicorn Web server is not running thus its configuration can't be reloaded."
    exit 1
  fi
  printf "Reloading Redmine Unicorn configuration... "
  redmine_execute "RAILS_ENV=$RAILS_ENV bin/web reload"
  echo "Done."

  wait_for_pids
  print_status
}

## Restarts Sidekiq and Unicorn.
restart_redmine(){
  check_status
  if [ "$web_status" = "0" ]; then
    stop_redmine
  fi
  start_redmine
}

PATH="${PATH}:/usr/local/bin"
run_rc_command "$1"
