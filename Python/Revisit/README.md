# Log level counter

Small Python exercise: read a log file and count how many times each severity level appears.

## What it does

1. **`read_log_file(path)`** — loads the log file using `pathlib.Path` (UTF-8).
2. **`count_log_levels(text)`** — walks every line, splits on whitespace, and increments counters when a token matches `INFO`, `WARNING`, or `ERROR`.
3. **`main()`** — runs against `app.log` in this folder and prints the result dict.

## Example

```bash
cd ht-study/Python/Revisit
python3 log_level_counter.py
```

Expected output for the bundled sample log:

```python
{'INFO': 6, 'WARNING': 3, 'ERROR': 3}
```

## How the counting works

Each log line is treated as a list of **tokens** (words separated by spaces):

```
2026-08-13T10:00:01 api-gateway INFO request started GET /health
│                      │            │    │
timestamp              service      level  message tokens...
```

For every line:

```python
tokens = line.split()
for level in LEVELS:
    if level in tokens:
        counter[level] += 1
```

- `LEVELS` is a **tuple** — fixed set of allowed levels; tuples are immutable (good for constants).
- `counter` is a **dict** — keys are level names, values are running counts.
- Using `level in tokens` means the level must appear as its own word (not inside another word).

## Concepts used

| Concept | Where | Why |
|---------|--------|-----|
| `pathlib.Path` | `read_log_file` | Modern file paths; `.read_text()` is simpler than manual `open`/`close` |
| Tuple `LEVELS` | top of file | Immutable list of valid levels — won't change by accident |
| Dict `counter` | `count_log_levels` | Named counts; easy to print or return |
| `splitlines()` | loop over log | Handles `\n` line breaks across platforms |
| `split()` | per line | Breaks `"a INFO b"` into `["a", "INFO", "b"]` |
| `if __name__ == "__main__"` | bottom | Script runs `main()` only when executed directly, not when imported |

## Use your own log file

Point at any file by editing `log_path` in `main()`, or pass a path from the command line (future improvement):

```python
log_path = "/path/to/your/app.log"
```

## Files

| File | Purpose |
|------|---------|
| `log_level_counter.py` | Script |
| `app.log` | Sample log for practice |
| `README.md` | This explanation |
