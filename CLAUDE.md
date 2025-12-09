# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Salesforce DX project (API version 64.0). Package directory: `force-app/main/default`.

## Commands

```bash
# Code Quality
npm run lint                 # ESLint on Aura and LWC JavaScript
npm run prettier             # Format all code files
npm run prettier:verify      # Check formatting without changes

# Testing
npm test                     # Run all LWC unit tests
npm test -- --testPathPattern="componentName"  # Run single component tests
npm run test:unit:watch      # Watch mode
npm run test:unit:coverage   # With coverage report

# Salesforce CLI
sf org create scratch -f config/project-scratch-def.json -a <alias>
sf project deploy start                          # Deploy to default org
sf project deploy start -o <alias>               # Deploy to specific org
sf project retrieve start
```

## Architecture

Standard SFDX structure under `force-app/main/default/`:
- `lwc/` - Lightning Web Components (preferred for new development)
- `aura/` - Legacy Aura components
- `classes/` and `triggers/` - Apex code
- `objects/` - Custom objects and fields

## Code Quality

Pre-commit hooks run automatically:
1. Prettier formatting on staged files
2. ESLint on Aura/LWC JavaScript
3. Jest tests on modified LWC components (with `--bail`)

## MCP Integration

Salesforce DX MCP server configured in `.mcp.json` for Claude Code integration.
