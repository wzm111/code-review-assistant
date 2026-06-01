#!/usr/bin/env node
/**
 * Code Review Assistant - MCP Server
 * Universal AI integration via Model Context Protocol
 * Supports: Claude Desktop, Cursor, Windsurf, and any MCP-compatible client
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { execSync } from 'child_process';
import { fileURLToPath } from 'url';
import path from 'path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SCRIPTS_DIR = path.join(__dirname, '..', 'scripts');

/**
 * Tool definitions mapped to bash scripts
 * name: snake_case tool name
 * script: kebab-case script filename (without .sh)
 * description: human-readable description
 * params: parameter schema
 */
const TOOL_MAP = [
  {
    name: 'scan_secrets',
    script: 'scan-secrets',
    description: 'Scan code for hardcoded secrets, API keys, tokens, passwords, and credentials',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory to scan' },
      severity: { type: 'string', enum: ['all', 'critical', 'high'], default: 'all', description: 'Severity filter level' },
    },
  },
  {
    name: 'scan_dependencies',
    script: 'scan-deps',
    description: 'Scan dependencies for known vulnerabilities (npm, pip, go mod, etc.)',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory containing package files' },
    },
  },
  {
    name: 'check_code_smell',
    script: 'code-smell',
    description: 'Detect code smells: duplication, long functions, magic numbers, dead code',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory to analyze' },
    },
  },
  {
    name: 'check_naming_convention',
    script: 'naming-convention',
    description: 'Check naming conventions for variables, functions, files, and directories across JS/TS/Python/Go/Java/PHP',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory to check' },
    },
  },
  {
    name: 'check_lint',
    script: 'lint-check',
    description: 'Run linting checks and report style violations',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory to lint' },
    },
  },
  {
    name: 'analyze_complexity',
    script: 'complexity-analysis',
    description: 'Analyze code complexity and detect duplication (cyclomatic complexity, cognitive complexity)',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      depth: { type: 'string', enum: ['quick', 'standard', 'deep'], default: 'standard', description: 'Analysis depth' },
    },
  },
  {
    name: 'check_concurrency',
    script: 'concurrency-check',
    description: 'Detect concurrency safety issues: race conditions, deadlocks, improper locking',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
    },
  },
  {
    name: 'check_error_handling',
    script: 'error-handling',
    description: 'Check error handling completeness: missing catches, swallowed errors, unhandled rejections',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
    },
  },
  {
    name: 'check_resource_leak',
    script: 'resource-leak',
    description: 'Scan for resource leaks: unclosed files, connections, streams, timers',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
    },
  },
  {
    name: 'check_type_safety',
    script: 'type-safety',
    description: 'Deep type safety check: any types, missing types, type inconsistencies',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      any_threshold: { type: 'string', default: '10', description: 'Maximum allowed any/unknown count' },
    },
  },
  {
    name: 'check_test_coverage',
    script: 'test-coverage',
    description: 'Analyze test coverage and identify untested code paths',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      threshold: { type: 'string', default: '80', description: 'Coverage threshold percentage' },
    },
  },
  {
    name: 'check_test_quality',
    script: 'test-quality',
    description: 'Evaluate test quality: assertions, mocks, test naming, independence',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
    },
  },
  {
    name: 'check_api_contract',
    script: 'api-contract',
    description: 'Detect API contract breaking changes between versions',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
    },
  },
  {
    name: 'check_db_migration',
    script: 'db-migration',
    description: 'Review database migration safety: destructive changes, rollback support',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
    },
  },
  {
    name: 'check_architecture',
    script: 'architecture-check',
    description: 'Check architecture compliance: layer violations, dependency direction',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
    },
  },
  {
    name: 'analyze_impact',
    script: 'impact-analysis',
    description: 'Analyze change impact and risk rating for code modifications',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      base_ref: { type: 'string', default: 'HEAD~1', description: 'Git reference to compare against' },
    },
  },
  {
    name: 'check_pii',
    script: 'pii-scan',
    description: 'Scan for PII (personally identifiable information) data leaks',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      severity: { type: 'string', enum: ['low', 'medium', 'high', 'critical'], default: 'medium', description: 'Severity threshold' },
    },
  },
  {
    name: 'check_supply_chain',
    script: 'supply-chain',
    description: 'Detect supply chain risks: typosquatting, malicious packages, dependency hijacking',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
    },
  },
  {
    name: 'check_config_drift',
    script: 'config-drift',
    description: 'Detect configuration drift between environments',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
    },
  },
  {
    name: 'check_reuse',
    script: 'reuse-check',
    description: 'Check code reusability and DRY principle violations',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      min_lines: { type: 'string', default: '5', description: 'Minimum duplicate lines threshold' },
    },
  },
  {
    name: 'check_bundle_size',
    script: 'bundle-size',
    description: 'Analyze bundle size and detect bloat',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      threshold_mb: { type: 'string', default: '1', description: 'Size threshold in MB' },
    },
  },
  {
    name: 'check_accessibility',
    script: 'a11y-check',
    description: 'Check accessibility (a11y) issues in frontend code',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
    },
  },
  {
    name: 'check_i18n',
    script: 'i18n-check',
    description: 'Check internationalization completeness: missing translations, hardcoded strings',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
    },
  },
  {
    name: 'check_license',
    script: 'license-check',
    description: 'Check license compliance of dependencies',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
    },
  },
  {
    name: 'run_scheduled_review',
    script: 'scheduled-review',
    description: 'Run a scheduled code review with configurable checks and notifications',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      severity: { type: 'string', enum: ['critical', 'high', 'medium', 'all'], default: 'all', description: 'Review severity level' },
    },
  },
  {
    name: 'export_report',
    script: 'export-report',
    description: 'Export review results to Markdown or HTML report',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      format: { type: 'string', enum: ['markdown', 'html'], default: 'markdown', description: 'Export format' },
      output: { type: 'string', description: 'Output file path' },
    },
  },
  {
    name: 'check_severity_gate',
    script: 'severity-gate',
    description: 'Calculate severity score and enforce quality gate thresholds',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      threshold: { type: 'string', enum: ['critical', 'high', 'medium', 'low'], default: 'high', description: 'Quality gate threshold' },
    },
  },
  {
    name: 'analyze_cross_file_context',
    script: 'cross-file-context',
    description: 'Analyze cross-file impact: callers, callees, imports, interfaces, risk assessment',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      base_ref: { type: 'string', default: 'HEAD~1', description: 'Git reference to compare against' },
    },
  },
  {
    name: 'generate_pr_description',
    script: 'pr-describe',
    description: 'Auto-generate PR title and description from git diff and commits',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      pr_number: { type: 'string', description: 'PR number to update (optional)' },
    },
  },
  {
    name: 'post_pr_comments',
    script: 'pr-comment',
    description: 'Post review findings as inline PR comments via GitHub CLI',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      pr_number: { type: 'string', description: 'PR number' },
      review_file: { type: 'string', description: 'Review output file (optional, reads from stdin if omitted)' },
    },
  },
  {
    name: 'apply_auto_fixes',
    script: 'auto-fix',
    description: 'Auto-fix simple code issues: trailing whitespace, formatting, unused imports, naming',
    params: {
      directory: { type: 'string', default: '.', description: 'Target directory' },
      apply: { type: 'string', enum: ['--apply', ''], default: '', description: 'Pass --apply to actually modify files (default is dry-run)' },
    },
  },
];

