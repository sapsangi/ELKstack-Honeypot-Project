# Project Journal

## Day 1: 2026-01-17

### ✅ Resolved
-  Stopped tracking sensitive `docker-compose-*.yml` files in git to prevent credential leaks.
-   Implemented `setup.sh` to generate a local `.env` file for OpenCTI tokens (`OPENCTI_TOKEN`, `CONNECTOR_ID`).
-   Created `basic-docker-compose-*.yml` template for version control and to make yml edits on a separate non-sensitive file.
-   Configured the system to use local, untracked configuration files in `elk/` and `opencti/` directories.
-  Updated `README.md` and `SETUP_INSTRUCTIONS.md` to reflect the new workflow (using templates, `.env` files, and service tokens).
- setup.sh incorrectly created directories for `kibana.yml` and `logstash.yml` instead of files; fixed by cleaning up and creating proper files.
- Docker Compose variable substitution failed for passwords containing `$`; fixed by escaping them as `$$`.

### 🚧 Unresolved
- The issue with the kibana service token is still present and requires further attention to ensure Kibana can start successfully.

### 🧗 Hurdles
- Kibana failed to start with the `elastic` user; required researching and implementing the service token generation flow, which relies on the container being running first. Would like to have a solution that very easily spins up the whole ELK stack.
    - A separate docker command must be run with the elastic user to generate the service token
    - The service token must be generated after the container is running, and the kibana service must be started with the service token
    - does not seem to work even if token is generated and kibana is restarted with the token
