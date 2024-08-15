#!/usr/bin/env bash

state_pull() {
    echo ">> state pull"
    cd "$1" || exit 1
    terraform init
    terraform state pull > terraform.tfstate
    cd - || exit 1
}

state_mv() {
    echo ">> state mv"
    cd "$2" || exit 1
    terraform init
    for i in $(terraform state list); do
        terraform state mv -state-out="../$1/terraform.tfstate" "$i" "$i"
    done
    cd - || exit 1
}

state_push() {
    echo ">> state push"
    cd "$1" || exit 1
    terraform state push terraform.tfstate
    cd - || exit 1
}

cleanup() {
    echo ">> cleanup"
    cd "$1" || exit 1
    rm -f terraform.tfstate
    rm -f terraform.tfstate.*
    cd - || exit 1
}

# Print help text and exit.
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: tfstate-merge.sh [options]"
    echo
    echo "Examples:"
    echo
    echo "  - ./tfstate-merge.sh stack1-migrate-to stack2-migrate-from"
    echo "  - ./tfstate-merge.sh app data"
    exit 0
fi

echo "> START"
echo ">> TF = $(terraform version)..."
state_pull "$1"
state_mv "$1" "$2"
state_push "$1"
# Uncomment below line if you want to cleanup state files
# cleanup "$1"
echo "> FINISHED"
