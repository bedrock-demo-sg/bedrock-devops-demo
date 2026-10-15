# bedrock-demo

Small Salesforce DX project used to demo a source-driven development lifecycle: advisors record periodic Client Reviews, and the next review date is calculated from the risk profile.

## Structure
- `force-app/main/default/objects/Client_Review__c` - custom object and fields (Private sharing)
- `classes/ClientReviewService` and `ClientReviewServiceTest` - date rule, invocable action, tests
- `flows/Client_Review_Created` - record-triggered flow (sets Status, calls the Apex action)
- `permissionsets/Client_Review_Manager` - object, field, class and tab access
- `code-analyzer.yml` - Code Analyzer v5 rule configuration
- `demo-assets/` - not deployed; patch files for the deliberate failing-scan demo
- `.github/` - CODEOWNERS and PR template

## Run locally
```
sf org create scratch --definition-file config/project-scratch-def.json --alias bedrock-demo-scratch --duration-days 7 --target-dev-hub <devhub-alias>
sf project deploy start --target-org bedrock-demo-scratch
sf org assign permset --name Client_Review_Manager --target-org bedrock-demo-scratch
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --wait 10 --target-org bedrock-demo-scratch
sf code-analyzer run --config-file code-analyzer.yml --target force-app --severity-threshold 2
```
Never commit private keys or certificates (see `.gitignore`).

## Code Analyzer and Java
PMD, CPD and the flow engine need Java 11+ on the PATH (`java -version`). Verified with Temurin 25 and Code Analyzer 5.11.0.
