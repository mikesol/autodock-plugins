---
description: Test the current PR or specified tests on an Autodock staging environment
argument-hint: "[test target or PR URL]"
---

# Autodock Test

Run tests on an Autodock staging environment. If no environment is running, sets one up first. Syncs the current state once (no progressive sync) and then runs tests.

**Arguments:**
- No arguments: Test the current PR (uses git context to determine what to test)
- PR URL or number: Test a specific PR (e.g., `#123` or `https://github.com/owner/repo/pull/123`)
- Test path/pattern: Run specific tests (e.g., `tests/unit/` or `**/integration/**`)
- `--browser` or `--visual`: Focus on browser-based testing with Chrome DevTools MCP
- `--e2e`: Run end-to-end tests (CLI runner + browser verification)

**Testing capabilities:**
- **CLI tests**: Unit tests, integration tests via jest/vitest/pytest/mocha
- **Browser tests**: Visual verification, interaction testing, console/network inspection via Chrome DevTools MCP
- **E2E tests**: Playwright/Cypress runners or manual browser flows

---

## Step 1: Check Authentication

**IMPORTANT: Do not search for tools or grep for MCP availability. Directly call the tool.**

Call the `mcp__autodock__account_info` tool now. This is the only way to check authentication status.

**If the tool returns user info (email, name):**
- Authentication successful - proceed to Step 2

**If the tool call fails, errors, or the tool doesn't exist:**
- Tell the user: "The Autodock MCP server needs authentication. Please run `/mcp`, select the `autodock` server, and press Enter to log in. Then try `/autodock:test` again."
- STOP here - do not proceed

---

## Step 2: Check Environment Status

Check if an Autodock environment is already running:

```bash
cat .autodock-state 2>/dev/null || echo "NO_STATE"
```

**If `.autodock-state` exists with an environmentId:**
1. Call `mcp__autodock__env_status` with that environmentId
2. If status is `ready`: Skip to Step 3 (environment already running)
3. If status is `stopped`: Call `mcp__autodock__env_restart`, wait for `ready`, then proceed to Step 3
4. If environment not found or failed: Delete `.autodock-state`, proceed to Step 2b

**If no `.autodock-state` exists (Step 2b):**
1. Launch a new environment by invoking the `staging` agent with `run_in_background: false` (we need to wait for it)
2. Tell the user: "No running environment found. Setting up Autodock environment first..."
3. Wait for the staging agent to complete
4. Proceed to Step 3

---

## Step 3: One-Time Sync

**IMPORTANT: Only sync once. Do NOT set up progressive sync or watch mode.**

### Step 3.1: Detect technologies

```bash
cat package.json 2>/dev/null || echo "{}"
ls -la next.config.* vite.config.* supabase/ k8s/ kubernetes/ argocd/ 2>/dev/null || true
```

Build detection array from:
- `next`, `@next/*` in package.json → `nextjs`
- `vite`, `@vitejs/*` in package.json → `vite`
- `@supabase/*` or `supabase/` directory → `supabase`
- `k8s/` or `kubernetes/` → `k3s`
- `argocd/` → `argocd`

### Step 3.2: Get sync instructions and execute

Call `mcp__autodock__env_sync` with:
- `projectName`: basename of current directory
- `detectedTechnologies`: array from above

Execute the rsync command, excluding `.env*` files and handling them separately per the sync tool's guidance.

### Step 3.3: Restart services if needed

If services were already running, restart them to pick up new code:

```bash
# Get the environment info from state
SLUG=$(cat .autodock-state | jq -r '.slug')
PROJECT=$(basename "$PWD")

# Kill existing processes and restart
ssh -i ~/.autodock/ssh/${SLUG}.pem ubuntu@${SLUG}.autodock.io << 'EOF'
pkill -f "npm run dev" || true
pkill -f "node" || true
sleep 2
cd /workspace/${PROJECT}
export __VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS=.autodock.io
nohup bash -li -c 'npm run dev' > /workspace/logs/${PROJECT}.log 2>&1 </dev/null &
EOF
```

