##
## Licensed Materials - Property of IBM
## 5737-I23
## Copyright IBM Corp. 2018 - 2022. All Rights Reserved.
## U.S. Government Users Restricted Rights:
## Use, duplication or disclosure restricted by GSA ADP Schedule
## Contract with IBM Corp.
##

# Initialize DB2 cmd environment
set-item -path env:DB2CLP -value "**$$**"

function Run-DB2Cmd($query) {
    # Run DB2 query using db2.exe
    # Usage:
    #   Run-DB2Cmd <$query>
    # Arguments:
    #   $query - the query string to append in the db2 command.
    # Returns:
    #   The query output.

    $output = Invoke-Expression "db2.exe -s -x ""$query""" | Out-String
    if ($LASTEXITCODE -gt 2) {
        Write-Host "ERROR: $output"
        exit $LASTEXITCODE
    }
    return $output.Trim()
}

function Prompt-Input {
    # Prompt for input
    # Usage:
    #   Prompt-Input <$message> [$type]
    # Arguments:
    #   $message - the prompt message
    #   $type - the prompt type, must be one of 'text', 'confirm', 'password'. Default to 'text' if not provided
    # Returns:
    #   If $type is text or password, the input string is returned; if $type is 'confirm', the bool $true or $false is returend.
    param(
        [Parameter(Mandatory=$true)][string]$message,
        [Parameter(Mandatory=$false)][ValidateSet('text', 'confirm', 'password')][string]$type = 'text'
    )
    if ($type -eq 'confirm') {
        $message = "$message [Y/N]"
    }
    $value = ""
    while (! $value) {
        $hasInput = $false
        if ($type -eq 'password') {
            $secureStr = Read-Host -AsSecureString -Prompt $message
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureStr)
            $value = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            if ($value) {
                $hasInput = $true
                $secureStr2 = Read-Host -AsSecureString -Prompt "Please confirm the password by entering it again"
                $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureStr2)
                $confirmValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
                if ($value -ne $confirmValue) {
                    $value = ""
                    $confirmValue = ""
                }
            }
        } else {
            $value = Read-Host -Prompt $message
            if ($value) {
                $hasInput = $true
            }
            if ( $type -eq 'confirm') {
                if ($value.ToUpper() -ne "Y" -and $value.ToUpper() -ne "N" ) {
                    $value = ""
                }
            }
        }
        if (! $value ) {
            $errMsg = "Please input a valid value."
            if ($type -eq 'password' -and $hasInput) {
                $errMsg = "The inputs do not match. Please try again."
            } elseif ($type -eq 'confirm') {
                $errMsg = "Please enter Y or N."
            }
            Write-Host ""
            Write-Host $errMsg
            Write-Host ""
        }
    }
    if ($type -eq 'confirm') {
        return ($value.ToUpper() -eq "Y")
    } else {
        return $value
    }
}

function Get-ReleaseSchemaVersion {
    # Get the script release base version

    # If the user sets DB_SCHEMA_VERSION environment variable, return it directly (for dev and QA use).
    $releaseSchemaVersion = $env:DB_SCHEMA_VERSION
    if ($releaseSchemaVersion) {
        return $releaseSchemaVersion
    }

    # Try sp-version.json (regular use case).
    $spVersionFile = "./sp-version.json"
    if (-not (Test-Path $spVersionFile)) {
        # sp-version.json doesn't exist. Try release.env (dev environment).
        $spVersionFile = "../../release.env"
        if (-not (Test-Path $spVersionFile)) {
            Write-Error "ERROR: sp-version.json is missing"
            exit 1
        }
    }

    # Extract DB_SCHEMA_VERSION from the file (handles JSON or env format).
    $releaseSchemaVersion = Get-Content $spVersionFile |
                            Select-String -Pattern '^\s*?\"?DB_SCHEMA_VERSION\"?[\=:]\s*?\"?([0-9.]+)\"?' |
                            ForEach-Object { $_.Matches.Groups[1].Value }

    if (! $releaseSchemaVersion) {
        Write-Error "ERROR: cannot read DB_SCHEMA_VERSION from ${spVersionFile}"
        exit 1
    }
    return $releaseSchemaVersion
}

