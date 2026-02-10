# LEVERAGED Project Workflow

## 🚨 MANDATORY PROCESS FOR ALL NEW JOBS

This workflow MUST be followed for every new task/job in this project. No exceptions.

---

## Phase 1: Job Intake & Planning

### 1.1 Job Posted
- New job/task is posted in chat
- **DO NOT START WORK YET**

### 1.2 CEO Distribution
- **Harvey (CEO)** receives the job
- Harvey analyzes requirements and distributes to appropriate Team Leads:
  - **Alex** - Tech Lead (Development)
  - **Maya** - Marketing Lead
  - **Diana** - Design Lead  
  - **Ben** - Business Lead

### 1.3 Team Lead Assignment
- Team Leads break down the job into tasks
- Assign tasks to team members:
  - **Dev Team:** Sarah (Frontend), Marcus (Backend), Nina (Security), Dev (QA)
  - **Marketing:** Content writers, Social media
  - **Design:** UI/UX designers
  - **Business:** Analysts, Operations

### 1.4 Board Task Creation
- ALL tasks are written to the board
- Each task has: title, assignee, priority, status="offen"
- Use: `POST http://localhost:3000/api/tasks`

### 1.5 Plan Posted to Chat
- Post the complete plan to chat:
  ```
  📋 **JOB PLAN: [Job Name]**
  
  **Tasks:**
  1. [Task 1] - Assigned to [Person]
  2. [Task 2] - Assigned to [Person]
  ...
  
  **Estimated Time:** X hours
  **Dependencies:** [list any]
  
  ⏳ Waiting for GO...
  ```

### 1.6 Wait for GO
- **DO NOT PROCEED** until user explicitly says "GO" or "Start"
- This is a hard stop - no work begins without approval

---

## Phase 2: Execution

### 2.1 Work Begins
- On "GO", all assigned tasks start
- Update task status to "in arbeit" (in progress)

### 2.2 Real-time Progress Tracking
- Update board after EVERY significant change
- Use webhook: `curl -X POST http://localhost:3000/api/tasks/{id} -d '{"status":"..."}'`
- Post progress updates to chat periodically

### 2.3 Task Completion
- When code/work is done, task moves to **"review"** (NOT "done"!)
- Update: `{"status": "review"}`

---

## Phase 3: Review & QA

### 3.1 QA Agent Team Audit
- **QA1** scans frontend code (React, TypeScript)
- **QA2** scans backend code (Solidity contracts)
- Both run automatically when tasks enter "review"

### 3.2 Audit Criteria
Code must pass:
- ✅ Zero CRITICAL issues
- ✅ Zero ERROR issues
- ⚠️ Warnings acceptable (document them)
- ℹ️ Info items logged

### 3.3 Fix Loop
If issues found:
1. QA reports issues
2. Developer fixes
3. Rescan
4. Repeat until clean

### 3.4 Audit Passed
- Only after QA approval → task moves to "done"
- Update: `{"status": "done"}`

---

## Phase 4: Pre-Deployment

### 4.1 User Approval Required
- Task is "done" but **NOT DEPLOYED**
- Wait for user to say "deploy"

### 4.2 Security Review
- **Nina (Security)** + Security Dev Team perform final review:
  - Reentrancy checks
  - Access control verification
  - Input validation
  - Economic attack vectors
  - Gas optimization review

### 4.3 Deployment Checklist
- [ ] All tests pass
- [ ] QA audit clean
- [ ] Security review passed
- [ ] User approved deployment
- [ ] Backup/rollback plan ready

---

## Phase 5: Deployment

### 5.1 Deploy
- Only after ALL Phase 4 checks pass
- Execute deployment scripts
- Verify on-chain

### 5.2 Post-Deploy Verification
- Check live site/contracts
- Monitor for issues
- Report completion

---

## Status Flow

```
offen → in arbeit → review → [QA Loop] → done → [Security] → deployed
```

## Board API Reference

```bash
# Create task
curl -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"projectId":"proj-7d79f857","title":"...","assignee":"...","priority":"high","status":"offen"}'

# Update task status
curl -X PATCH http://localhost:3000/api/tasks/{taskId} \
  -H "Content-Type: application/json" \
  -d '{"status":"in arbeit"}'

# Post to chat
curl -X POST http://localhost:3000/api/response \
  -H "Content-Type: application/json" \
  -d '{"projectId":"proj-7d79f857","message":"..."}'
```

---

**⚠️ VIOLATION OF THIS WORKFLOW IS NOT ALLOWED**

If you receive a new job and start working without following this process, STOP immediately and restart from Phase 1.