Wait a few seconds for services to start.

---

## Step 4: Determine Test Target and Mode

Parse `$ARGUMENTS` to determine what to test and how:

### Step 4.1: Determine test mode

Check for mode flags in arguments:
- `--browser` or `--visual` → Browser-only testing with Chrome DevTools MCP (skip CLI tests)
- `--e2e` → Full E2E: CLI tests + browser verification
- No flag → Auto-detect based on project (prefer CLI tests if available, add browser checks)

### Step 4.2: Determine test target

**If no arguments provided (or only mode flags):**
1. Get current branch and PR info:
   ```bash
   git branch --show-current
   gh pr view --json number,title,url,files 2>/dev/null || echo "NO_PR"
   ```
2. If a PR exists for current branch: Test the PR's changes
   - Check `files` to understand what changed (UI components? API? Config?)
   - This informs whether to focus on browser or CLI tests
3. If no PR: Test all tests (full test suite)

**If arguments look like a PR reference:**
- `#123` or a GitHub PR URL → Fetch PR info with `gh pr view <ref> --json number,title,headRefName,baseRefName,files`
- Checkout the PR branch if not already on it
- Analyze changed files to determine test focus

**If arguments look like a test path/pattern:**
- Use as the test target directly (e.g., `tests/unit/`, `**/*.test.ts`)

### Step 4.3: Smart test selection for PRs

When testing a PR, analyze the changed files to prioritize testing:

```bash
gh pr view --json files | jq -r '.files[].path'
```

**File patterns → Test focus:**
- `src/components/*`, `*.tsx`, `*.css` → Prioritize browser/visual testing
- `src/api/*`, `src/services/*`, `*.test.ts` → Prioritize CLI unit tests
- `src/pages/*`, `src/app/*` → Both: CLI tests + browser navigation
- `package.json`, config files → Full test suite + dependency check
- `*.md`, `docs/*` → Skip tests, just verify build

---

## Step 5: Run Tests

Determine the appropriate testing strategy based on the project and test target.

### Step 5.1: Detect test framework and type

Check package.json for test configuration:

```bash
cat package.json | jq '.scripts.test // empty'
cat package.json | jq '.scripts' | grep -i 'test\|e2e\|cypress\|playwright'
```

**Test types to identify:**
- **Unit/Integration tests**: jest, vitest, pytest, mocha → Run via CLI on remote
- **E2E tests with bundled runner**: playwright, cypress → Run via CLI on remote
- **Browser/Visual tests**: No test runner, or manual QA → Use Chrome DevTools MCP

### Step 5.2: For CLI-based tests (unit, integration, E2E runners)

Call `mcp__autodock__env_run` to get SSH templates, then execute tests:

```bash
SLUG=$(cat .autodock-state | jq -r '.slug')
PROJECT=$(basename "$PWD")

ssh -i ~/.autodock/ssh/${SLUG}.pem ubuntu@${SLUG}.autodock.io << 'EOF'
cd /workspace/${PROJECT}
bash -li -c 'npm test'  # Or the appropriate test command
EOF
```

**For specific test patterns**, pass them to the test runner:
```bash
bash -li -c 'npm test -- ${TEST_PATTERN}'
```

### Step 5.3: For Browser Testing with Chrome DevTools MCP

**IMPORTANT: Use Chrome DevTools MCP for visual verification, interaction testing, and debugging.**

The Chrome DevTools MCP tools (`mcp__chrome-devtools__*`) allow you to interact with the deployed application in a real browser. This is essential for:
- Visual regression testing
- UI interaction testing
- Console error detection
- Network request verification
- Accessibility testing

#### 5.3.1: Navigate to the deployed app

First, get the exposed URL from state and navigate:

```bash
SLUG=$(cat .autodock-state | jq -r '.slug')
# Frontend is typically on port 3000
URL="https://3000--${SLUG}.autodock.io"
```

Then use Chrome DevTools:
1. Call `mcp__chrome-devtools__new_page` with the URL to open the app
2. Or call `mcp__chrome-devtools__navigate_page` if a page is already open