/**
 * Build MCP tool schema from tool map
 */
function buildTools() {
  return TOOL_MAP.map((t) => ({
    name: t.name,
    description: t.description,
    inputSchema: {
      type: 'object',
      properties: t.params,
    },
  }));
}

/**
 * Execute a bash script with given arguments
 */
function runScript(scriptName, args) {
  const scriptPath = path.join(SCRIPTS_DIR, `${scriptName}.sh`);
  const argValues = Object.values(args || {});
  const cmd = `bash "${scriptPath}" ${argValues.map((a) => `"${a}"`).join(' ')}`;

  try {
    const output = execSync(cmd, {
      cwd: args.directory || '.',
      encoding: 'utf-8',
      timeout: 120000,
      maxBuffer: 10 * 1024 * 1024,
    });
    return { success: true, output };
  } catch (error) {
    // Scripts exit with code 1 when issues found - this is expected
    return {
      success: error.status === 1,
      output: error.stdout || error.message,
      exitCode: error.status,
    };
  }
}

const server = new Server(
  { name: 'code-review-assistant', version: '1.0.0' },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: buildTools(),
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  const tool = TOOL_MAP.find((t) => t.name === name);

  if (!tool) {
    return {
      content: [
        { type: 'text', text: `Unknown tool: ${name}` },
      ],
      isError: true,
    };
  }

  const result = runScript(tool.script, args);

  return {
    content: [
      {
        type: 'text',
        text: result.output || 'No output from script',
      },
    ],
    isError: !result.success,
  };
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // Server runs until stdin closes
}

main().catch((err) => {
  console.error('MCP Server error:', err);
  process.exit(1);
});