function Get-BaseDBVersion($baseDBName, $baseDBSchema) {
    # Get the base DB scheam version
    # Usage:
    #   Get-BaseDBVersion <$baseDBName> <$baseDBSchema>
    # Arguments:
    #   baseDBName - the base DB name
    #   baseDBSchema - the base DB schema. It should be the same as the db user
    # Returns:
    #   The schema version of the base DB.

    $baseDBSchema = $baseDBSchema.ToUpper()
    $schemaVersion = ""

    # Connect to the database
    Run-DB2Cmd "connect to $baseDBName" | Out-Null
    Run-DB2Cmd "set schema $baseDBSchema" | Out-Null

    # Make sure the schema is correct
    $output = Run-DB2Cmd "SELECT 1 FROM SYSIBM.SYSTABLES WHERE TYPE='T' AND UPPER(CREATOR)='$baseDBSchema' AND UPPER(NAME)='TENANTINFO'"
    if (! $output) {
        Write-Host "ERROR: cannot find base DB tables in database '$baseDBName' schema '$baseDBSchema'."
        exit 1
    }

    # Try to get the base DB schemaVersion from BASE_OPTIONS table
    $output = Run-DB2Cmd "SELECT 1 FROM SYSIBM.SYSTABLES WHERE TYPE='T' AND UPPER(CREATOR)='$baseDBSchema' AND UPPER(NAME)='BASE_OPTIONS'"
    if ($output) {
        $schemaVersion = Run-DB2Cmd "SELECT SCHEMA_VERSION FROM BASE_OPTIONS"
    }
    if (! $schemaVersion) {
        # There's no BASE_OPTIONS table. We have to guess...
        $schemaVersion = ""
        # Check OPT_FLAGS column in TENANTINFO table. OPT_FLAGS column was added on 21.0.3, and removed on 22.0.1.
        $output = Run-DB2Cmd "SELECT 1 FROM SYSCAT.COLUMNS WHERE UPPER(TABNAME)='TENANTINFO' AND UPPER(TABSCHEMA)='$baseDBSchema' AND UPPER(COLNAME)='OPT_FLAGS'"
        if ( $output ) {
            # If it has this column, it must be 21.0.3.
            $schemaVersion = "21.0.3"
        }

        if (! $schemaVersion) {
            # Check CONFIG column in TenantInfo. CONFIG was added since the beginning and was removed on 22.0.1, together with OPT_FLAGS.
            $output = Run-DB2Cmd "SELECT 1 FROM SYSCAT.COLUMNS WHERE UPPER(TABNAME)='TENANTINFO' AND UPPER(TABSCHEMA)='$baseDBSchema' AND UPPER(COLNAME)='CONFIG'"
            if ( $output ) {
                # If CONFIG exists, it must be 21.0.1 or 21.0.2
                $schemaVersion = "21.0.2"
            }
        }

        if (! $schemaVersion) {
            # We know it doens't have BASE_OPTIONS table, which was added on 23.0.1, thus it must be 23.0.1
            $schemaVersion = "23.0.1"
        }
    }

    # Close the connection
    Run-DB2Cmd "connect reset" | Out-Null
    return $schemaVersion
}

function Get-TenantDBVersion($baseDBName, $baseDBSchema, $tenantDBName, $tenantDBSchema) {
    # Get the tenant (project) DB scheam version
    # Usage:
    #   Get-TenantDBVersion <$baseDBName> <$baseDBSchema> <$tenantDBName> <$tenantDBSchema>
    # Arguments:
    #   baseDBName - the base DB name
    #   baseDBSchema - the base DB schema. It should be the same as the db user
    #   tenantDBName - the tenant DB name matching the DBNAME colum in TenantInfo table. Note that it may be different from the TenantID
    #   tenantDBSchema - the tenant DB schema (i.e., ontology in the TenantInfo table)
    # Returns:
    #   The schema version of the tenant (project) DB.

    $tenantDBName = $tenantDBName.ToUpper()
    $tenantDBSchema = $tenantDBSchema.ToUpper()
    $schemaVersion = ""

    # Connect to the database
    Run-DB2Cmd "connect to $baseDBName" | Out-Null
    Run-DB2Cmd "set schema $baseDBSchema" | Out-Null

    # Query the tenant DB version
    $schemaVersion = Run-DB2Cmd "SELECT TENANTDBVERSION FROM TENANTINFO WHERE UPPER(DBNAME)='$tenantDBName' AND UPPER(ONTOLOGY)='$tenantDBSchema'"
    if ( ! $schemaVersion ) {
        Write-Host "ERROR: cannot find the record of tenant DB '${tenantDBName}' ontology '${tenantDBSchema}' in base DB."
        exit 1
    }

    # Close the connection
    Run-DB2Cmd "connect reset" | Out-Null

    return $schemaVersion
}