#### 5.3.2: Take a snapshot to understand page structure

Call `mcp__chrome-devtools__take_snapshot` to get the accessibility tree. This returns:
- All interactive elements with unique `uid` identifiers
- Text content and structure
- Form fields, buttons, links

Use this to plan interactions and verify content.

#### 5.3.3: Visual verification with screenshots

Call `mcp__chrome-devtools__take_screenshot` to capture:
- Full page: `fullPage: true`
- Specific element: `uid: "<element-uid>"`
- Current viewport: no parameters

Compare screenshots to verify:
- Layout renders correctly
- Styles are applied
- No visual regressions
- Responsive design works

#### 5.3.4: Test user interactions

Use Chrome DevTools to simulate user behavior:

- **Click elements**: `mcp__chrome-devtools__click` with `uid`
- **Fill forms**: `mcp__chrome-devtools__fill` with `uid` and `value`
- **Fill multiple fields**: `mcp__chrome-devtools__fill_form` with array of elements
- **Hover**: `mcp__chrome-devtools__hover` with `uid`
- **Keyboard input**: `mcp__chrome-devtools__press_key` with key combo (e.g., "Enter", "Control+A")
- **Drag and drop**: `mcp__chrome-devtools__drag` with `from_uid` and `to_uid`

**Example flow - test a login form:**
1. `take_snapshot` → Find login form elements
2. `fill_form` → Enter username and password
3. `click` → Click submit button
4. `wait_for` → Wait for success message or redirect
5. `take_screenshot` → Verify logged-in state

#### 5.3.5: Check for console errors

Call `mcp__chrome-devtools__list_console_messages` to detect:
- JavaScript errors
- React/Vue warnings
- Failed API calls logged to console
- Deprecation warnings

Filter by type: `types: ["error", "warn"]` to focus on problems.

For detailed error info, call `mcp__chrome-devtools__get_console_message` with the `msgid`.

#### 5.3.6: Verify network requests

Call `mcp__chrome-devtools__list_network_requests` to check:
- API calls are being made
- Correct endpoints are hit
- No failed requests (4xx, 5xx)

Filter by type: `resourceTypes: ["fetch", "xhr"]` for API calls.

For detailed request/response, call `mcp__chrome-devtools__get_network_request` with the `reqid`.

**Check for:**
- Failed requests (status >= 400)
- Slow requests
- Missing authentication headers
- CORS errors

#### 5.3.7: Test different viewports

Call `mcp__chrome-devtools__resize_page` to test responsive design:
- Mobile: `width: 375, height: 667`
- Tablet: `width: 768, height: 1024`
- Desktop: `width: 1920, height: 1080`

Take screenshots at each viewport to verify responsive behavior.

#### 5.3.8: Performance testing

For performance analysis:
1. Call `mcp__chrome-devtools__performance_start_trace` with `reload: true, autoStop: true`
2. Wait for trace to complete
3. Call `mcp__chrome-devtools__performance_analyze_insight` to examine specific metrics

Check Core Web Vitals:
- LCP (Largest Contentful Paint)
- FID (First Input Delay)
- CLS (Cumulative Layout Shift)

#### 5.3.9: Handle dialogs and popups

If the app shows alerts, confirms, or prompts:
- Call `mcp__chrome-devtools__handle_dialog` with `action: "accept"` or `action: "dismiss"`
- For prompts, include `promptText`

### Step 5.4: Recommended test flow for PRs

When testing a PR, combine both approaches:

1. **Run CLI tests first** (fast feedback):
   ```bash
   ssh ... 'npm test'
   ```

2. **Then browser verification** (visual/interaction):
   - Navigate to app URL
   - Take snapshot and screenshot of affected pages
   - Test the specific feature/fix from the PR
   - Check console for errors
   - Verify network requests

3. **For UI PRs**, focus on Chrome DevTools:
   - Screenshot before/after comparisons
   - Interaction testing for new components
   - Responsive testing if layout changed

4. **For API PRs**, focus on CLI + network verification:
   - Run unit tests
   - Use Chrome DevTools to verify API calls from frontend

