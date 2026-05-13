# Copilot Instructions for aud_support

This repository contains recovery activity modules and support materials for an alcohol use disorder (AUD) treatment platform. The project uses Quarto (qmd) files to structure interactive therapeutic content.

## Project Overview

**Goal:** Develop recovery activities and psychoeducational modules for substance use disorder treatment, with a focus on relapse prevention and sustained recovery.

**Key Assets:**
- **Recovery activities**: Therapeutic worksheets, psychoeducational readings, and interactive exercises in Quarto format
- **Support categories**: 12 evidence-based categories (craving, risky situations, relationships, etc.) that activities map to
- **CSV metadata**: Tracking activity status, mappings, and selection logic
- **Treatment resources**: Clinical manuals and reference materials from NIDA, Project MATCH, and MBRP frameworks

## Architecture & Data Model

### Activity Workflow & Status
Activities progress through three workflow stages:
1. **in_progress**: Being created/edited in `modules/in_progress/`
2. **pending_review**: Complete but awaiting review by JC in `modules/pending_review/`
3. **complete**: Approved and ready for deployment in `modules/complete/`

### Support Categories (12 Primary)
Activities map to one or more of these evidence-based categories:
- abstinence_goal
- craving
- future_efficacy
- past_use
- physical_health
- pleasant_event
- relationships
- risky_situation
- routine
- stressful_event
- support_seeking
- valence_arousal

**Why multiple mappings?** A single activity (e.g., "managing stress") may be relevant to multiple support categories. The CSV metadata tracks all applicable mappings.

### Core Data Files

#### `modules/recovery_activities.csv`
**Purpose:** Master inventory of all activities
**Key columns:**
- `activity`: Activity file name (maps to qmd file)
- `purpose`: Brief description of therapeutic goal
- Support category columns (12 cols): Marked with 'x' if activity addresses that category
- `format`: Type of activity (worksheet, psychoed reading, calendar, etc.)
- `source`: Origin (matrix, therapist-developed, etc.)
- `activity_status`: Workflow status (in_progress, pending_review, complete)
- `notes`: Contextual information (e.g., "Give earlier on", prerequisite activities)

#### `modules/activity_selection.csv`
**Purpose:** Algorithm reference for recommending activities to users
**Key columns:**
- `activity_name`: Filename with extension (e.g., `psychoed_craving.qmd`)
- Support category columns: Contain ranking (e.g., `1` = recommend first within that category)
- `can_repeat`: Whether activity can be shown again (yes/no)
- `notes`: Algorithm hints (e.g., "scheduling_reading given first")

**Selection Logic:**
- Categories are detected from user data (GPS location patterns, EMA responses, etc.)
- For each active category, rank activities by numeric value (lower = show first)
- Psychoed activities rank 1 and should be shown before related activities
- Check if activity was recently recommended (across any category); if so, skip it
- Respect `can_repeat` flag to avoid showing one-time activities twice

#### `modules/features.qmd`
**Purpose:** Human-readable reference mapping GPS/EMA data features to support categories
**Content:** Table showing how raw data (location patterns, mood, cravings, etc.) maps onto therapeutic support categories

### Quarto Activity Format

Activities are `.qmd` files using Quarto markdown with embedded YAML frontmatter. Standard structure:
```yaml
---
title: "Activity Title"
author: "Creator Name"
format: html
---
```

**Activity Types (by format field in CSV):**
- **psychoed reading**: Educational content (theory, rationale for recovery strategies)
- **worksheet**: Interactive exercises for self-reflection and planning
- **calendar**: Progress tracking and scheduling activities
- **chart**: Visual tools for pattern recognition (e.g., relapse analysis)

**Naming Convention:** 
- Psychoed modules: `psychoed_{support_category}.qmd` (e.g., `psychoed_craving.qmd`)
- Other activities: `{descriptive_name}.qmd` (e.g., `recovery_checklist.qmd`)

### Image Management
Images embedded in recovery modules are stored in `modules/images/`. 
- Image filename should map to the activity name it's used in (e.g., `mindfulness.png` for mindfulness activity)
- If the image folder is moved, all qmd file paths referencing images must be updated

## Key Conventions

### Recovery Activities
1. **Psychoed First:** For each support category, psychoeducational content should be recommended before related activities. Rank psychoed as `1` in `activity_selection.csv`.

2. **Avoid Recent Repeats:** The selection algorithm should check if an activity was recently shown (from a different support category). If so, skip it to reduce redundancy, even if `can_repeat: yes`.

3. **Activity Mappings:** An activity can address multiple support categories. Always update both `recovery_activities.csv` (for inventory) AND `activity_selection.csv` (for selection logic) when adding new activities.

4. **Prerequisite Chains:** Document prerequisites in the `notes` column. Example: "scheduling_reading given first" indicates that reading must be shown before the related worksheet.

### CSV Data Management
- **Both files must stay in sync:** If an activity is added, it appears in `recovery_activities.csv` first (with all metadata), then gets a ranking row in `activity_selection.csv` if it should be recommended.
- **Status field consistency:** The `activity_status` field in `recovery_activities.csv` is the source of truth for workflow stage. Use values: `in_progress`, `pending_review`, `complete`.
- **Decimal/numeric ranking:** Rankings in `activity_selection.csv` can be any number (1, 2, 1.5, etc.). Lower numbers = recommend first.

