"""Transactional mail service for sending OTP and registration emails using SMTP."""

from __future__ import annotations

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import structlog

from app.config import get_settings

logger = structlog.get_logger(__name__)


class MailService:
    """Service to handle outbound transactional emails using standard SMTP."""

    def __init__(self) -> None:
        self.settings = get_settings()

    async def send_email(
        self, to_email: str, subject: str, html_content: str, text_content: str = ""
    ) -> bool:
        """Send an email using SMTP server defined in app settings."""
        # If SMTP is not configured, log email contents for development and testing
        if not self.settings.SMTP_HOST:
            logger.info(
                "email_mock_sent",
                to=to_email,
                subject=subject,
                text_content=text_content,
                info="SMTP settings not configured. Logging instead.",
            )
            return True

        try:
            msg = MIMEMultipart("alternative")
            msg["Subject"] = subject
            msg["From"] = self.settings.SMTP_FROM
            msg["To"] = to_email

            if text_content:
                msg.attach(MIMEText(text_content, "plain"))
            msg.attach(MIMEText(html_content, "html"))

            # Run in a synchronous wrapper block since smtplib is blocking
            # We use standard SMTP/SMTPS protocol based on settings
            server = smtplib.SMTP(self.settings.SMTP_HOST, self.settings.SMTP_PORT)
            if self.settings.SMTP_USE_TLS:
                server.starttls()
            if self.settings.SMTP_USERNAME and self.settings.SMTP_PASSWORD:
                server.login(self.settings.SMTP_USERNAME, self.settings.SMTP_PASSWORD)

            server.sendmail(self.settings.SMTP_FROM, to_email, msg.as_string())
            server.quit()
            logger.info("email_sent_successfully", to=to_email, subject=subject)
            return True
        except Exception as e:
            logger.exception("email_send_failed", to=to_email, error=str(e))
            return False


mail_service = MailService()