---

## Step 6: Generate Test Report

Create a persistent test report with full audit log and screenshots.

### Step 6.1: Create report directory

```bash
mkdir -p .autodock/reports
REPORT_DIR=".autodock/reports/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REPORT_DIR/screenshots"
```

### Step 6.2: Save screenshots during testing

Throughout Step 5, save all screenshots to the report directory:

```bash
# When taking screenshots with Chrome DevTools, save to file
mcp__chrome-devtools__take_screenshot with filePath: "$REPORT_DIR/screenshots/01-homepage.png"
mcp__chrome-devtools__take_screenshot with filePath: "$REPORT_DIR/screenshots/02-login-form.png"
# etc.
```

Name screenshots sequentially with descriptive names (e.g., `01-homepage.png`, `02-after-login.png`, `03-dashboard.png`).

### Step 6.3: Generate HTML report

Create `$REPORT_DIR/report.html` with a full audit log:

```html
<!DOCTYPE html>
<html>
<head>
  <title>Autodock Test Report - [timestamp]</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
    .status-passed { color: #22c55e; } .status-failed { color: #ef4444; }
    .screenshot { max-width: 100%; border: 1px solid #e5e7eb; border-radius: 8px; margin: 10px 0; }
    .step { border-left: 3px solid #3b82f6; padding-left: 16px; margin: 20px 0; }
    .error { background: #fef2f2; border: 1px solid #fecaca; padding: 12px; border-radius: 6px; }
    .success { background: #f0fdf4; border: 1px solid #bbf7d0; padding: 12px; border-radius: 6px; }
    details { margin: 10px 0; } summary { cursor: pointer; font-weight: 600; }
  </style>
</head>
<body>
  <h1>Autodock Test Report</h1>
  <p><strong>Target:</strong> [PR #123: "Fix onboarding flow" | onboarding | etc.]</p>
  <p><strong>Environment:</strong> <a href="https://3000--[slug].autodock.io">https://3000--[slug].autodock.io</a></p>
  <p><strong>Generated:</strong> [timestamp]</p>
  <p><strong>Status:</strong> <span class="status-[passed|failed]">[PASSED | FAILED]</span></p>

  <h2>Summary</h2>
  <ul>
    <li>Steps executed: X</li>
    <li>Screenshots captured: Y</li>
    <li>Console errors: Z</li>
    <li>Network failures: W</li>
  </ul>

  <h2>Audit Log</h2>

  <div class="step">
    <h3>Step 1: Navigate to homepage</h3>
    <p class="success">✅ Page loaded successfully</p>
    <img src="screenshots/01-homepage.png" class="screenshot" alt="Homepage">
    <details>
      <summary>Page snapshot</summary>
      <pre>[accessibility tree snapshot]</pre>
    </details>
  </div>

  <div class="step">
    <h3>Step 2: Click "Get Started" button</h3>
    <p class="success">✅ Navigation to /signup</p>
    <img src="screenshots/02-signup-page.png" class="screenshot" alt="Signup page">
  </div>

  <div class="step">
    <h3>Step 3: Fill registration form</h3>
    <p class="success">✅ Form filled with test data</p>
    <details>
      <summary>Form data</summary>
      <pre>email: test@example.com
name: Test User
password: ********</pre>
    </details>
  </div>

  <!-- More steps... -->

  <h2>Console Messages</h2>
  <div class="[error|success]">
    [List of console errors/warnings, or "No errors detected"]
  </div>

  <h2>Network Requests</h2>
  <table>
    <tr><th>Method</th><th>URL</th><th>Status</th><th>Duration</th></tr>
    <tr><td>POST</td><td>/api/auth/register</td><td>201</td><td>234ms</td></tr>
    <!-- More requests... -->
  </table>

  <h2>Failed Requests</h2>
  <div class="[error|success]">
    [List of 4xx/5xx requests, or "All requests successful"]
  </div>

</body>
</html>
```

### Step 6.4: Create "latest" symlink

Create a symlink for easy access to the most recent report:

