# A1 Submit
> **A brief description of the submission information for A1**

## Description
The CI behavior and version update logic depend on the special tags included in your commit message.

### Component-specific tags
Each of the following tags triggers CI once and updates **only the version number of the corresponding component**:
- `[version-only-a1]` — updates the **a1** version number
- `[version-only-a1ctl]` — updates the **a1ctl** version number
- `[version-only-a1mod]` — updates the **a1mod** version number
- `[version-only-a1pm]` — updates the **a1pm** version number
- `[version-only-gui]` — updates the **gui** version number
- `[version-only-generate]` — updates the **generate** version number

### Other tags
- `[version-only-all]` — runs CI once and updates the version numbers of **all components** simultaneously.
- `[version-only-other]` — runs CI but updates **no** version number.
- **No special tag** — runs CI but updates **no** version number.

### Priority rules
- If the commit contains **both** `[version-only-other]` and any component-specific tag, `[version-only-other]` takes **higher priority** — no version number is updated.
- If the commit contains **both** `[version-only-other]` and `[version-only-all]`... *(clarify if needed)*

## Examples
### `fix: xxx [version-only-a1]`
- Only the **a1** version number is updated.

### `fix: xxx [version-only-all]`
- **All** version numbers are updated.

### `fix: xxx [version-only-other]`
- **No** version number is updated.

