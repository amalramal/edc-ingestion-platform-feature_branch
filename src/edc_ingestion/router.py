"""CLI entrypoint for ECS task overrides (Step Functions → ``python -m edc_ingestion.router``)."""

from __future__ import annotations

import argparse
import json
import sys

from edc_ingestion.logging_config import configure_logging


def main() -> None:
    configure_logging()
    parser = argparse.ArgumentParser(prog="edc-task")
    parser.add_argument("--task", required=True, choices=["ingestion", "validation", "publisher"])
    parser.add_argument("--studyId", required=True, dest="study_id")
    args = parser.parse_args()

    match args.task:
        case "ingestion":
            from edc_ingestion.tasks.ingestion.main import run as run_ingestion

            out = run_ingestion(args.study_id)
            json.dump(out, sys.stdout, default=str)
            sys.stdout.write("\n")
        case _:
            sys.stderr.write(f"{args.task} task is not implemented yet.\n")
            raise SystemExit(2)


if __name__ == "__main__":
    main()
