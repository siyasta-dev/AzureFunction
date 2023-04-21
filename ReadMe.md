# Description

The Azure function will run Resource Graph query and saves the result in Storage Account Posts the same data to a Logic App.

# SetUp

## Script setup
You would need to edit the [script](./ReportVMStatus/run.ps1?plain=1#L4) with resource graph query and the storage account info.

## Permission Setup
You need to enable Managed identity on Azure Function and provide `Reader` access to the Manged Identity on Subscription and `Contributor` access on storage account.

## Logic App Setup

1. Create a Logic app with HTTP Post trigger and Body JSON schema as follow.
    ```
    {
        "properties": {
            "data": {
                "type": "string"
            }
        },
        "type": "object"
    }
    ```

1. Subsequently add action of sending mail with dynamic content `data` as mail body.
1. Save the HTTP Post URL as `LOGIC_APP_URL` in Application setting of Function App.