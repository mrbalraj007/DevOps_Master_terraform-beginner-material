# GitHub Codespaces Setup Guide

This guide provides step-by-step instructions for setting up GitHub Codespaces and configuring it to automatically install Terraform and AWS CLI.

## Table of Contents
- [What is GitHub Codespaces?](#what-is-github-codespaces)
- [Enabling GitHub Codespaces](#enabling-github-codespaces)
- [Configuring Codespaces for Terraform and AWS CLI](#configuring-codespaces-for-terraform-and-aws-cli)
- [Creating and Using Your Codespace](#creating-and-using-your-codespace)
- [Additional Configuration and Tips](#additional-configuration-and-tips)

## What is GitHub Codespaces?

GitHub Codespaces provides cloud-based development environments that are fully configurable and available on demand. It allows you to develop entirely in the cloud with a feature-rich editor and support for extensions.

## Enabling GitHub Codespaces

### Prerequisites
- A GitHub account
- Owner or admin permissions for at least one repository

### Steps to Enable Codespaces

1. **Verify Access to Codespaces**:
   - GitHub Codespaces is available for all GitHub users, but usage limits differ based on your account type.
   - For personal accounts, navigate to [GitHub Codespaces](https://github.com/codespaces) to check availability.
   - For organizations, an organization owner needs to enable it for members.

2. **Enable Codespaces for an Organization (if applicable)**:
   - Go to your organization's settings page: `https://github.com/organizations/[YOUR-ORG-NAME]/settings/codespaces`
   - Toggle on "Enable Codespaces for users in this organization"
   - Configure policy settings as needed (user permissions, who can create codespaces, etc.)

3. **Setting Repository Access**:
   - By default, your repositories should be accessible in Codespaces once it's enabled.
   - For organizations, you may need to explicitly enable repositories.

## Configuring Codespaces for Terraform and AWS CLI

To configure your Codespace to automatically install Terraform and AWS CLI, you need to create a dev container configuration file.

1. **Create a Dev Container Configuration**:
   - In your repository, create a directory structure: `.devcontainer`
   - Inside this directory, create a file named `devcontainer.json`

2. **Configure the Dev Container**:
   - Add the following configuration to automatically install Terraform and AWS CLI:

```json
{
    "name": "Terraform AWS Development",
    "image": "mcr.microsoft.com/vscode/devcontainers/universal:linux",
    "features": {
        "terraform": {
            "version": "latest",
            "tflint": "latest"
        },
        "aws-cli": {
            "version": "latest"
        },
        "git": "latest"
    },
    "customizations": {
        "vscode": {
            "extensions": [
                "hashicorp.terraform",
                "amazonwebservices.aws-toolkit-vscode",
                "github.copilot"
            ],
            "settings": {
                "terminal.integrated.defaultProfile.linux": "bash"
            }
        }
    },
    "postCreateCommand": "echo 'Development environment setup complete!'"
}
```

## Creating and Using Your Codespace

1. **Create a New Codespace**:
   - Navigate to your repository on GitHub
   - Click on the "Code" button (green)
   - Select the "Codespaces" tab
   - Click on "Create codespace on main" (or your default branch)
   - Wait for the Codespace to be created and configured (this may take a few minutes as it installs Terraform and AWS CLI)

2. **Verify Installation**:
   - Once your Codespace is ready, open a new terminal (Terminal → New Terminal)
   - Verify Terraform is installed: `terraform --version`
   - Verify AWS CLI is installed: `aws --version`

3. **Configure AWS CLI**:
   - Configure AWS credentials: `aws configure`
   - Enter your AWS Access Key ID, Secret Access Key, default region, and output format

## Additional Configuration and Tips

### Setting Up Environment Variables Securely

1. **For Repository-Specific Secrets**:
   - Go to your repository settings
   - Navigate to Secrets → Codespaces
   - Add secrets like `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`

2. **For User-Level Secrets**:
   - Go to [https://github.com/settings/codespaces](https://github.com/settings/codespaces)
   - Click on "New secret"
   - Add your secrets and select which repositories can access them

### Customizing Your Codespace Further

- **Persistent Customization**: Any changes made to your Codespace persist between sessions.
- **Dotfiles Repository**: Set up a [dotfiles repository](https://docs.github.com/en/codespaces/customizing-your-codespace/personalizing-github-codespaces-for-your-account#dotfiles) for personalized settings across all your Codespaces.
- **Pre-building Codespaces**: For faster startup, you can [configure prebuilds](https://docs.github.com/en/codespaces/prebuilding-your-codespaces/about-github-codespaces-prebuilds) for your repository.

### Managing Codespaces

- **List Your Codespaces**: Visit [https://github.com/codespaces](https://github.com/codespaces) to see all your active Codespaces.
- **Delete Unused Codespaces**: Remember to delete Codespaces you're no longer using to free up resources and reduce costs.
- **Change Machine Type**: You can change the machine type for your Codespace if you need more resources.

## Conclusion

You now have a fully configured GitHub Codespace with Terraform and AWS CLI installed. This environment is ready for development and can be accessed from anywhere with an internet connection.

[YouTube Link](https://www.youtube.com/watch?v=fgp-t5SqQmM&t=2391s)