#!/bin/bash

verify_run_params() {
    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
        echo "Usage: $0 run <organization> <workspace> <path_to_content_directory>"
        exit 0
    fi
}

verify_create_ws_params() {
    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo "Usage: $0 create-ws <organization> <workspace>"
        exit 0
    fi
}

# Create workspace
create_workspace() {
    ORG_NAME=$1
    WORKSPACE_NAME=$2

    echo "{\"data\": {\"attributes\": {\"name\": \"${WORKSPACE_NAME}\",\"resource-count\": 0},\"type\": \"workspaces\"}}" > ./create-ws-payload.json

    curl \
    --header "Authorization: Bearer $TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request POST \
    --data @create-ws-payload.json \
    https://app.terraform.io/api/v2//organizations/${ORG_NAME}/workspaces

    rm create-ws-payload.json
    echo "SUCCESS..."
}

# Look Up the Workspace ID
get_workspace_id() {
    ORG_NAME="${1}"
    WORKSPACE_NAME="${2}"

    WORKSPACE_ID=($(curl \
    --header "Authorization: Bearer $TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    https://app.terraform.io/api/v2/organizations/$ORG_NAME/workspaces/$WORKSPACE_NAME \
    | jq -r '.data.id'))

    echo "${WORKSPACE_ID}"
}

# Create a Configuration Version
create_config_version() {
    WORKSPACE_ID=$1

    echo '{"data":{"type":"configuration-versions"}}' > ./create_config_version.json

    UPLOAD_URL=($(curl \
    --header "Authorization: Bearer $TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    --request POST \
    --data @create_config_version.json \
    https://app.terraform.io/api/v2/workspaces/$WORKSPACE_ID/configuration-versions \
    | jq -r '.data.attributes."upload-url"'))

    rm create_config_version.json
    echo "${UPLOAD_URL}"
}

# Upload the Configuration Content File
upload_config_content() {
    UPLOAD_URL=$1
    CONTENT_DIRECTORY=$2

    UPLOAD_FILE_NAME="./content-$(date +%s).tar.gz"
    tar -zcf "$UPLOAD_FILE_NAME" -C "$CONTENT_DIRECTORY" .

    curl \
    --header "Content-Type: application/octet-stream" \
    --request PUT \
    --data-binary @"$UPLOAD_FILE_NAME" \
    $UPLOAD_URL

    rm $UPLOAD_FILE_NAME

    echo "SUCCESS..."
}

run_code() {
    upload_url=$(create_config_version $1)
    upload_config_content $upload_url $2
}

usage() {
    echo "$0 [run|create-ws]"
}

case $1 in
    create-ws)
        verify_create_ws_params $@
        create_workspace $2 $3
        ;;
    run)
        verify_run_params $@
        workspace_id=$(get_workspace_id $2 $3)
        run_code $workspace_id $4
        ;;
    *)
        usage
        ;;
esac