### Clinical Content
- All activities should be grounded in evidence-based treatment frameworks:
  - **MBRP**: Mindfulness-Based Relapse Prevention (craving, awareness)
  - **CBT**: Cognitive-Behavioral Coping Skills (thoughts, behaviors, situations)
  - **MET/CRA**: Motivational Enhancement Therapy (motivation, goals, relationships)
  - **12-Step Facilitation**: Community support, spirituality, peer recovery
- Reference source manuals in `resources/manuals/` when developing content

## Workflow Conventions

### When Adding a New Activity
1. Create `.qmd` file in `modules/in_progress/`
2. Add row to `recovery_activities.csv` with all metadata (mark `activity_status: in_progress`)
3. Add row(s) to `activity_selection.csv` for each support category the activity addresses
4. Move to `modules/pending_review/` when ready for review
5. Update `activity_status` to `pending_review` in CSV
6. Once approved, move to `modules/complete/` and update to `activity_status: complete`

### When Modifying Recovery Activities
- Test that activity still maps correctly to its support categories
- If changing category mappings, update both CSVs
- If changing activity format or purpose, note the reason in git commit
- If moving image references, verify paths still resolve (images/ folder should not move)

## Repository Structure

```
aud_support/
├── modules/
│   ├── complete/              # Approved, deployed activities (mostly empty during development)
│   ├── in_progress/           # Activities being created/edited
│   ├── pending_review/        # Activities awaiting JC review
│   ├── images/                # Images embedded in activities
│   ├── features.qmd           # Feature-to-category mapping reference
│   ├── recovery_activities.csv  # Master activity inventory (status, metadata)
│   ├── activity_selection.csv   # Selection algorithm reference (rankings)
│   └── readme/                # Documentation (workflow, file descriptions)
├── resources/
│   ├── manuals/               # Evidence-based clinical reference materials
│   │   ├── match_manuals/     # Project MATCH treatment manuals
│   │   ├── nida/              # NIDA treatment frameworks
│   │   ├── mbrp/              # Mindfulness-Based Relapse Prevention
│   │   ├── meds/              # Medication reference materials
│   │   └── matrix/            # Matrix model resources
│   ├── AA_worksheets/         # 12-Step support materials
│   ├── papers/                # Research papers and clinical literature
│   ├── activity_screenshots/  # Screenshot references for activities
│   └── treatment_resources.md # Curated list of external resources
├── .github/
│   └── copilot-instructions.md  # This file
└── .gitignore
```

## Quarto & Local Development

The project uses **Quarto** to develop and render interactive therapeutic content. While there are no build scripts or tests in the current repo, activities are designed to render as HTML via Quarto's rendering engine.

**If contributing activities:**
- Activities are written in `.qmd` format (Quarto markdown)
- Install Quarto from [quarto.org](https://quarto.org) to preview locally
- Render preview: `quarto preview modules/in_progress/activity_name.qmd`
- Check links, embedded images, and formatting before moving to pending_review

## Common Tasks

### Finding Activities by Support Category
1. Open `modules/features.qmd` to understand how data maps to categories
2. Check `modules/recovery_activities.csv` for all activities addressing a category (look for 'x' in category column)
3. Check `modules/activity_selection.csv` to see recommended order for that category

### Understanding Activity Selection Logic
- User generates feature data (GPS patterns, EMA mood responses, etc.)
- Features map to support categories (see features.qmd)
- For each active category, rank activities by their value in `activity_selection.csv`
- Show psychoed first (rank 1), then related activities (rank 2+)
- Skip activities recently recommended (avoid redundancy)

### Adding a New Support Feature
1. Document in `modules/features.qmd` how the new feature maps to support categories
2. Update activity CSVs to reflect how this feature might trigger activity recommendations
3. Ensure any new activities addressing this feature are added to both CSVs

### Moving Activities Between Workflow Stages
- Update `activity_status` in `recovery_activities.csv`
- Move .qmd file to appropriate directory (in_progress → pending_review → complete)
- Commit with message: e.g., "Move activity X to pending_review for JC review"

## External Resources

Clinical manuals and treatment frameworks are stored in `resources/manuals/`:
- **MATCH CBT Manual**: Cognitive-Behavioral Coping Skills techniques
- **NIDA Manuals**: Evidence-based treatment approaches
- **MBRP Guide**: Mindfulness practices for relapse prevention
- **Medication Guides**: AUD and SUD pharmacological interventions

See `resources/treatment_resources.md` for a curated list of external resources.

## Git Workflow

- Main branch: `main`
- Commit messages should reference activity names or support categories when applicable
- Example: "Add relapse_analysis worksheet for past_use category"
- All activities are committed; the workflow stages (in_progress, pending_review, complete) are tracked via CSV and directory structure, not git branches

## Notes for AI Assistants

When working with this repository:
1. **Always update both CSVs together** if activity mappings change
2. **Respect activity status** — only activities in `complete/` are production-ready
3. **Check category mappings** against `features.qmd` and the 12-category standard
4. **Review selection logic** in `activity_selection.csv` to ensure ranking makes clinical sense (psychoed before application, lower numbers first)
5. **Preserve image references** — if moving images or restructuring, verify paths in qmd files
6. **Validate format field** in CSVs matches actual activity type (worksheet, reading, etc.)

When reviewing existing activities, prioritize:
- Alignment with evidence-based treatment frameworks (MBRP, CBT, MET, 12-Step)
- Appropriate category mappings in both CSVs
- Clinical accuracy and user safety
- Clear prerequisites and sequencing