function Set-BaseDBVersion($baseDBName, $baseDBSchema, $schemaVersion) {
    # Sets the base DB scheam version
    # Usage:
    #   Set-BaseDBVersion <$baseDBName> <$baseDBSchema> [$schemaVersion]
    # Arguments:
    #   baseDBName - the base DB name
    #   baseDBSchema - the base DB schema. It should be the same as the db user
    #   schemaVersion (optinoal) - the schema version to set. If not provided, the version from Get-ReleaseSchemaVersion will be used

    if (! $schemaVersion) {
        $schemaVersion = Get-ReleaseSchemaVersion
    }

    # Connect to the database
    Run-DB2Cmd "connect to $baseDBName" | Out-Null
    Run-DB2Cmd "set schema $baseDBSchema" | Out-Null

    # Update the base DB version
    Run-DB2Cmd "UPDATE BASE_OPTIONS SET SCHEMA_VERSION='$schemaVersion'" | Out-Null

    # Close the connection
    Run-DB2Cmd "connect reset" | Out-Null
}

function Set-TenantDBVersion($baseDBName, $baseDBSchema, $tenantDBName, $tenantDBSchema, $schemaVersion) {
    # Sets the tenant (project) DB scheam version
    # Usage:
    #   Set-TenantDBVersion <$baseDBName> <$baseDBSchema> <$tenantDBName> <$tenantDBSchema> [$schemaVersion]
    # Arguments:
    #   baseDBName - the base DB name
    #   baseDBSchema - the base DB schema. It should be the same as the db user
    #   tenantDBName - the tenant DB name matching the DBNAME colum in TenantInfo table. Note that it may be different from the TenantID
    #   tenantDBSchema - the tenant DB schema (i.e., ontology in the TenantInfo table)
    #   schemaVersion (optinoal) - the schema version to set for this tenant (project). If not provided, the version from Get-ReleaseSchemaVersion will be used

    $tenantDBName = $tenantDBName.ToUpper()
    $tenantDBSchema = $tenantDBSchema.ToUpper()
    
    if (! $schemaVersion) {
        $schemaVersion = Get-ReleaseSchemaVersion
    }

    # Connect to the database
    Run-DB2Cmd "connect to $baseDBName" | Out-Null
    Run-DB2Cmd "set schema $baseDBSchema" | Out-Null

    # Update the tenant DB version
    Run-DB2Cmd "UPDATE TENANTINFO SET TENANTDBVERSION='$schemaVersion', BACAVERSION='$schemaVersion' WHERE UPPER(DBNAME)='$tenantDBName' AND UPPER(ONTOLOGY)='$tenantDBSchema'" | Out-Null

    # Close the connection
    Run-DB2Cmd "connect reset" | Out-Null
}

function Get-UpgradeTemplates($prefix, $fromVersion, $toVersion) {
    # Parameters:
    #   $prefix - the template prefix (UpgradeBaseDB or UpgradeTenantDB)
    #   $fromVersion - the starting version
    #   $toVersion - the target version

    # Find matching templates
    $templateFiles = Get-ChildItem -Path "./sql/" -Filter "*${prefix}_*.sql.template" | Sort-Object Name

    $foundMatch = $false
    $thisFrom = ""
    $thisTo = ""
    $sqlFiles = @()

    foreach ($templateFile in $templateFiles) {
        if (!$foundMatch) {
            $thisFrom = ([Regex]::Match($templateFile.Name, "${prefix}_([0-9.]+)_to_([0-9.]+)\.sql\.template")).Groups[1].Value
            if ($thisFrom -eq $fromVersion) {
                $foundMatch = $true
            }
        }

        if ($foundMatch) {
            $sqlFiles += $templateFile.FullName
            $thisTo = ([Regex]::Match($templateFile.Name, "${prefix}_([0-9.]+)_to_([0-9.]+)\.sql\.template")).Groups[2].Value
            if ($thisTo -eq $toVersion) {
                break
            }
        }
    }
    return $sqlFiles
}

