"""
EDC Ingestion Platform — SNS → SES Alert Emailer (Lambda).

Receives SNS notifications from the ``edc-pipeline-alerts`` topic and
forwards them as formatted HTML emails via Amazon SES.

Environment Variables (set by Terraform):
    SENDER_EMAIL      — Verified SES sender address.
    RECIPIENT_EMAILS  — Comma-separated list of recipient addresses.
"""

from __future__ import annotations

import json
import os

import boto3

ses = boto3.client("ses")

SENDER: str = os.environ["SENDER_EMAIL"]
RECIPIENTS: list[str] = [
    e.strip() for e in os.environ["RECIPIENT_EMAILS"].split(",") if e.strip()
]


def handler(event: dict, context: object) -> dict:
    """Lambda entry point — invoked by the SNS subscription."""
    for record in event.get("Records", []):
        sns_message = record.get("Sns", {})
        subject = sns_message.get("Subject", "EDC Pipeline Alert")
        raw_body = sns_message.get("Message", "{}")

        try:
            payload = json.loads(raw_body)
        except (json.JSONDecodeError, TypeError):
            payload = {"raw_message": raw_body}

        html_body = _build_html(subject, payload)
        text_body = _build_text(subject, payload)

        ses.send_email(
            Source=SENDER,
            Destination={"ToAddresses": RECIPIENTS},
            Message={
                "Subject": {"Data": subject, "Charset": "UTF-8"},
                "Body": {
                    "Html": {"Data": html_body, "Charset": "UTF-8"},
                    "Text": {"Data": text_body, "Charset": "UTF-8"},
                },
            },
        )

    return {"status": "ok", "emails_sent": len(event.get("Records", []))}


def _build_html(subject: str, payload: dict) -> str:
    """Render a structured HTML email from the SNS payload."""
    rows = "".join(
        f"<tr><td style='padding:6px 12px;border:1px solid #ddd;font-weight:bold'>{k}</td>"
        f"<td style='padding:6px 12px;border:1px solid #ddd'>{v}</td></tr>"
        for k, v in payload.items()
    )
    return f"""
    <html>
    <body style="font-family:Arial,sans-serif;color:#333">
      <h2 style="color:#c0392b">{subject}</h2>
      <table style="border-collapse:collapse;width:100%;max-width:600px">
        {rows}
      </table>
      <p style="margin-top:20px;font-size:12px;color:#888">
        This is an automated alert from the EDC Ingestion Platform.
      </p>
    </body>
    </html>
    """


def _build_text(subject: str, payload: dict) -> str:
    """Render a plain-text fallback from the SNS payload."""
    lines = [subject, "=" * len(subject), ""]
    for k, v in payload.items():
        lines.append(f"  {k}: {v}")
    lines.append("")
    lines.append("-- EDC Ingestion Platform (automated alert)")
    return "\n".join(lines)
