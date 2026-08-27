# Content Cortex AI Services Reference

This document provides comprehensive guidance for deploying IBM Content Cortex AI Services with multi-provider AI model support.

## Table of Contents

- [Overview](#overview)
- [Supported AI Providers](#supported-ai-providers)
- [Architecture](#architecture)
- [Property File Format](#property-file-format)
- [Deployment Workflows](#deployment-workflows)
  - [Standalone Script Execution](#standalone-script-execution)
  - [Integration with CP4BA Scripts](#integration-with-cp4ba-scripts)
- [IBM Knowledge Center Documentation Guide](#ibm-knowledge-center-documentation-guide)
  - [For KC: New CP4BA Deployment with AI Services](#for-kc-new-cp4ba-deployment-with-ai-services)
  - [For KC: Updating Existing CP4BA Deployment to Add AI Services](#for-kc-updating-existing-cp4ba-deployment-to-add-ai-services)
  - [For KC: Upgrading AI Services Configuration (Standalone)](#for-kc-upgrading-ai-services-configuration-standalone)
  - [For KC: SSL Certificate Requirements (WatsonX LWE)](#for-kc-ssl-certificate-requirements-watsonx-lwe)
  - [For KC: Multi-Provider Configuration](#for-kc-multi-provider-configuration)
  - [For KC: Common Configuration Errors](#for-kc-common-configuration-errors)
- [Execution Flows](#execution-flows)
  - [Flow 1: Standalone Property Mode](#flow-1-standalone-property-mode)
  - [Flow 2: Standalone Generate Mode](#flow-2-standalone-generate-mode)
  - [Flow 3: CP4BA Prerequisites Integration (Property Mode)](#flow-3-cp4ba-prerequisites-integration-property-mode)
  - [Flow 4: CP4BA Prerequisites Integration (Generate Mode)](#flow-4-cp4ba-prerequisites-integration-generate-mode)
  - [Flow 5: SSL Certificate Validation (Detailed)](#flow-5-ssl-certificate-validation-detailed)
  - [Flow 6: JSON Key Generation (Secret Format)](#flow-6-json-key-generation-secret-format)
  - [Flow 7: Folder Cleanup (Re-run Behavior)](#flow-7-folder-cleanup-re-run-behavior)
  - [Flow 8: Error Scenarios and Handling](#flow-8-error-scenarios-and-handling)
- [Provider Configuration Examples](#provider-configuration-examples)
  - [WatsonX.ai SaaS](#watsonxai-saas)
  - [WatsonX.ai Lightweight Engine](#watsonxai-lightweight-engine)
  - [Microsoft Azure OpenAI](#microsoft-azure-openai)
  - [Multi-Provider Configuration](#multi-provider-configuration)
- [Generated Artifacts](#generated-artifacts)
- [Script Reference](#script-reference)
- [Troubleshooting](#troubleshooting)

---

## Overview

Content Cortex AI Services enables AI-powered capabilities in IBM Cloud Pak for Business Automation. The deployment setup supports multiple AI model providers simultaneously, allowing for:

- **Provider redundancy**: Fallback to alternate providers if primary fails
- **Model diversity**: Use different models for different tasks
- **Hybrid deployments**: Mix cloud and on-premises AI services

**Key Features:**
- Multi-provider support (WatsonX SaaS, WatsonX LWE, Microsoft Azure OpenAI)
- Interactive property file generation
- Automated secret and Custom Resource (CR) creation
- Integration with CP4BA deployment scripts

---

## Supported AI Providers

| Provider | Type | Authentication | Use Case |
|----------|------|----------------|----------|
| **WatsonX.ai SaaS** | Cloud | Username + API Key | IBM Cloud-based AI services |
| **WatsonX.ai Lightweight Engine (LWE)** | On-Premises | Username + API Key (preferred) or Password | Self-hosted AI in OpenShift |
| **Microsoft Azure OpenAI** | Cloud | Username + API Key | Azure-based AI services via Foundry |

---

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│  cp4a-content-cortex-ai-services-setup.sh                   │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │  Property Mode   │         │  Generate Mode   │          │
│  │  (-m property)   │────────▶│  (-m generate)   │          │
│  └──────────────────┘         └──────────────────┘          │
│         │                              │                     │
│         ▼                              ▼                     │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │ Property File    │         │ Secret + CR      │          │
│  │ (TOML-like)      │         │ Generation       │          │
│  └──────────────────┘         └──────────────────┘          │
└─────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
                        ┌────────────────────────────┐
                        │  Kubernetes Resources:     │
                        │  - ibm-providers-config-   │
                        │    secret (JSON)           │
                        │  - CCXAIServices CR        │
                        └────────────────────────────┘
```

### Execution Modes

1. **Property Mode** (`-m property`):
   - Interactive prompts for provider configuration
   - Generates property file with all settings
   - Supports multiple providers in single file

2. **Generate Mode** (`-m generate`):
   - Reads property file
   - Generates Kubernetes secret with provider configurations
   - Generates Custom Resource for deployment

### Integration Points

- **cp4a-prerequisites.sh**: Calls during prerequisites setup
- **cp4a-deployment.sh**: Calls during CR generation phase
- **Standalone**: Direct execution for AI Services-only deployments

---

## Property File Format

The property file uses a TOML-like format with provider sections and nested model arrays.

### Structure

```toml
# Common Configuration (applies to all providers)
[COMMON]
ENABLE_REDIS=false
SLOW_STORAGE_CLASSNAME=ocs-storagecluster-cephfs
BLOCK_STORAGE_CLASSNAME=ocs-storagecluster-ceph-rbd

# Provider 1 Configuration (WatsonX SaaS)
[PROVIDER_1]
PROVIDER_ID=watsonx_a1b2
ENABLED=true
PROVIDER_NAME=watsonx_saas
PROVIDER_URL=https://us-south.ml.cloud.ibm.com
API_KEY=<Required>
SPACE_ID=<Optional>
PROJECT_ID=<Optional>
SSL_ENABLED=false
TLS_CERT_LOCATION=

# Model 1 for Provider 1
[[PROVIDER_1.MODELS]]
MODEL_ID=openai/gpt-oss-120b
DEFAULT=false
TEMPERATURE=0.7
MAX_TOKENS=2048
TOP_P=1.0
TOP_K=50
CONTEXT_WINDOW_TOKEN_LIMIT=131072

# Model 2 for Provider 1
[[PROVIDER_1.MODELS]]
MODEL_ID=openai/gpt-oss-70b
DEFAULT=false
TEMPERATURE=0.5
MAX_TOKENS=1024
TOP_P=1.0
TOP_K=50
CONTEXT_WINDOW_TOKEN_LIMIT=131072

# Provider 2 Configuration (Azure OpenAI)
[PROVIDER_2]
PROVIDER_ID=azure_c3d4
ENABLED=true
PROVIDER_NAME=azure
PROVIDER_URL=https://mycompany.openai.azure.com
API_KEY=<Required>
SSL_ENABLED=false
TLS_CERT_LOCATION=

# Model for Provider 2
[[PROVIDER_2.MODELS]]
MODEL_ID=gpt-4
DEFAULT=true
TEMPERATURE=0.7
MAX_TOKENS=4096
TOP_P=1.0
TOP_K=50
CONTEXT_WINDOW_TOKEN_LIMIT=272000
```

### Property Descriptions

#### Common Section

| Property | Required | Description | Default |
|----------|----------|-------------|---------|
| `ENABLE_REDIS` | Yes | Enable Redis for token caching | `false` |
| `SLOW_STORAGE_CLASSNAME` | Yes | Storage class for persistent volumes | - |
| `BLOCK_STORAGE_CLASSNAME` | Conditional | Required if Redis enabled | - |

#### Provider Section

| Property | Required | Providers | Description |
|----------|----------|-----------|-------------|
| `PROVIDER_ID` | Yes | All | Unique identifier for this provider (auto-generated) |
| `ENABLED` | Yes | All | Enable/disable provider (`true`/`false`). At least one must be enabled |
| `PROVIDER_NAME` | Yes | All | Provider type: `watsonx_saas`, `watsonx_lightweightengine`, or `azure` |
| `PROVIDER_URL` | Yes | All | API endpoint URL |
| `USERNAME` | Yes | All | Username for Provider authentication |
| `API_KEY` | Yes | All | Authentication API key (required for all providers) |
| `PASSWORD` | Conditional | LWE only | Alternative to API_KEY for LWE (API_KEY preferred) |
| `SPACE_ID` | Optional | SaaS only | WatsonX deployment space ID |
| `PROJECT_ID` | Optional | SaaS only | WatsonX project ID |
| `SSL_ENABLED` | Conditional | LWE only | Enable SSL/TLS certificate validation (`true`/`false`). Required for LWE with self-signed certificates |
| `TLS_CERT_LOCATION` | Conditional | LWE only | Path to SSL certificate folder. Certificate file must be named `lwe.crt`. Required if `SSL_ENABLED=true` |

**Provider Control:**
- Set `ENABLED=false` to temporarily disable a provider without deleting its configuration
- Disabled providers are skipped during secret generation
- At least one provider must have `ENABLED=true`

#### Model Section

| Property | Required | Description | Default |
|----------|----------|-------------|---------|
| `MODEL_ID` | Yes | Model identifier from provider | - |
| `DEFAULT` | Yes | Set to `true` for the active/default model. **Only ONE model across ALL providers can be `true`** | `false` |
| `TEMPERATURE` | Optional | Sampling temperature (0.0-1.0) | `0.7` |
| `MAX_TOKENS` | Optional | Maximum tokens for completion | `2048` |
| `TOP_P` | Optional | Top-p (nucleus sampling) parameter | `1.0` |
| `TOP_K` | Optional | Top-k sampling parameter | `50` |
| `CONTEXT_WINDOW_TOKEN_LIMIT` | Optional | Maximum context window size in tokens | `131072` (WatsonX), `272000` (Azure) |

**Model Selection:**
- Exactly one model across all enabled providers must have `DEFAULT=true`
- The model with `DEFAULT=true` becomes the `active_llm` in the deployment
- Validation will fail if zero or multiple models have `DEFAULT=true`
- To change the default model, set the current default to `false` and set a different model to `true`

---

## Deployment Workflows

### Standalone Script Execution

Use this workflow for AI Services-only deployments or testing.

#### Step 1: Generate Property File

```bash
cd /path/to/cert-kubernetes/scripts
./cp4a-content-cortex-ai-services-setup.sh -m property -n <namespace>
```

**Interactive Prompts:**
1. Number of providers to configure (1-3)
2. Provider type selection (multi-select)
3. For each provider:
   - Provider-specific configuration (URL, credentials)
   - Model configuration (ID, name, parameters)
4. Common configuration (Redis, storage classes)

**Output:**
- Property file: `cp4ba-prerequisites/propertyfile/cp4ba_ai_services.property`

#### Step 2: Review and Edit Property File

```bash
vi cp4ba-prerequisites/propertyfile/cp4ba_ai_services.property
```

**Common Edits:**
- Add additional models (copy existing `[[PROVIDER_N.models]]` sections)
- Update API keys and credentials
- Adjust model parameters (temperature, max_tokens)

#### Step 3: Generate Resources

```bash
./cp4a-content-cortex-ai-services-setup.sh -m generate -n <namespace>
```

**Output:**
- Secret: `cp4ba-prerequisites/secret_template/ibm-providers-config-secret.yaml`
- CR: `cp4ba-prerequisites/generated-cr/ibm_content_cortex_ai_services_cr_final.yaml`

**Messages:**
```
[INFO] Generate Mode: Creating secrets and custom resources
[INFO] Validating property file: <path>
[SUCCESS] Property file validated successfully
[SUCCESS] Created Content Cortex AI Services secret template
[INFO] Generating the Content Cortex AI Services Custom Resource File...
[SUCCESS] Content Cortex AI Services Custom Resource generated successfully
[SUCCESS] Generate mode completed successfully!
[INFO] Generated artifacts:
  - Secret: <path>
  - CR: <path>
```

---

### Integration with CP4BA Scripts

#### cp4a-prerequisites.sh Integration

The prerequisites script handles secret generation during the prerequisites phase.

**Flow:**
1. User selects "Content Cortex AI Services" pattern
2. Script prompts for property file generation or uses existing
3. Property file is validated
4. Secret is generated (CR generation deferred to deployment phase)

**Usage:**
```bash
./cp4a-prerequisites.sh -m property -n <namespace>
# Select Content Cortex AI Services when prompted
```

#### cp4a-deployment.sh Integration

The deployment script handles CR generation during the deployment phase.

**Flow:**
1. Script detects Content Cortex AI Services pattern
2. Reads property file
3. Generates CR with storage classes from user profile
4. Includes CR in final deployment package

**Usage:**
```bash
./cp4a-deployment.sh -n <namespace>
```

---

## IBM Knowledge Center Documentation Guide

This section provides guidance for IBM Knowledge Center (KC) documentation writers on what information should be included in the official product documentation. The content below is structured to help end users understand how to deploy Content Cortex AI Services in different scenarios.

---

### For KC: New CP4BA Deployment with AI Services

**Section Title**: "Deploying Content Cortex AI Services with Cloud Pak for Business Automation"

**Prerequisites to Document**:
- OpenShift cluster with CP4BA operator installed
- Sufficient storage (file and block storage classes)
- Access to AI provider (WatsonX.ai SaaS, WatsonX.ai LWE, or Microsoft Azure OpenAI)
- API keys or credentials for chosen AI provider(s)
- For WatsonX LWE with self-signed certificates: SSL certificate file

**Step 1: Run Prerequisites Script**

Document that users should run:
```bash
./cp4a-prerequisites.sh -m property -n <namespace>
```

**Important Points to Include**:

1. **AI Services Selection Question**:
   - During the prerequisites script execution, users will be asked:
     ```
     Do you want to deploy Content Cortex AI Services as a part of the Content Cortex Essentials? (Yes/No, default: No):
     ```
   - Users should answer **Yes** to enable AI Services setup

2. **Provider Selection (Multi-Select)**:
   - After selecting AI Services, users will see a multi-select menu:
     ```
     Select AI provider types (use SPACE to select, ENTER to confirm):
     [ ] WatsonX.ai SaaS
     [ ] WatsonX.ai Lightweight Engine (LWE)
     [ ] Microsoft Azure OpenAI (Foundry)
     ```
   - Users can select **one or more providers** (1-3 total)
   - Use SPACE bar to select/deselect
   - Press ENTER to confirm selection

3. **Provider Configuration**:
   - For each selected provider, default configuration will be set
   - Users will need to edit the property file later with actual credentials

4. **Property File Location**:
   - AI Services property file is generated at:
     ```
     cp4ba-prerequisites/propertyfile/cp4ba_ai_services.property
     ```
   - This is in the **same folder** as other CP4BA property files:
     - `cp4ba_user_profile.property`
     - `cp4ba_db_server.property`
     - `cp4ba_db_name_user.property`
     - `cp4ba_LDAP.property`

**Step 2: Edit Property File**

Document that users must edit `cp4ba_ai_services.property` to:

1. **Replace `<Required>` placeholders** with actual values:
   - `API_KEY`: Provider API key
   - `PROVIDER_URL`: Provider endpoint URL
   - For WatsonX SaaS: `PROJECT_ID` or `SPACE_ID`
   - For WatsonX LWE: `USERNAME`

2. **Configure SSL for WatsonX LWE** (if using self-signed certificates):
   - Set `SSL_ENABLED=true`
   - Set `TLS_CERT_LOCATION` to the certificate folder path
   - **Place certificate file** as `lwe.crt` in the specified folder
   - Example location: `cp4ba-prerequisites/propertyfile/cert/aiservices/lwe.crt`

3. **Set Default Model**:
   - Exactly **one model** across all providers must have `DEFAULT=true`
   - This becomes the active model for AI Services

4. **Configure Redis** (optional):
   - Set `ENABLE_REDIS=true` for token caching (improves performance)
   - Requires block storage class in user profile

**Step 3: Continue with CP4BA Setup**

Document that the rest of the CP4BA setup **remains unchanged**:

1. **Edit Other Property Files**:
   - `cp4ba_user_profile.property` (LDAP, storage classes, etc.)
   - `cp4ba_db_server.property` (database servers)
   - `cp4ba_db_name_user.property` (database names and users)
   - `cp4ba_LDAP.property` (LDAP configuration)

2. **Run Generate Mode**:
   ```bash
   ./cp4a-prerequisites.sh -m generate -n <namespace>
   ```
   
   **What Happens**:
   - All CP4BA secrets are generated (LDAP, database, etc.)
   - **AI Services secrets are generated** in the same step:
     - Provider configuration secret: `cp4ba-prerequisites/secret_template/aiservices/ibm-providers-config-secret.yaml`
     - SSL secret script (if LWE with SSL): `cp4ba-prerequisites/secret_template/aiservices/watsonx-lwe-ssl-secret.sh`
   - Database SQL scripts are generated
   - All artifacts are in the **same locations** as standard CP4BA deployment

3. **SSL Certificate Validation**:
   - If WatsonX LWE provider has `SSL_ENABLED=true`:
     - Script validates certificate exists at specified location
     - Script validates certificate is in valid PEM format
     - **Script fails with error** if certificate is missing or invalid
   - Users must place certificate before running generate mode

4. **Apply Secrets**:
   - Run the generated secret creation script:
     ```bash
     ./cp4ba-prerequisites/project/<namespace>/create_secret.sh
     ```
   - This creates **all secrets** including AI Services secrets

5. **Run Deployment Script**:
   ```bash
   ./cp4a-deployment.sh -n <namespace>
   ```
   
   **What Happens**:
   - All CP4BA Custom Resources are generated
   - **AI Services Custom Resource is generated** in the same step:
     - Location: `generated-cr/project/<namespace>/ibm_content_cortex_ai_services_cr_final.yaml`
   - CR includes storage classes from user profile
   - CR includes Redis configuration from AI Services property file

6. **Apply Custom Resources**:
   - Apply the generated CRs to deploy CP4BA with AI Services

**Key Points to Emphasize**:
- AI Services setup is **integrated** into standard CP4BA workflow
- Property file is in the **same folder** as other property files
- Secrets are generated in the **same step** as other secrets
- CR is generated in the **same step** as other CRs
- No separate deployment steps required for AI Services

---

### For KC: Updating Existing CP4BA Deployment to Add AI Services

**Section Title**: "Adding Content Cortex AI Services to an Existing CP4BA Deployment"

**Use Case**:
- CP4BA is already deployed
- User wants to add AI Services as a new component
- User wants to add Content pattern (if not already deployed) with AI Services

**Prerequisites to Document**:
- Existing CP4BA deployment
- Access to deployment namespace
- AI provider credentials
- For WatsonX LWE with SSL: Certificate file
- Existing property files from original deployment

**Using --update-components Flag**

Document that users should use the **--update-components flag** with prerequisites script:

**Step 1: Run Prerequisites Script with Update Flag**

```bash
./cp4a-prerequisites.sh -m property -n <namespace> --update-components
```

**What Happens**:
1. **Component Selection**:
   - Script displays existing components
   - User can add new components (including Content pattern if not present)
   - If Content pattern is selected (existing or new), AI Services question appears

2. **AI Services Selection Question**:
   - Same as new deployment:
     ```
     Do you want to deploy Content Cortex AI Services as a part of the Content Cortex Essentials? (Yes/No, default: No):
     ```
   - Users should answer **Yes** to enable AI Services setup

3. **Provider Selection (Multi-Select)**:
   - Same multi-select menu as new deployment:
     ```
     Select AI provider types (use SPACE to select, ENTER to confirm):
     [ ] WatsonX.ai SaaS
     [ ] WatsonX.ai Lightweight Engine (LWE)
     [ ] Microsoft Azure OpenAI (Foundry)
     ```
   - Select one or more providers (1-3)

4. **Property File Generated**:
   - Location: `cp4ba-prerequisites/propertyfile/cp4ba_ai_services.property`
   - Same folder as existing property files
   - Contains default configuration for selected providers

**Step 2: Edit Property File**

Same as new deployment - edit `cp4ba_ai_services.property` to:
- Replace `<Required>` placeholders with actual values
- Configure SSL for LWE (if needed)
- Set default model (exactly one)
- Configure Redis (optional)

**Step 3: Continue with CP4BA Update**

Document that the rest of the update workflow **remains unchanged**:

1. **Edit Other Property Files** (if needed):
   - Update existing property files for new components
   - AI Services property file is treated like any other component

2. **Run Generate Mode**:
   ```bash
   ./cp4a-prerequisites.sh -m generate -n <namespace>
   ```
   
   **What Happens**:
   - All CP4BA secrets are generated (including new components)
   - **AI Services secrets are generated** in the same step:
     - Provider configuration secret
     - SSL secret script (if LWE with SSL)
   - All artifacts in same locations as standard CP4BA

3. **Apply Secrets**:
   ```bash
   ./cp4ba-prerequisites/project/<namespace>/create_secret.sh
   ```
   - Creates all secrets including AI Services secrets

4. **Run Deployment Script**:
   ```bash
   ./cp4a-deployment.sh -n <namespace>
   ```
   
   **What Happens**:
   - All CP4BA Custom Resources are updated/generated
   - **AI Services Custom Resource is generated** in the same step
   - CR includes storage classes from user profile
   - CR includes Redis configuration

5. **Apply Custom Resources**:
   - Apply the generated/updated CRs to update CP4BA with AI Services

**Key Points to Emphasize**:
- Use `--update-components` flag to add AI Services to existing deployment
- AI Services setup is **integrated** into standard CP4BA update workflow
- Same questions and property file format as new deployment
- Secrets and CR generated in same steps as other components
- No separate update steps required for AI Services

---

### For KC: Upgrading AI Services Configuration (Standalone)

**Section Title**: "Upgrading or Reconfiguring Content Cortex AI Services"

**Use Case**:
- CP4BA with AI Services is already deployed
- User wants to change AI provider configuration
- User wants to add/remove providers
- User wants to change model configuration
- User wants to update API keys or endpoints

**Prerequisites to Document**:
- Existing CP4BA deployment with AI Services
- Access to deployment namespace
- New AI provider credentials (if changing providers)
- For WatsonX LWE with SSL: Certificate file

**Standalone Script Execution for Upgrades**

Document that users should use the **standalone AI Services script** for configuration changes:

**Step 1: Generate New Property File**

```bash
cd /path/to/cert-kubernetes/scripts
./cp4a-content-cortex-ai-services-setup.sh -m property -n <namespace>
```

**What Happens**:
1. **Interactive Provider Selection**:
   - Multi-select menu appears
   - Select providers for new configuration (can be different from current)
   - Use SPACE to select, ENTER to confirm

2. **Property File Generated**:
   - Location: `cp4ba-prerequisites/propertyfile/cp4ba_ai_services.property`
   - **Overwrites existing property file** (if present)
   - Contains default configuration for selected providers

3. **SSL Certificate Folder Created** (if LWE selected):
   - Location: `cp4ba-prerequisites/propertyfile/cert/aiservices`
   - Users must place `lwe.crt` file here if using SSL

**Step 2: Edit Property File**

Edit property file with new configuration:
- Update API keys, endpoints, or credentials
- Add/remove providers
- Change model configuration
- Update default model selection
- Configure SSL for LWE (if needed)
- Update Redis configuration (if needed)

**Step 3: Generate New Secrets and CR**

```bash
./cp4a-content-cortex-ai-services-setup.sh -m generate -n <namespace>
```

**What Happens**:
1. **Property File Validation**:
   - Validates new configuration
   - Validates at least one enabled provider
   - Validates exactly one default model
   - Validates SSL certificates (if LWE with SSL enabled)

2. **Secrets Generated**:
   - Provider configuration secret: `cp4ba-prerequisites/secret_template/aiservices/ibm-providers-config-secret.yaml`
   - SSL secret script (if needed): `cp4ba-prerequisites/secret_template/aiservices/watsonx-lwe-ssl-secret.sh`
   - **Overwrites existing secrets** with new configuration

3. **Custom Resource Generated**:
   - Location: `generated-cr/project/<namespace>/ibm_content_cortex_ai_services_cr_final.yaml`
   - **Overwrites existing CR** with new configuration

**Step 4: Apply New Secrets**

```bash
# Delete old provider configuration secret
oc delete secret ibm-providers-config-secret -n <namespace>

# Apply new provider configuration secret
oc apply -f cp4ba-prerequisites/secret_template/aiservices/ibm-providers-config-secret.yaml -n <namespace>

# If SSL secret exists and changed, delete and recreate
oc delete secret watsonx-lwe-ssl-secret -n <namespace> 2>/dev/null || true
bash cp4ba-prerequisites/secret_template/aiservices/watsonx-lwe-ssl-secret.sh
```

**Step 5: Apply Updated Custom Resource**

```bash
oc apply -f generated-cr/project/<namespace>/ibm_content_cortex_ai_services_cr_final.yaml -n <namespace>
```

**What Happens After Applying**:
- AI Services pods will restart with new configuration
- New provider configuration takes effect
- Existing data and settings are preserved

**Key Points to Emphasize**:
- Use standalone script for configuration upgrades
- Property file and secrets are overwritten with new configuration
- Must delete old secrets before applying new ones
- AI Services pods restart automatically after CR update
- Can be used for any configuration change (providers, models, credentials)

---

### For KC: SSL Certificate Requirements (WatsonX LWE)

**Section Title**: "Configuring SSL Certificates for WatsonX Lightweight Engine"

**When SSL is Required**:
- WatsonX LWE is deployed with self-signed certificates
- Certificate validation is needed for secure communication

**Certificate Requirements**:
1. **Format**: PEM format (Base64-encoded X.509)
2. **File Name**: Must be named `lwe.crt`
3. **Location**: Place in folder specified by `TLS_CERT_LOCATION` property
4. **Default Location**: `cp4ba-prerequisites/propertyfile/cert/aiservices/lwe.crt`

**Configuration Steps**:

1. **Obtain Certificate**:
   - Export certificate from WatsonX LWE deployment
   - Ensure it's in PEM format
   - Save as `lwe.crt`

2. **Configure Property File**:
   ```toml
   [PROVIDER_1]
   PROVIDER_NAME=watsonx_lightweightengine
   SSL_ENABLED=true
   TLS_CERT_LOCATION=/path/to/cert-kubernetes/scripts/cp4ba-prerequisites/propertyfile/cert/aiservices
   ```

3. **Place Certificate**:
   - Copy `lwe.crt` to the `TLS_CERT_LOCATION` folder
   - Ensure file is readable

4. **Validation**:
   - During generate mode, script validates:
     - Certificate file exists
     - Certificate is in valid PEM format
     - Certificate is readable
   - **Script fails** if validation fails

**Generated SSL Secret**:
- Secret name: `watsonx-lwe-ssl-secret`
- Contains certificate mounted at: `/etc/certs/lwe/tls.crt`
- Automatically mounted in AI Services pods
- Labeled for backup: `cp4ba.ibm.com/backup-type=mandatory`

**Troubleshooting**:
- If certificate validation fails, check:
  - File exists at specified location
  - File is named `lwe.crt`
  - File is in PEM format
  - File has read permissions

---

### For KC: Multi-Provider Configuration

**Section Title**: "Configuring Multiple AI Providers"

**Use Case**:
- Use multiple AI providers for redundancy
- Use different models for different tasks
- Mix cloud and on-premises AI services

**Supported Combinations**:
- WatsonX SaaS + WatsonX LWE
- WatsonX SaaS + Azure OpenAI
- WatsonX LWE + Azure OpenAI
- All three providers together

**Configuration Guidelines**:

1. **Provider Selection**:
   - Select multiple providers during setup
   - Each provider gets unique ID (auto-generated)
   - Each provider can have multiple models

2. **Default Model Selection**:
   - **Exactly one model** across all providers must have `DEFAULT=true`
   - This becomes the active model
   - Other models are available but not default

3. **Provider Priority** (for default model):
   - Recommended priority: Azure > WatsonX SaaS > WatsonX LWE
   - Script suggests Azure model as default if selected

4. **Example Configuration**:
   ```toml
   # Provider 1: WatsonX SaaS
   [PROVIDER_1]
   PROVIDER_ID=watsonx_a1b2
   ENABLED=true
   PROVIDER_NAME=watsonx_saas
   
   [[PROVIDER_1.MODELS]]
   MODEL_ID=openai/gpt-oss-120b
   DEFAULT=false
   
   # Provider 2: Azure OpenAI
   [PROVIDER_2]
   PROVIDER_ID=azure_c3d4
   ENABLED=true
   PROVIDER_NAME=azure
   
   [[PROVIDER_2.MODELS]]
   MODEL_ID=gpt-4
   DEFAULT=true  # This is the active model
   ```

**Key Points to Emphasize**:
- Multiple providers provide redundancy
- Only one default model across all providers
- Each provider can be enabled/disabled independently
- Disabled providers are skipped during deployment

---

### For KC: Common Configuration Errors

**Section Title**: "Troubleshooting Content Cortex AI Services Setup"

Document common errors and resolutions:

1. **Error: No enabled providers**
   - **Cause**: All providers have `ENABLED=false`
   - **Resolution**: Set `ENABLED=true` for at least one provider

2. **Error: No default model**
   - **Cause**: No model has `DEFAULT=true`
   - **Resolution**: Set `DEFAULT=true` for exactly one model

3. **Error: Multiple default models**
   - **Cause**: Multiple models have `DEFAULT=true`
   - **Resolution**: Set `DEFAULT=false` for all but one model

4. **Error: SSL certificate missing**
   - **Cause**: LWE provider has `SSL_ENABLED=true` but certificate not found
   - **Resolution**: Place `lwe.crt` file in `TLS_CERT_LOCATION` folder

5. **Error: SSL certificate invalid**
   - **Cause**: Certificate is not in valid PEM format
   - **Resolution**: Verify certificate format, re-export if needed

6. **Error: Redis enabled but no block storage**
   - **Cause**: `ENABLE_REDIS=true` but `CP4BA_BLOCK_STORAGE_CLASS_NAME` not set
   - **Resolution**: Set block storage class in user profile property file

---

## Execution Flows

This section documents all possible execution flows for Content Cortex AI Services setup, including validation, error handling, and artifact generation.

### Flow 1: Standalone Property Mode

**Command:**
```bash
./cp4a-content-cortex-ai-services-setup.sh -m property -n <namespace>
```

**Execution Steps:**
1. **Cleanup Phase**
   - Removes `WATSONX_SSL_CERT_FOLDER` (if exists)
   - Removes `AI_SERVICES_PROPERTY_FILE` (if exists)
   - Ensures fresh generation on each run

2. **Provider Selection**
   - Interactive multi-select menu for provider types
   - Supports 1-3 providers
   - Options: WatsonX SaaS, WatsonX LWE, Microsoft Azure OpenAI

3. **Provider Configuration**
   - For each selected provider:
     - Auto-generates unique `PROVIDER_ID`
     - Sets default values based on provider type
     - Configures default model with provider-specific parameters

4. **Property File Generation**
   - Creates directory structure if needed
   - Creates SSL certificate folder: `cp4ba-prerequisites/propertyfile/cert/aiservices`
   - Generates property file: `cp4ba-prerequisites/propertyfile/cp4ba_ai_services.property`
   - Includes comments and instructions

**Output:**
- Property file with TOML-like format
- SSL certificate folder (for LWE providers)
- Success message with next steps

---

### Flow 2: Standalone Generate Mode

**Command:**
```bash
./cp4a-content-cortex-ai-services-setup.sh -m generate -n <namespace>
```

**Execution Steps:**
1. **Cleanup Phase**
   - Removes `AI_SERVICES_SECRET_FOLDER` (if exists)
   - Removes `TEMP_FOLDER` (if exists)
   - Removes `FINAL_CR_FOLDER` (if exists)
   - Ensures fresh generation on each run

2. **Property File Validation**
   - Checks property file exists
   - Parses TOML-like format
   - Validates structure and syntax
   - Checks at least one enabled provider
   - Validates exactly one default model

3. **SSL Certificate Validation** (if LWE with SSL enabled)
   - Checks certificate file exists: `<TLS_CERT_LOCATION>/lwe.crt`
   - Validates certificate format (PEM)
   - Validates certificate is readable
   - **Fails with error if certificate missing or invalid**

4. **Secret Generation**
   - Creates secret folder: `cp4ba-prerequisites/secret_template/aiservices`
   - Generates provider configuration secret (JSON format)
   - Secret file: `ibm-providers-config-secret.yaml`
   - JSON keys format: `<provider_id>_<sanitized_model_id>`
     - Example: `watsonx_ibmgranite13bchatv2` (special chars removed from model_id)

5. **SSL Secret Generation** (if LWE with SSL enabled)
   - Generates SSL secret creation script
   - Script file: `watsonx-lwe-ssl-secret.sh`
   - Script creates Kubernetes secret from certificate file
   - Secret name: `watsonx-lwe-ssl-secret`

6. **Custom Resource Generation**
   - Creates CR folder structure
   - Generates CCXAIServices CR YAML
   - Includes storage class configuration
   - Includes Redis configuration (if enabled)
   - CR file: `generated-cr/project/<namespace>/ibm_content_cortex_ai_services_cr_final.yaml`

**Output:**
- Provider configuration secret (always)
- SSL secret script (conditional - only if LWE with SSL)
- Custom Resource YAML (always)
- Success message with artifact locations

---

### Flow 3: CP4BA Prerequisites Integration (Property Mode)

**Command:**
```bash
./cp4a-prerequisites.sh -m property -n <namespace>
```

**Execution Steps:**
1. **Pattern Selection**
   - User selects Content Cortex AI Services pattern
   - Script sets `SETUP_CONTENT_CORTEX_AI_SERVICES=true`

2. **Provider Selection**
   - Sources `cp4a-content-cortex-ai-services-setup.sh`
   - Calls `prompt_provider_types_multiselect()`
   - Stores provider configuration in global arrays

3. **Property File Generation**
   - Calls `generate_multi_provider_property_file("skip_storage")`
   - Skips storage class properties (handled by user profile)
   - Generates property file with provider configurations

4. **Continues with Other Prerequisites**
   - LDAP configuration
   - Database configuration
   - Other pattern-specific setup

**Output:**
- Property file: `cp4ba-prerequisites/propertyfile/cp4ba_ai_services.property`
- Integrated with other CP4BA property files

---

### Flow 4: CP4BA Prerequisites Integration (Generate Mode)

**Command:**
```bash
./cp4a-prerequisites.sh -m generate -n <namespace>
```

**Execution Steps:**
1. **Early Parsing Phase** (in `check_property_file()`)
   - **IMPORTANT**: Happens BEFORE SSL validation
   - Sources `cp4a-content-cortex-ai-services-setup.sh`
   - Calls `parse_multi_provider_property_file()`
   - Populates `PARSED_PROVIDERS` and `PARSED_MODELS` arrays
   - **Purpose**: Enables SSL validation to check AI Services certificates

2. **SSL Certificate Validation Phase**
   - Calls `validate_ssl_certificates()` (in common.sh)
   - Validates LDAP certificates (if SSL enabled)
   - Validates DB certificates (if SSL enabled)
   - **Validates AI Services certificates** (if LWE with SSL enabled)
     - Uses `PARSED_PROVIDERS` array populated in step 1
     - Checks each LWE provider with `SSL_ENABLED=true`
     - Validates certificate exists: `<TLS_CERT_LOCATION>/lwe.crt`
     - **Fails with error if certificate missing or invalid**

3. **Property File Validation Phase**
   - Checks for `<Required>` placeholders
   - Validates all property files
   - **Note**: AI Services property already parsed in step 1

4. **Secret Generation Phase**
   - Generates all CP4BA secrets
   - **AI Services Secret Generation**:
     - Calls `generate_multi_provider_secret()`
     - Creates provider configuration secret (JSON format)
     - Calls `create_watsonx_lwe_ssl_secret_template()`
     - Creates SSL secret script (if LWE with SSL enabled)

5. **Continues with Other Prerequisites**
   - Database SQL scripts
   - Other secret templates
   - Validation checks

**Output:**
- Provider configuration secret: `cp4ba-prerequisites/secret_template/aiservices/ibm-providers-config-secret.yaml`
- SSL secret script (conditional): `cp4ba-prerequisites/secret_template/aiservices/watsonx-lwe-ssl-secret.sh`
- Integrated with other CP4BA secrets

**Key Differences from Standalone:**
- No CR generation (deferred to deployment phase)
- Storage classes from user profile (not property file)
- Integrated validation with other CP4BA components

---

### Flow 5: SSL Certificate Validation (Detailed)

**Trigger Conditions:**
- LWE provider configured
- `ENABLED=true` for the provider
- `SSL_ENABLED=true` for the provider
- `TLS_CERT_LOCATION` specified

**Validation Steps:**
1. **Certificate File Check**
   - Expected location: `<TLS_CERT_LOCATION>/lwe.crt`
   - Checks file exists
   - Checks file is readable

2. **Certificate Format Validation**
   - Validates PEM format
   - Checks for valid certificate structure
   - Uses `check_ssl_cert()` function from common.sh

3. **Error Handling**
   - **Missing Certificate**:
     ```
     [✘] SSL certificate for WatsonX Lightweight Engine provider '<provider_id>' is missing at: <path>/lwe.crt
     ```
   - **Invalid Certificate**:
     ```
     [✘] SSL certificate for WatsonX Lightweight Engine provider '<provider_id>' is invalid at: <path>/lwe.crt
     ```
   - **Validation Failure**: Script exits with error code 1

4. **Success Path**
   - Certificate validated successfully
   - SSL secret script generated
   - Secret includes certificate mount path: `/etc/certs/lwe/tls.crt`

**Skip Conditions:**
- No LWE providers configured
- LWE provider has `ENABLED=false`
- LWE provider has `SSL_ENABLED=false`
- Message: "Skipping SSL certificate validation for AI Services - no WatsonX LWE providers with SSL enabled"

---

### Flow 6: JSON Key Generation (Secret Format)

**Key Format:**
```
<provider_id>_<sanitized_model_id>
```

**Sanitization Rules:**
- Remove forward slashes (`/`)
- Remove hyphens (`-`)
- Remove periods (`.`)
- Keep alphanumeric characters

**Examples:**
| Provider ID | Model ID | Generated Key |
|-------------|----------|---------------|
| `watsonx` | `openai/gpt-oss-120b` | `watsonx_openaigptoss120b` |
| `azure` | `gpt-5.4` | `azure_gpt54` |
| `watsonx_lwe` | `openai/gpt-oss-120b` | `watsonx_lwe_openaigptoss120b` |

**Implementation:**
```bash
sanitized_model_id=$(echo "$model_id" | tr -d '/-.')
llm_key="${provider_id}_${sanitized_model_id}"
```

**Purpose:**
- Valid JSON keys (no special characters)
- Unique identification of model configurations
- Consistent naming across deployments

---

### Flow 7: Folder Cleanup (Re-run Behavior)

**Property Mode Cleanup:**
```bash
rm -rf "$WATSONX_SSL_CERT_FOLDER"
rm -f "$AI_SERVICES_PROPERTY_FILE"
```
- Ensures fresh property file generation
- Removes old SSL certificate folder
- Prevents stale configuration

**Generate Mode Cleanup:**
```bash
rm -rf "$AI_SERVICES_SECRET_FOLDER"
rm -rf "$TEMP_FOLDER"
rm -rf "$FINAL_CR_FOLDER"
```
- Ensures fresh secret generation
- Removes old temporary files
- Removes old CR files
- Prevents artifact conflicts

**Benefits:**
- Clean slate on each run
- No leftover files from previous runs
- Consistent behavior
- Easier troubleshooting

---

### Flow 8: Error Scenarios and Handling

#### Scenario 1: Missing Property File
**Trigger:** Generate mode without property file

**Error:**
```
[✘] Property file not found: <path>
[✘] Please run property mode first: ./cp4a-content-cortex-ai-services-setup.sh -m property -n <namespace>
```

**Resolution:** Run property mode first

---

#### Scenario 2: No Enabled Providers
**Trigger:** All providers have `ENABLED=false`

**Error:**
```
[✘] At least one provider must be enabled (ENABLED=true)
[✘] Property file validation failed
```

**Resolution:** Set `ENABLED=true` for at least one provider

---

#### Scenario 3: No Default Model
**Trigger:** No model has `DEFAULT=true`

**Error:**
```
[✘] Exactly one model across all enabled providers must be selected as the default LLM model
[✘] No default model found. Please set DEFAULT=true for exactly one model in an enabled provider
```

**Resolution:** Set `DEFAULT=true` for exactly one model

---

#### Scenario 4: Multiple Default Models
**Trigger:** Multiple models have `DEFAULT=true`

**Error:**
```
[✘] Exactly one model across all enabled providers must be selected as the default LLM model
[✘] Found 2 models with DEFAULT=true:
[✘]   - Provider: watsonx_2ce0 (PROVIDER_1), Model: openai/gpt-oss-120b
[✘]   - Provider: azure_9aa4 (PROVIDER_3), Model: gpt-5.4
[✘] Please set DEFAULT=false for all but one model
```

**Resolution:** Set `DEFAULT=false` for all but one model

---

#### Scenario 5: Missing SSL Certificate
**Trigger:** LWE provider with `SSL_ENABLED=true` but certificate missing

**Error:**
```
[✘] SSL certificate for WatsonX Lightweight Engine provider 'watsonx_lwe' is missing at: /path/to/cert/aiservices/lwe.crt
```

**Resolution:**
1. Place certificate file as `lwe.crt` in `TLS_CERT_LOCATION`
2. Ensure file is readable
3. Re-run generate mode

---

#### Scenario 6: Invalid SSL Certificate
**Trigger:** LWE provider with `SSL_ENABLED=true` but certificate invalid

**Error:**
```
[✘] SSL certificate for WatsonX Lightweight Engine provider 'watsonx_lwe' is invalid at: /path/to/cert/aiservices/lwe.crt
```

**Resolution:**
1. Verify certificate is in PEM format
2. Verify certificate is not corrupted
3. Obtain valid certificate from LWE deployment
4. Re-run generate mode

---

## Provider Configuration Examples

### WatsonX.ai SaaS

**Single Model Configuration:**

```toml
[PROVIDER_1]
PROVIDER_TYPE=watsonx_saas
PROVIDER_NAME=watsonx_prod
PROVIDER_URL=https://us-south.ml.cloud.ibm.com
API_KEY=your-api-key-here
PROJECT_ID=your-project-id

[[PROVIDER_1.models]]
MODEL_ID=openai/gpt-oss-120b
MAX_TOKENS=2048
TEMPERATURE=0.7
```

**Generated Secret Entry:**
```json
{
  "active_llm": "watsonx_prod_granite_chat",
  "llms": {
    "watsonx_prod_granite_chat": {
      "provider": "watsonx",
      "deployment_mode": "saas",
      "url": "https://us-south.ml.cloud.ibm.com",
      "project_id": "your-project-id",
      "api_key": "your-api-key-here",
      "model": "openai/gpt-oss-120b",
      "max_completion_tokens": 2048,
      "temperature": 0.7
    }
  }
}
```

---

### WatsonX.ai Lightweight Engine

**With API Key:**

```toml
[PROVIDER_1]
PROVIDER_TYPE=watsonx_lightweightengine
PROVIDER_NAME=watsonx_lwe
PROVIDER_URL=https://cpd.mycompany.com
USERNAME=admin
API_KEY=your-api-key-here

[[PROVIDER_1.models]]
MODEL_ID=ibm/granite-13b-chat-v2
MAX_TOKENS=2048
TEMPERATURE=0.7
```

**With Password:**

```toml
[PROVIDER_1]
PROVIDER_TYPE=watsonx_lightweightengine
PROVIDER_NAME=watsonx_lwe
PROVIDER_URL=https://cpd.mycompany.com
USERNAME=admin
PASSWORD=your-password-here

[[PROVIDER_1.models]]
MODEL_ID=ibm/granite-13b-chat-v2
```

**With SSL Certificate (Self-Signed):**

```toml
[PROVIDER_1]
PROVIDER_TYPE=watsonx_lightweightengine
PROVIDER_NAME=watsonx_lwe
PROVIDER_URL=https://cpd.mycompany.com
USERNAME=admin
API_KEY=your-api-key-here
SSL_ENABLED=true
TLS_CERT_LOCATION=/path/to/cert-kubernetes/scripts/cp4ba-prerequisites/propertyfile/cert/aiservices

[[PROVIDER_1.models]]
MODEL_ID=ibm/granite-13b-chat-v2
MAX_TOKENS=2048
TEMPERATURE=0.7
CONTEXT_WINDOW_TOKEN_LIMIT=131072
```

**SSL Certificate Setup:**
1. Place your LWE certificate file as `lwe.crt` in the `TLS_CERT_LOCATION` folder
2. The certificate will be validated during generate mode
3. A separate SSL secret (`watsonx-lwe-ssl-secret`) will be created
4. The secret is automatically mounted in the deployment

**Generated Secret Entry (without SSL):**
```json
{
  "watsonx_lwe_granite_lwe": {
    "provider": "watsonx",
    "deployment_mode": "lightweight",
    "url": "https://cpd.mycompany.com",
    "instance_id": "openshift",
    "username": "admin",
    "api_key": "your-api-key-here",
    "model": "openai/gpt-oss-120b",
    "verify_ssl": false,
    "max_completion_tokens": 2048,
    "temperature": 0.7,
    "context_window_token_limit": 131072
  }
}
```

**Generated Secret Entry (with SSL):**
```json
{
  "watsonx_lwe_granite_lwe": {
    "provider": "watsonx",
    "deployment_mode": "lightweight",
    "url": "https://cpd.mycompany.com",
    "instance_id": "openshift",
    "username": "admin",
    "api_key": "your-api-key-here",
    "version": "5.3",
    "verify_ssl": "/etc/certs/lwe/tls.crt",
    "ssl_secret_name": "watsonx-lwe-ssl-secret",
    "model": "openai/gpt-oss-120b",
    "max_completion_tokens": 2048,
    "temperature": 0.7,
    "context_window_token_limit": 131072
  }
}
```

**Generated SSL Secret Script:**
When SSL is enabled, an additional secret creation script is generated:
- Location: `cp4ba-prerequisites/secret_template/aiservices/watsonx-lwe-ssl-secret.sh`
- Creates a Kubernetes secret with the certificate mounted at `/etc/certs/lwe/tls.crt`
- Automatically labeled for backup (`cp4ba.ibm.com/backup-type=mandatory`)

---

### Microsoft Azure OpenAI

```toml
[PROVIDER_1]
PROVIDER_TYPE=azure
PROVIDER_NAME=azure_openai
PROVIDER_URL=https://mycompany.openai.azure.com
API_KEY=your-azure-api-key

[[PROVIDER_1.models]]
MODEL_ID=gpt-5.4
MAX_TOKENS=4096
TEMPERATURE=0.7
```

**Generated Secret Entry:**
```json
{
  "azure_openai_gpt4o_main": {
    "provider": "azure",
    "endpoint": "https://mycompany.openai.azure.com",
    "model": "gpt-5.4",
    "api_key": "your-azure-api-key",
    "use_entra_id": false,
    "timeout": 60,
    "api_version": "2024-12-01-preview",
    "max_completion_tokens": 4096,
    "temperature": 0.7
  }
}
```

---

### Multi-Provider Configuration

**Hybrid Cloud + On-Premises:**

```toml
[COMMON]
ENABLE_REDIS=false
SLOW_STORAGE_CLASSNAME=ocs-storagecluster-cephfs

# Primary: Azure OpenAI
[PROVIDER_1]
PROVIDER_ID=azure_a1b2
ENABLED=true
PROVIDER_NAME=azure
PROVIDER_URL=https://mycompany.openai.azure.com
API_KEY=azure-key

[[PROVIDER_1.MODELS]]
MODEL_ID=gpt-4
DEFAULT=true
MAX_TOKENS=4096
TEMPERATURE=0.7
TOP_P=1.0
TOP_K=50

# Secondary: WatsonX SaaS (disabled for now)
[PROVIDER_2]
PROVIDER_ID=watsonx_c3d4
ENABLED=false
PROVIDER_NAME=watsonx_saas
PROVIDER_URL=https://us-south.ml.cloud.ibm.com
API_KEY=watsonx-key
PROJECT_ID=project-id

[[PROVIDER_2.MODELS]]
MODEL_ID=openai/gpt-oss-120b
DEFAULT=false
MAX_TOKENS=2048
TEMPERATURE=0.7
TOP_P=1.0
TOP_K=50

# Tertiary: On-Premises LWE
[PROVIDER_3]
PROVIDER_ID=watsonx_e5f6
ENABLED=true
PROVIDER_NAME=watsonx_lightweightengine
PROVIDER_URL=https://cpd.internal.com
USERNAME=admin
API_KEY=lwe-key

[[PROVIDER_3.MODELS]]
MODEL_ID=openai/gpt-oss-70b
DEFAULT=false
MAX_TOKENS=1024
TEMPERATURE=0.5
TOP_P=1.0
TOP_K=50
```

**Active LLM Selection:**
The model with `DEFAULT=true` becomes the `active_llm` in the deployment. In the example above:
- `active_llm` = `azure_a1b2_gpt54` (from PROVIDER_1)
- PROVIDER_2 is disabled (`ENABLED=false`), so it's excluded from the deployment
- PROVIDER_3 is enabled but its model has `DEFAULT=false`

**Validation Rules:**
- At least one provider must have `ENABLED=true`
- Exactly one model across all enabled providers must have `DEFAULT=true`
- Disabled providers are skipped during secret generation

---

## Generated Artifacts

### Secret: ibm-providers-config-secret

**Location:** `cp4ba-prerequisites/secret_template/ibm-providers-config-secret.yaml`

**Structure:**
```yaml
kind: Secret
apiVersion: v1
type: Opaque
metadata:
  name: ibm-providers-config-secret
  namespace: "<namespace>"
  labels:
    cp4ba.ibm.com/backup-type: mandatory
stringData:
  providers_config.json: |
    {
      "active_llm": "<provider>_<model>",
      "llms": {
        "<provider>_<model>": { ... },
        ...
      }
    }
```

**Key Points:**
- Contains all provider credentials and configurations
- JSON format for runtime consumption
- Labeled for backup inclusion
- One secret for all providers

---

### Custom Resource: CCXAIServices

**Location:** `cp4ba-prerequisites/generated-cr/ibm_content_cortex_ai_services_cr_final.yaml`

**Structure:**
```yaml
apiVersion: ccxaiservices.operator.ibm.com/v1
kind: CCXAIServices
metadata:
  name: ai-services
  namespace: "<namespace>"
  labels:
    app.kubernetes.io/instance: ibm-ai-services-operator
    app.kubernetes.io/managed-by: ibm-ai-services-operator
    app.kubernetes.io/name: ibm-ai-services-operator
    release: 26.0.0
    cxaiservices.operator.ibm.com/backup-type: mandatory
spec:
  appVersion: 26.0.0
  license:
    accept: true
  shared_configuration:
    sc_deployment_context: "CP4BA"
    image_pull_secrets:
    - ibm-entitlement-key
    sc_image_repository: cp.icr.io
    root_ca_secret: icp4a-root-ca
    sc_deployment_profile_size: "small"
    sc_redis_enable: false
    storage_configuration:
      sc_slow_file_storage_classname: "<storage-class>"
      # sc_block_storage_classname: "<block-storage>" (if Redis enabled)
```

**Key Points:**
- Defines AI Services deployment configuration
- References secret for provider configurations
- Includes storage and Redis settings
- Managed by CCXAIServices operator

---

## Script Reference

### cp4a-content-cortex-ai-services-setup.sh

**Location:** `scripts/cp4a-content-cortex-ai-services-setup.sh`

#### Command-Line Options

```bash
Usage:
  cp4a-content-cortex-ai-services-setup.sh -m <mode> -n <namespace>
  cp4a-content-cortex-ai-services-setup.sh --help

Options:
  -m <mode>       Mode: 'property' or 'generate' (required)
  -n <namespace>  Target namespace for CP4BA deployment (required)
  -h, --help      Display help message and exit
```

#### Key Functions

| Function | Purpose | Called By |
|----------|---------|-----------|
| `show_help()` | Display usage information | CLI |
| `run_property_mode()` | Interactive property file generation | CLI |
| `run_generate_mode()` | Generate secrets and CR from property file | CLI |
| `parse_multi_provider_property_file()` | Parse TOML-like property file | Generate mode, cp4a-deployment.sh |
| `generate_multi_provider_secret()` | Create JSON-based provider secret | Generate mode, cp4a-prerequisites.sh |
| `generate_content_cortex_ai_services_cr()` | Create CCXAIServices CR | Generate mode, cp4a-deployment.sh |
| `prompt_provider_types_multiselect()` | Interactive provider selection | Property mode |
| `set_default_provider_configuration()` | Collect provider-specific config | Property mode |
| `generate_multi_provider_property_file()` | Write property file | Property mode |

#### Global Variables

**Paths:**
- `AI_SERVICES_PROPERTY_FILE`: Property file location
- `AI_SERVICES_SECRET_FILE`: Generated secret location
- `CONTENT_CORTEX_AI_SERVICES_PATTERN_FILE_FINAL`: Generated CR location

**Configuration:**
- `NAMESPACE`: Target namespace
- `ENABLE_REDIS`: Redis enablement flag
- `CP4BA_SLOW_FILE_STORAGE_CLASSNAME`: Slow storage class
- `CP4BA_BLOCK_STORAGE_CLASS_NAME`: Block storage class (if Redis enabled)

**Parsed Data:**
- `PARSED_PROVIDERS`: Array of provider configurations
- `PARSED_COMMON`: Associative array of common settings
- `PARSED_ACTIVE_LLM`: Selected active LLM key

---

## Troubleshooting

### Common Issues

#### Issue: Property file not found

**Error:**
```
[ERROR] Property file not found: <path>
[ERROR] Please run property mode first: cp4a-content-cortex-ai-services-setup.sh -m property -n <namespace>
```

**Solution:**
Run property mode to generate the property file first.

---

#### Issue: Invalid property value

**Error:**
```
[ERROR] CP4BA_SLOW_FILE_STORAGE_CLASSNAME not found in property file
```

**Solution:**
Edit the property file and ensure all `<Required>` placeholders are replaced with actual values.

---

#### Issue: Provider configuration missing

**Error:**
```
[ERROR] Failed to parse AI services property file
```

**Solution:**
1. Check property file syntax (TOML-like format)
2. Ensure all required fields are present for each provider
3. Verify model sections use `[[PROVIDER_N.models]]` format

---

#### Issue: Multiple providers with same name

**Error:**
```
[ERROR] Duplicate provider name detected
```

**Solution:**
Ensure each `PROVIDER_NAME` is unique across all providers in the property file.

---

#### Issue: No enabled providers

**Error:**
```
[✘] At least one provider must be enabled (ENABLED=true)
[✘] Property file validation failed
```

**Solution:**
At least one provider must have `ENABLED=true`. Check your property file and set `ENABLED=true` for at least one provider:
```toml
[PROVIDER_1]
ENABLED=true  # At least one provider must be enabled
```

---

#### Issue: No default model selected

**Error:**
```
[✘] Exactly one model across all enabled providers must be selected as the default LLM model
[✘] No default model found. Please set DEFAULT=true for exactly one model in an enabled provider
[✘] Property file validation failed
```

**Solution:**
Set `DEFAULT=true` for exactly one model across all enabled providers:
```toml
[[PROVIDER_1.MODELS]]
MODEL_ID=openai/gpt-oss-120b
DEFAULT=true  # Mark this as the default model
```

---

#### Issue: Multiple default models

**Error:**
```
[✘] Exactly one model across all enabled providers must be selected as the default LLM model
[✘] Found 2 models with DEFAULT=true:
[✘]   - Provider: watsonx_2ce0 (PROVIDER_1), Model: openai/gpt-oss-120b
[✘]   - Provider: azure_9aa4 (PROVIDER_3), Model: gpt-5.4
[✘] Please set DEFAULT=false for all but one model
[✘] Property file validation failed
```

**Solution:**
Only one model can have `DEFAULT=true`. Set all others to `DEFAULT=false`:
```toml
# Provider 1
[[PROVIDER_1.MODELS]]
MODEL_ID=openai/gpt-oss-120b
DEFAULT=false  # Changed from true

# Provider 3
[[PROVIDER_3.MODELS]]
MODEL_ID=gpt-4
DEFAULT=true  # Keep only one as true
```

---

### Validation Checklist

Before running generate mode, verify:

- [ ] Property file exists at expected location
- [ ] All `<Required>` placeholders replaced with actual values
- [ ] Provider names are unique
- [ ] At least one model configured per provider
- [ ] Storage class names are valid for your cluster
- [ ] API keys and credentials are correct
- [ ] URLs are accessible from the cluster

---

### Debug Mode

Enable debug output:

```bash
set -x
./cp4a-content-cortex-ai-services-setup.sh -m generate -n <namespace>
```

This will show detailed execution trace for troubleshooting.

---

## Additional Resources

- **IBM Documentation**: [Content Cortex AI Services](https://www.ibm.com/docs/en/cloud-paks/cp-biz-automation)
- **WatsonX.ai**: [IBM watsonx.ai Documentation](https://www.ibm.com/docs/en/watsonx-as-a-service)
- **Azure OpenAI**: [Microsoft Azure OpenAI Service](https://azure.microsoft.com/en-us/products/ai-services/openai-service)

---

**Document Version:** 3.1
**Last Updated:** 2026-05-28
**Changes in v3.1:**
- Added IBM Knowledge Center Documentation Guide section
- Documented new CP4BA deployment with AI Services workflow
- Documented adding AI Services to existing deployment workflow
- Added SSL certificate requirements for WatsonX LWE
- Added multi-provider configuration guidance
- Added common configuration errors and resolutions
**Changes in v3.0:**
- Removed MODEL_NAME property (now uses MODEL_ID only)
- Updated JSON key generation format (provider_id + sanitized_model_id)
- Added comprehensive execution flow documentation
- Added folder cleanup behavior documentation
- Enhanced SSL certificate validation flow documentation
- Added detailed error scenarios and resolutions
**Script Version:** 26.0.0