function Run-BaseDBUpgradeTemplates($baseDBName, $baseDBSchema, [string[]]$templateFiles) {
    # Run the base DB sql templates. This function will connect to the database
    # Usage:
    #   Run-BaseDBUpgradeTemplates <$baseDBName> <$baseDBSchema> <$template_files>
    # Arguments:
    #   baseDBName - the base database name
    #   baseDBSchema - the base schema
    #   templateFiles - a list of template files to run

    if ($templateFiles -eq $null -or $templateFiles.Count -eq 0) {
        Write-Host "No upgrade template to run."
        return
    }

    $baseDBSchema = $baseDBSchema.ToUpper()

    # Connect to the database
    Run-DB2Cmd "connect to $baseDBName" | Out-Null
    Run-DB2Cmd "set schema $baseDBSchema" | Out-Null

    $lastVersion = ""
    foreach ($templateFile in $templateFiles) {
        # Track the versions
        if (! $lastVersion) {
            $lastVersion = ([Regex]::Match($templateFile, ".+_([0-9.]+)_to_([0-9.]+)\.sql\.template")).Groups[1].Value
        }
        $thisVersion = ([Regex]::Match($templateFile, ".+_([0-9.]+)_to_([0-9.]+)\.sql\.template")).Groups[2].Value

        # Run the upgrade sql file
        Write-Host ""
        Write-Host "Running upgrade script: $templateFile"
        $output = Invoke-Expression "db2.exe -stvf ""$templateFile""" | Out-String
        $rc = $LASTEXITCODE
        Write-Host $output

        # Error handling
        if ($rc -gt 2) {
            Write-Host ""
            Write-Host "ERROR  : script ${templateFile} failed with rc=${rc}."
            Write-Host "CAUSE  : likely due to unexpected issues in base DB '$baseDBName' schame '$baseDBSchema'."
            Write-Host "STATUS : the base DB remains at version ${lastVersion}."
            Write-Host "Recommendation: review the output above and fix any issues in the database, then re-run the upgrade."
            Run-DB2Cmd "connect reset" | Out-Null
            exit $rc
        }

        # Commit the version upgrade in base DB if base_options table exists
        $output = Run-DB2Cmd "SELECT 1 FROM SYSIBM.SYSTABLES WHERE TYPE='T' AND UPPER(CREATOR)='$baseDBSchema' AND UPPER(NAME)='BASE_OPTIONS'"
        if ($output) {
            Run-DB2Cmd "UPDATE base_options SET schema_version='${thisVersion}'"
        }
    }

    # Close the connection
    Run-DB2Cmd "connect reset" | Out-Null
}

function Run-TenantDBUpgradeTemplates($baseDBName, $baseDBSchema, $tenantDBName, $tenantDBSchema, [string[]]$templateFiles) {
    # Run the tenant DB sql templates. This function will connect to the database
    # Usage:
    #   Run-TenantDBUpgradeTemplates <$baseDBName> <$baseDBSchema> <$tenantDBName> <$tenantDBSchema> <$template_files>
    # Arguments:
    #   baseDBName - the base database name
    #   baseDBSchema - the base schema
    #   tenantDBName - the tenant DB name
    #   tenantDBSchema - the tenant DB schema
    #   templateFiles - a list of template files to run

    if ($templateFiles -eq $null -or $templateFiles.Count -eq 0) {
        Write-Host "No upgrade template to run."
        return
    }

    $baseDBSchema = $baseDBSchema.ToUpper()

    $lastVersion = ""
    foreach ($templateFile in $templateFiles) {
        # Track the versions
        if (! $lastVersion) {
            $lastVersion = ([Regex]::Match($templateFile, ".+_([0-9.]+)_to_([0-9.]+)\.sql\.template")).Groups[1].Value
        }
        $thisVersion = ([Regex]::Match($templateFile, ".+_([0-9.]+)_to_([0-9.]+)\.sql\.template")).Groups[2].Value

        # Connect to the database
        Run-DB2Cmd "connect to $tenantDBName" | Out-Null
        Run-DB2Cmd "set schema $tenantDBSchema" | Out-Null

        # Run the upgrade sql file
        Write-Host ""
        Write-Host "Running upgrade script: $templateFile"
        $output = Invoke-Expression "db2.exe -stvf ""$templateFile""" | Out-String
        $rc = $LASTEXITCODE
        Write-Host $output

        # Disconnect from the tenant DB
        Run-DB2Cmd "connect reset" | Out-Null

        # Error handling
        if ($rc -gt 2) {
            Write-Host ""
            Write-Host "ERROR  : script ${templateFile} failed with rc=${rc}."
            Write-Host "CAUSE  : likely due to unexpected issues in tenant DB '$tenantDBName' schame '$tenantDBSchema'."
            Write-Host "STATUS : the tenant DB remains at version ${lastVersion}."
            Write-Host "Recommendation: review the output above and fix any issues in the database, then re-run the upgrade."
            exit $rc
        }

        # Commit the version upgrade in base DB if base_options table exists
        Set-TenantDBVersion $baseDBName $baseDBSchema $tenantDBName $tenantDBSchema $thisVersion
    }
}

