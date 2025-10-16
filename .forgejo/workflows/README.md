# Forgejo Workflows

This directory contains example workflows for using the forgejo-runner-docker-image in Forgejo Actions.

## Available Workflows

### docker-build-push.yml (Docker-in-Docker)
Uses the `node20-dind` image with Docker-in-Docker approach.

**Features:**
- Complete isolation from host system
- Requires `--privileged` mode
- Must manually start Docker daemon
- Best for security-sensitive builds

**Use this when:**
- You need complete isolation
- Security is a priority
- You're building complex Docker images

### docker-build-push-dood.yml (Docker-on-Docker)
Uses the `node20-cli` image with Docker-on-Docker approach.

**Features:**
- Uses host Docker daemon
- No privileged mode needed
- Simpler configuration
- Faster startup

**Use this when:**
- You want simple configuration
- Speed is important
- You trust the build environment

## How to Use

1. **Choose a workflow** based on your requirements
2. **Copy to your repository** at `.forgejo/workflows/your-workflow.yml`
3. **Configure secrets:**
   - `FORGEJO_TOKEN`: Your Forgejo authentication token
4. **Customize:**
   - Change image tags
   - Modify build commands
   - Adjust registry URLs

## Testing

Both workflows have been validated with `yamllint` and follow Forgejo Actions best practices.

To test in your repository:
```bash
# Commit and push to trigger the workflow
git add .forgejo/workflows/
git commit -m "Add Docker build workflow"
git push
```

## Documentation

For detailed information about using these images in Forgejo Actions:
- [Forgejo Actions Guide](../../docs/FORGEJO_ACTIONS_GUIDE.md)
- [Docker Daemon Issue Explanation](../../docs/DOCKER_DAEMON_ISSUE.md)

## Troubleshooting

If you encounter issues:
1. Check that your runner has Docker installed
2. Verify privileged mode is enabled (for DinD)
3. Ensure Docker socket is accessible (for DooD)
4. Review the detailed guides in the docs directory
