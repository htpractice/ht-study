"""
Count INFO, WARNING, and ERROR occurrences in a log file.

Each line is split into tokens (whitespace-separated words). If a token
exactly matches a known log level, that level's counter is incremented.
"""

from pathlib import Path

LEVELS = ("INFO", "WARNING", "ERROR")  # immutable — safe to reuse everywhere


def read_log_file(path: str | Path) -> str:
    """Read the full log file as UTF-8 text."""
    return Path(path).read_text(encoding="utf-8")


def count_log_levels(text: str) -> dict[str, int]:
    """
    Scan every line and count how many times each log level appears.

    Example line: 2026-08-13 app-server INFO request completed 200
    After split:  ["2026-08-13", "app-server", "INFO", "request", ...]
    """
    counter = {
        "INFO": 0,
        "WARNING": 0,
        "ERROR": 0,
    }

    for line in text.splitlines():
        tokens = line.split()  # split line into words
        for level in LEVELS:
            if level in tokens:
                counter[level] += 1

    return counter


def main() -> None:
    # Default: sample log next to this script (override with your own path)
    log_path = Path(__file__).resolve().parent / "app.log"

    text = read_log_file(log_path)
    counts = count_log_levels(text)
    print(counts)


if __name__ == "__main__":
    main()