function Run-UpgradeBaseDB {
    # Main function for base DB upgrade

    $releaseSchemaVersion = Get-ReleaseSchemaVersion
    Write-Host ""
    Write-Host "This script will upgrade your base DB to $releaseSchemaVersion"
    Write-Host ""

    $baseDBName = Prompt-Input "Please enter the base database name"
    $baseDBSchema = Prompt-Input "Please enter the base database user name"

    Write-Host "Checking the base DB version ..."
    $baseDBVersion = Get-BaseDBVersion $baseDBName $baseDBSchema

    if ( $baseDBVersion -eq $releaseSchemaVersion ) {
        Write-Host "Base DB schema version ${baseDBVersion} is already up-to-date."
        exit 0
    }

    $templateFiles = Get-UpgradeTemplates 'UpgradeBaseDB' $baseDBVersion $releaseSchemaVersion

    Write-Host ""
    Write-Host "-- Please confirm these are the desired settings:"
    Write-Host " - Base database name: $baseDBName"
    Write-Host " - Base database user name: $baseDBSchema"
    Write-Host ""

    Write-Host "Will run the following scripts to upgrade base DB from $baseDBVersion to $releaseSchemaVersion :"
    foreach ($templateFile in $templateFiles) {
        Write-Host $templateFile
    }
    Write-Host ""

    $confirm = Prompt-Input "Would you like to continue?" "confirm"
    if (! $confirm) {
        exit 0
    }

    Run-BaseDBUpgradeTemplates $baseDBName $baseDBSchema $templateFiles
    Set-BaseDBVersion $baseDBName $baseDBSchema $releaseSchemaVersion
    Write-Host ""
    Write-Host "Script completed."
    Write-Host ""
}

function Run-UpgradeTenantDB() {
    # Main function for tenant DB upgrade

    $releaseSchemaVersion = Get-ReleaseSchemaVersion
    Write-Host ""
    Write-Host "This script will upgrade your base DB to $releaseSchemaVersion"
    Write-Host ""

    $baseDBName = Prompt-Input "Please enter the base database name"
    $baseDBSchema = Prompt-Input "Please enter the base database user name"
    $tenantDBName = Prompt-Input "Please enter the tenant database name"
    $tenantDBSchema = Prompt-Input "Please enter the ontology"

    Write-Host "Checking the tenant DB version ..."
    $tenantDBVersion = Get-TenantDBVersion $baseDBName $baseDBSchema $tenantDBName $tenantDBSchema

    if ( $tenantDBVersion -eq $releaseSchemaVersion ) {
        Write-Host "Tenant DB schema version ${tenantDBVersion} is already up-to-date."
        exit 0
    }

    $templateFiles = Get-UpgradeTemplates 'UpgradeTenantDB' $tenantDBVersion $releaseSchemaVersion

    Write-Host ""
    Write-Host "-- Please confirm these are the desired settings:"
    Write-Host " - Base database name: $baseDBName"
    Write-Host " - Base database user name: $baseDBSchema"
    Write-Host " - Tenant database name: $tenantDBName"
    Write-Host " - Ontology: $tenantDBSchema"
    Write-Host ""

    Write-Host "Will run the following scripts to upgrade the tenant from $tenantDBVersion to $releaseSchemaVersion :"
    foreach ($templateFile in $templateFiles) {
        Write-Host $templateFile
    }
    Write-Host ""

    $confirm = Prompt-Input "Would you like to continue?" "confirm"
    if (! $confirm) {
        exit 0
    }

    Run-TenantDBUpgradeTemplates $baseDBName $baseDBSchema $tenantDBName $tenantDBSchema $templateFiles
    Set-TenantDBVersion $baseDBName $baseDBSchema $tenantDBName $tenantDBSchema $releaseSchemaVersion
    Write-Host ""
    Write-Host "Script completed."
    Write-Host ""
}
