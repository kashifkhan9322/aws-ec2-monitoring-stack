# GitHub Actions — CI/CD Workflows

This directory is reserved for future GitHub Actions workflows.

## Current Status

No automated pipelines are configured at this time.  
This is a hands-on infrastructure monitoring project; no application deployment pipeline is required.

## Potential Future Workflows

The following workflows could be added in future iterations of this project:

| Workflow | Purpose |
|----------|---------|
| `lint-yaml.yml` | Validate Prometheus and Alertmanager YAML configuration files |
| `validate-promql.yml` | Syntax check PromQL alert rules using `promtool check rules` |
| `shellcheck.yml` | Static analysis of Bash scripts using ShellCheck |
| `markdown-lint.yml` | Enforce consistent Markdown formatting across documentation |

## Adding a Workflow

To add a workflow, create a YAML file in this directory:

```
.github/workflows/your-workflow-name.yml
```

GitHub Actions will automatically detect and run it on the configured triggers.

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Prometheus promtool](https://prometheus.io/docs/prometheus/latest/command-line/promtool/)
- [ShellCheck](https://www.shellcheck.net/)