```bash
ln -sfn "$REPORT_DIR" .autodock/reports/latest
```

This allows users to always open `.autodock/reports/latest/report.html` without knowing the timestamp.

### Step 6.5: Create markdown summary

Also create `$REPORT_DIR/SUMMARY.md` for quick reference:

```markdown
# Test Report: [target]

**Status:** PASSED/FAILED
**Environment:** https://3000--[slug].autodock.io
**Generated:** [timestamp]

## Results

| Metric | Value |
|--------|-------|
| Steps executed | X |
| Screenshots | Y |
| Console errors | Z |
| Network failures | W |

## Screenshots

![Homepage](screenshots/01-homepage.png)
![After login](screenshots/02-after-login.png)

## Issues Found

- [List any failures or concerns]

## Full Report

Open [report.html](report.html) for the complete audit log.
```

### Step 6.5: Report to user

Report comprehensive test results to the user:

```
Test Results
============

**Target:** <PR #123: "Fix login flow" | tests/unit/ | Full test suite>
**Environment:** <slug>.autodock.io
**Mode:** <CLI | Browser | E2E>
**Status:** <PASSED | FAILED | ERROR>

---

## CLI Test Results (if applicable)

**Summary:**
- Tests run: X
- Passed: Y
- Failed: Z
- Skipped: W

**Failed tests:**
- test_name_1: error message
- test_name_2: error message

---

## Browser Test Results (if applicable)

**Pages tested:** 3
**Screenshots captured:** 5

**Visual checks:**
- ✅ Homepage renders correctly
- ✅ Login form displays all fields
- ❌ Mobile layout has overflow issue

**Console errors:** 2 errors detected
- TypeError: Cannot read property 'map' of undefined (app.js:142)
- 404: /api/user/preferences

**Network issues:** 1 failed request
- GET /api/config → 500 Internal Server Error

**Accessibility:** Snapshot captured, X interactive elements found

---

**URLs:**
- App: https://3000--<slug>.autodock.io
- API: https://8080--<slug>.autodock.io (if applicable)

**Report:** .autodock/reports/latest/report.html
View the full audit log with screenshots by opening the report in your browser.
```

Tell the user how to open the report:
```bash
open .autodock/reports/latest/report.html
```

### Suggestions based on results

**If CLI tests failed:**
- "Run `/autodock:test <specific_test>` to re-run a single test"
- "Check logs with `ssh ... 'cat /workspace/logs/<project>.log'`"

**If browser tests found issues:**
- "Console errors detected - check the browser console for stack traces"
- "Network request failed - verify the API is running and endpoints are correct"
- "Visual issue found - screenshot attached showing the problem"

**If everything passed:**
- "All tests passed! The environment is still running at https://3000--<slug>.autodock.io"
- "Run `/autodock:test --browser` to do additional visual verification"

**Always remind:**
- "The environment is still running - you can make fixes and run `/autodock:test` again"
- "Use `/autodock:sync` if you make local changes before re-testing"

---

## Error Handling

- **Environment launch fails**: Report error, suggest checking quota
- **Sync fails**: Report which step failed, offer manual retry
- **Test command not found**: Suggest checking package.json scripts
- **Tests timeout**: Report partial results, suggest running specific tests

---

## Notes

- This command does NOT do progressive sync. Use `/autodock:sync` manually if you make local changes
- The environment remains running after tests complete for debugging/re-testing
- Use `/autodock:down` to stop the environment when done

**Chrome DevTools MCP requirements:**
- The Chrome DevTools MCP server must be connected (check with `/mcp`)
- A Chrome browser must be running with DevTools protocol enabled
- The MCP can control browser tabs to navigate, interact, and capture

**Quick reference - Common test flows:**
- `/autodock:test` → Auto-detect and run appropriate tests for current PR
- `/autodock:test --browser` → Browser-only: visual checks, console errors, network verification
- `/autodock:test --e2e` → Full E2E: CLI tests + browser verification
- `/autodock:test tests/unit/` → Run specific test path via CLI
- `/autodock:test #123` → Test a specific PR
