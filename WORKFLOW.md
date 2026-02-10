# LEVERAGED Project Workflow

## 🚨 MANDATORY PROCESS FOR ALL NEW JOBS

This workflow MUST be followed for every new task/job in this project. No exceptions.

---

# 0. GLOBAL IMMUTABLE RULES

## 0.1 NO MOCK DATA
- Mock data is **strictly forbidden**
- No fake API responses
- No placeholder data
- No simulated logic
- No "temporary implementation"
- No hardcoded demo values

**If real API credentials are missing:**
→ Stop and request them.

**If API is unreachable:**
→ Implement a proper interface layer and clearly document dependency, but **never fabricate responses**.

## 0.2 NO PLACEHOLDER LOGIC

**Forbidden patterns:**
- `TODO`
- `FIXME`
- `temporary`
- `sample`
- `fake`
- `stub` (unless clearly defined interface contract)
- console-only debug hacks
- unfinished branches

All logic must be **production-intent**.

## 0.3 FILE TREE MUST BE DEFINED FIRST

Before writing any code:
- Define full directory structure
- Define modules
- Define interfaces
- Define dependencies
- Define runtime requirements
- Define environment variables

**No coding before architecture approval.**

## 0.4 TESTS ARE MANDATORY

Every module must include:
- Unit tests
- Edge case tests
- Failure tests
- Input validation tests

**Project is incomplete if tests are missing.**

## 0.5 SELF-CRIT REQUIRED AFTER EACH PHASE

After each major phase you must:
- Analyze code quality
- Analyze security risks
- Analyze performance bottlenecks
- Identify edge cases
- Identify architectural weaknesses

**You must explicitly list weaknesses.**

## 0.6 CONTEXT MANAGEMENT

Before every major phase:
- Summarize current system state
- Remove irrelevant context
- Compress memory representation

**Prevent context overflow.**

## 0.7 ITERATIVE BUILD LOOP

You must iterate until fully verified:

```
LOOP:
  1. Analyze current state
  2. Detect weaknesses
  3. Fix issues
  4. Run tests
  5. Re-evaluate
  6. Repeat
```

**Stop only when:**
- All tests pass
- No warnings
- No unused imports
- No dead code
- No mock data
- No broken integrations

---

# EXECUTION PHASES

## Phase 1: PROJECT DEFINITION

Before coding:
1. Define exact objective
2. Define what "done" means
3. Define scope boundaries
4. Define constraints (language, framework, deployment target)
5. Define external dependencies
6. Define security requirements
7. Define performance requirements

**Do not proceed without clarity.**

## Phase 2: ARCHITECTURE DESIGN

You must produce:
- System component breakdown
- Data flow description
- Module responsibilities
- Interface contracts
- Error handling strategy
- Configuration strategy
- Logging strategy

**No implementation before architecture is complete.**

## Phase 3: FILE STRUCTURE

Generate full file tree including:
- `src/`
- `modules/`
- `services/`
- `api/`
- `utils/`
- `config/`
- `tests/`
- `scripts/`
- `docs/`
- environment template
- package manager config
- README

**Must be explicit.**

## Phase 4: MODULE IMPLEMENTATION

For each module:
1. Implement clean production-grade code
2. Implement proper error handling
3. Implement logging
4. Validate types
5. Validate imports
6. Add tests
7. Run static analysis
8. Self-review

**Only then proceed to next module.**

## Phase 5: FULL INTEGRATION TESTING

After all modules:
- Test complete workflow
- Simulate failure cases
- Validate API calls
- Validate data persistence
- Validate concurrency behavior
- Validate performance
- Validate memory usage

## Phase 6: SECURITY AUDIT

Mandatory checks:
- Input validation everywhere
- No hardcoded secrets
- Proper env variable usage
- SQL injection prevention
- XSS prevention
- Authentication enforcement
- Authorization validation
- Rate limiting if needed
- Dependency vulnerability awareness
- Safe error messages

## Phase 7: PERFORMANCE REVIEW

Must analyze:
- Inefficient loops
- Blocking calls
- Redundant database queries
- Caching opportunities
- Scalability risks
- Async optimization
- Memory inefficiencies

## Phase 8: DEPLOYMENT READINESS

Generate:
- `.env.example`
- Installation instructions
- Setup script
- Run script
- Deployment instructions
- Dockerfile (if applicable)
- CI/CD recommendation
- Production configuration notes

## Phase 9: FINAL VALIDATION

Before marking complete, answer:
1. What could break in production?
2. What scales poorly?
3. What assumptions were made?
4. What are known weaknesses?
5. What technical debt exists?
6. What would a senior engineer criticize?

**If meaningful critique is missing → re-analyze and improve.**

---

# STRICT FAILURE CONDITIONS

**Immediately stop and flag if:**
- Mock data detected
- Tests failing
- Missing external credentials
- Circular dependency detected
- Context overflow risk
- Security vulnerability detected
- Incomplete module
- Broken integration

---

# ADVANCED RULE FOR LARGE PROJECTS (>5000 LOC)

Split into milestones:
- Each milestone must be independently testable
- Independently runnable
- Independently verifiable

**Never attempt massive monolithic generation.**

---

# EXECUTION LOOP TEMPLATE

```python
while not production_ready:
    analyze()
    detect_weaknesses()
    implement_fixes()
    run_tests()
    evaluate_security()
    evaluate_performance()
    summarize_state()
    compress_context()
```

---

# JOB INTAKE WORKFLOW

## Step 1: Job Posted
- New job/task is posted in chat
- **DO NOT START WORK YET**

## Step 2: CEO Distribution
- **Harvey (CEO)** receives the job
- Harvey analyzes requirements and distributes to appropriate Team Leads:
  - **Alex** - Tech Lead (Development)
  - **Maya** - Marketing Lead
  - **Diana** - Design Lead
  - **Ben** - Business Lead

## Step 3: Team Lead Assignment
- Team Leads break down the job into tasks
- Assign tasks to team members:
  - **Dev Team:** Sarah (Frontend), Marcus (Backend), Nina (Security), Dev (QA)

## Step 4: Board Task Creation
- ALL tasks are written to the board
- Each task has: title, assignee, priority, status="offen"

## Step 5: Plan Posted to Chat
- Post the complete plan to chat with all tasks listed
- Include estimated time and dependencies

## Step 6: Wait for GO
- **DO NOT PROCEED** until user explicitly says "GO" or "Start"
- This is a hard stop - no work begins without approval

## Step 7: Execute with Phases
- Follow Phase 1-9 for each major component
- Update board in real-time
- Tasks complete → "review" (NOT "done")

## Step 8: QA Audit
- QA1 scans frontend
- QA2 scans backend
- Code must pass: 0 critical, 0 errors

## Step 9: Done Status
- Only after QA approval → task moves to "done"

## Step 10: Deployment
- Task is "done" but **NOT DEPLOYED**
- Wait for user to say "deploy"
- Security team performs final review
- Only then execute deployment

---

# STATUS FLOW

```
offen → in arbeit → review → [QA Loop] → done → [Security] → deployed
```

---

**⚠️ VIOLATION OF THESE RULES IS NOT ALLOWED**

You must behave as a disciplined senior engineer.
Speed is irrelevant. Stability is mandatory.
No shortcuts. No pretending. No hallucinated completeness.

**Only verified, testable, production-intent systems are acceptable.**
