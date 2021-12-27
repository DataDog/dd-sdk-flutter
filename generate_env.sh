#!/usr/bin/env bash
set echo off

tee ./example/.env > /dev/null << END
# Edit this file with your Datadog client token, environment and application id
DD_CLIENT_TOKEN=$DD_CLIENT_TOKEN
DD_APPLICATION_ID=$DD_APPLICATION_ID
DD_ENV=prod
END

tee ./integration_test_app/.env > /dev/null << END
# Edit this file with your Datadog client token, environment and application id
DD_CLIENT_TOKEN=$DD_CLIENT_TOKEN
DD_APPLICATION_ID=$DD_APPLICATION_ID
DD_ENV=prod
END
