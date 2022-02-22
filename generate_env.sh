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


if [[ ! -z ${DD_E2E_CLIENT_TOKEN+x} ]]; then
    tee ./e2e_test_app/.env > /dev/null << END
DD_CLIENT_TOKEN=$DD_E2E_CLIENT_TOKEN
DD_APPLICATION_ID=$DD_E2E_APPLICATION_ID
DD_E2E_IS_ON_CI=${IS_ON_CI:-false}
END

else
    echo "Not generating E2E .env file because DD_E2E_CLIENT_TOKEN is $DD_E2E_CLIENT_TOKEN"
fi
