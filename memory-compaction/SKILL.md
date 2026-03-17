---
name: memory-compaction
description: Compact and organize MEMORY.md into structured memory/*.md files. Keeps active memory small (<10KB) while archiving searchable history. Run monthly or when MEMORY.md exceeds 20KB.
version: 1.0.0
---

# Memory Compaction

Routine maintenance to keep MEMORY.md focused on active work while preserving searchable history in memory/*.md files.

## Purpose

As agents accumulate knowledge, MEMORY.md grows. Large memory files:
- Cost tokens on every conversation load
- Get truncated when exceeding context limits
- Slow down `memory_search` operations
- Make it harder to find relevant information

**Solution:** Archive completed/historical content → memory/*.md while keeping MEMORY.md hot and focused.

**Key principle:** `memory_search` searches MEMORY.md + memory/*.md, so nothing is lost—just organized.

## When to Run

Run memory compaction when:
- MEMORY.md exceeds 20KB (~500 lines)
- Monthly routine maintenance
- Before/after major project milestones
- User explicitly requests "compact memory" or "organize memory"

## Memory Architecture

### MEMORY.md (Hot, Active Knowledge)
**Target size:** < 10KB  
**Retention:** Last 30 days of activity

**Contents:**
- Active tasks (in progress, blocked, next up)
- Current projects and their status
- Recent decisions and their reasoning
- Critical reference info (credentials, repo locations, active endpoints)
- Recent conversations and context

**Prune aggressively:**
- Completed tasks → `memory/archived-tasks.md`
- Old blog posts → `memory/blog-posts.md`
- Historical security audits → `memory/security-audits.md`
- Past decisions → `memory/decisions.md`

### memory/*.md (Archived, Searchable History)

**Purpose:** Long-term searchable knowledge base

**Structure:**
```
memory/
├── archived-tasks.md       # Completed tasks, closed issues
├── blog-posts.md           # Published blog post history
├── security-audits.md      # Security audit history
├── decisions.md            # Past decisions and reasoning
├── github-repos.md         # GitHub repo details
├── processes.md            # Workflow documentation
├── projects-archive.md     # Completed/paused projects
└── infrastructure.md       # System/infra details
```

**Format each file:**
```markdown
# [Category Name]

Archive of [description]. Moved from MEMORY.md during compaction.

---

## [Section Title] (YYYY-MM-DD)

Content here...

---

## [Earlier Section] (YYYY-MM-DD)

Content here...
```

**Chronological order:** Newest first (top of file).

## Compaction Workflow

### Phase 1: Assess Current State

```bash
# Check MEMORY.md size
wc -l /mnt/workspace/MEMORY.md
du -h /mnt/workspace/MEMORY.md

# Check memory/ directory
ls -lh /mnt/workspace/memory/

# Read current MEMORY.md
cat /mnt/workspace/MEMORY.md
```

**Decision criteria:**
- < 10KB → No action needed (inform user)
- 10-20KB → Optional compaction (ask user)
- > 20KB → Recommend compaction (explain benefits)

### Phase 2: Identify Content to Archive

Scan MEMORY.md for sections that should be archived:

**High priority to archive:**
- ✅ Completed tasks (marked "Done" or closed)
- ✅ Blog posts older than 30 days
- ✅ Security audits older than 30 days
- ✅ Historical decisions (older context)
- ✅ Deprecated processes/workflows

**Keep in MEMORY.md:**
- 🔥 Active tasks (in progress, blocked)
- 🔥 Current projects
- 🔥 Recent decisions (< 30 days)
- 🔥 Critical credentials/locations
- 🔥 Recent context (< 14 days)

### Phase 3: Create/Update Archive Files

For each section being archived:

1. **Check if archive file exists:**
   ```bash
   ls /mnt/workspace/memory/[category].md
   ```

2. **Create archive file if needed:**
   ```bash
   # File doesn't exist - create it
   ```

3. **Extract section from MEMORY.md** (copy, don't delete yet)

4. **Prepend to archive file** (newest first):
   ```markdown
   ## [Section Title] (YYYY-MM-DD)
   
   [Content from MEMORY.md]
   
   ---
   
   [Existing content below...]
   ```

5. **Verify content preserved** (read back, ensure nothing lost)

### Phase 4: Update MEMORY.md

**Only after archives are verified:**

1. **Create backup:**
   ```bash
   cp /mnt/workspace/MEMORY.md /mnt/workspace/MEMORY.md.backup-$(date +%Y%m%d)
   ```

2. **Remove archived sections** from MEMORY.md

3. **Add compaction note** to MEMORY.md:
   ```markdown
   ## Memory Compaction (YYYY-MM-DD)
   
   Compacted MEMORY.md from XXX lines → YYY lines.
   
   Archived content moved to:
   - memory/archived-tasks.md
   - memory/blog-posts.md
   - memory/security-audits.md
   
   All content remains searchable via `memory_search`.
   ```

4. **Verify MEMORY.md still has critical info:**
   - GitHub credentials
   - Active repo locations
   - Current project status
   - In-progress tasks

### Phase 5: Validate and Report

```bash
# Check new size
wc -l /mnt/workspace/MEMORY.md
du -h /mnt/workspace/MEMORY.md

# Verify archives created
ls -lh /mnt/workspace/memory/

# Test search still works
# (memory_search should find content in both MEMORY.md and memory/*.md)
```

**Report to user:**
```
✅ Memory compaction complete

Before: XXX lines / XX KB
After: YYY lines / YY KB

Archived:
- ZZ completed tasks → memory/archived-tasks.md
- ZZ blog posts → memory/blog-posts.md
- ZZ security audits → memory/security-audits.md

All content remains searchable via memory_search.
Backup saved: MEMORY.md.backup-YYYYMMDD
```

## Archive File Standards

### Structure

Each archive file should have:
- **Header:** Category name + description
- **Sections:** Chronological (newest first)
- **Separator:** `---` between sections
- **Dates:** YYYY-MM-DD in section headers
- **Links:** Preserve URLs, GitHub links, file paths

### Example: memory/blog-posts.md

```markdown
# Blog Posts Archive

Published blog posts on Molten.bot. Moved from MEMORY.md during compaction.

All posts published to [Molten-Bot/www](https://github.com/Molten-Bot/www).

---

## Blog Post: Agent Approval Fatigue (2026-02-17)

**Title:** The Agent Approval Fatigue Problem  
**Slug:** `agent-approval-fatigue`  
**Commit:** `37146de` ✅ pushed

Explores why human-in-the-loop approval systems fail for AI agents. Covers risk-based routing, pattern recognition, meaningful oversight. Control plane positioning for Molten.

---

## Blog Post: AI Agent Testing (2026-02-16)

**Title:** Why AI Agents Need Better Testing Than Your Code Does  
**Slug:** `ai-agent-testing-reliability`  
**Commit:** `77eaf14` ✅ pushed

Testing AI agents is fundamentally different—agents make judgments under uncertainty. Covers chaos testing, infrastructure validation, load testing, contract testing.

---

[Earlier posts continue...]
```

### Example: memory/archived-tasks.md

```markdown
# Archived Tasks

Completed tasks from backlog and ad-hoc work. Moved from MEMORY.md during compaction.

---

## Task: Multi-Container Agent Deployment Fix (2026-02-14)

**File:** `/mnt/workspace/backlog/done/issue-multi-container-agent-deployment.md`  
**Status:** ✅ Done

Fixed browser container sidecar not loading in QA/production. Multi-container agent architecture validated. Browser automation working in production.

**Technical scope:**
- Diagnosed deployment config (K8s/Docker/orchestration)
- Validated multi-container sidecar architecture
- Enabled rapid container fleet expansion
- Tested browser accessibility from agent container

---

[Earlier tasks continue...]
```

## Success Criteria

| Outcome | Success | Failure |
|---------|---------|---------|
| Primary | MEMORY.md < 10KB, all content preserved in memory/*.md, searchable via memory_search | Content lost, MEMORY.md still bloated, or search broken |
| Safety | Backup created before modifications, content verified in archives | No backup, or content not verified before deletion |
| Reporting | User informed of size reduction, archive locations, backup location | Silent completion or incomplete report |

## Safety Rules

1. **ALWAYS create backup** before modifying MEMORY.md
2. **VERIFY content in archive files** before removing from MEMORY.md
3. **PRESERVE all links, dates, and references** (no information loss)
4. **NEVER delete content** without confirming it's in an archive
5. **TEST memory_search** after compaction to ensure retrieval works

## Automation Considerations

This skill can be scheduled via OpenClaw cron for monthly compaction:

```json
{
  "schedule": { "kind": "cron", "expr": "0 0 1 * *" },
  "payload": { 
    "kind": "agentTurn",
    "message": "Run memory compaction routine. Review MEMORY.md size and compact if needed."
  }
}
```

**Recommended:** Manual review before compaction (agent proposes, user approves).

## Tips

- **Be aggressive with archiving:** If it's not actively referenced, archive it.
- **Consolidate repeated info:** If SSH key regenerated 10 times, one note is enough.
- **Keep critical reference data:** GitHub creds, repo locations, active project status.
- **Add search keywords:** When archiving, include searchable terms in section titles.
- **Preserve context:** Keep enough detail that archives are useful when retrieved.

## Related Skills

- **memory_search** — Used to verify archived content is still searchable
- **security-audit** — Often generates content that needs archiving
- **backlog-worker** — Task completion creates archive candidates

## Resources

**OpenClaw memory system:**
- MEMORY.md: `/mnt/workspace/MEMORY.md`
- memory/: `/mnt/workspace/memory/`
- Documentation: https://docs.openclaw.ai

**memory_search tool:**
- Searches MEMORY.md + memory/*.md automatically
- Returns top snippets with path + line numbers
- Mandatory before answering questions about prior work
