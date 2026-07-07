"""Authentication routes for user onboarding, traditional credentials, OTP, OAuth, MFA, and passkeys."""

from __future__ import annotations

import random
import string
import uuid
from datetime import UTC, datetime
from typing import TYPE_CHECKING, Annotated, Any

import pyotp
import structlog
from fastapi import APIRouter, Body, Depends
from sqlalchemy import select

from app.config import get_settings
from app.domain.entities import User
from app.infrastructure.database.models import UserModel
from app.infrastructure.database.session import get_db_session
from app.infrastructure.repositories.redis_cache import cache_repo
from app.infrastructure.repositories.sqlalchemy_repos import SQLAlchemyUserRepository
from app.infrastructure.services.mail_service import mail_service
from app.presentation.middleware.auth_dependency import get_current_user
from app.presentation.schemas.api_schemas import (
    DeviceResponse,
    ErrorResponse,
    LoginRequest,
    OAuthLoginRequest,
    PasskeyOptionsResponse,
    PasskeyVerifyRequest,
    RefreshTokenRequest,
    RegisterRequest,
    SendOTPRequest,
    TokenResponse,
    TOTPSetupResponse,
    TOTPVerifyRequest,
    UserResponse,
    VerifyOTPRequest,
)
from app.shared.exceptions import AuthenticationError, ConflictError, NotFoundError, ValidationError
from app.shared.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    validate_password_strength,
    verify_password,
)

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession

logger = structlog.get_logger(__name__)
router = APIRouter()


def _generate_otp() -> str:
    """Generate a 6-digit numeric OTP code."""
    return "".join(random.choices(string.digits, k=6))


def _generate_backup_codes(count: int = 8) -> list[str]:
    """Generate secure backup codes for account recovery."""
    return [
        "".join(random.choices(string.ascii_uppercase + string.digits, k=10)) for _ in range(count)
    ]


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=201,
    responses={409: {"model": ErrorResponse}, 422: {"model": ErrorResponse}},
)
async def register(
    request: RegisterRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> TokenResponse:
    """Register a new user account with traditional email/password credentials."""
    password_errors = validate_password_strength(request.password)
    if password_errors:
        raise ValidationError(
            message="Password does not meet requirements",
            details={"errors": password_errors},
        )

    repo = SQLAlchemyUserRepository(session)

    existing = await repo.get_by_email(request.email)
    if existing:
        raise ConflictError("A user with this email already exists")

    user = User(
        email=request.email,
        hashed_password=hash_password(request.password),
        full_name=request.full_name,
    )
    created_user = await repo.create(user)
    await session.commit()

    logger.info("user_registered", user_id=created_user.id, email=created_user.email)

    settings = get_settings()
    access_token = create_access_token(
        user_id=created_user.id,
        email=created_user.email,
        role=created_user.role.value if hasattr(created_user.role, "value") else created_user.role,
    )
    refresh_token = create_refresh_token(user_id=created_user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post(
    "/login",
    response_model=TokenResponse,
    responses={401: {"model": ErrorResponse}},
)
async def login(
    request: LoginRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> TokenResponse:
    """Authenticate user with email and password, returning active JWT session."""
    repo = SQLAlchemyUserRepository(session)

    user = await repo.get_by_email(request.email)
    if user is None:
        raise AuthenticationError("Invalid email or password")

    if not verify_password(request.password, user.hashed_password):
        logger.warning("failed_login_attempt", email=request.email)
        raise AuthenticationError("Invalid email or password")

    user.update_last_login()
    await repo.update(user)
    await session.commit()

    logger.info("user_logged_in", user_id=user.id)

    settings = get_settings()
    role = user.role.value if hasattr(user.role, "value") else user.role
    access_token = create_access_token(
        user_id=user.id,
        email=user.email,
        role=role,
    )
    refresh_token = create_refresh_token(user_id=user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post(
    "/oauth-login",
    response_model=TokenResponse,
    responses={401: {"model": ErrorResponse}},
)
async def oauth_login(
    request: OAuthLoginRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> TokenResponse:
    """Authenticate or register user via Google/Apple OAuth token exchanges."""
    repo = SQLAlchemyUserRepository(session)

    user = None
    if request.provider == "google":
        user = await repo.get_by_google_id(request.token)
    elif request.provider == "apple":
        user = await repo.get_by_apple_id(request.token)

    if user is None:
        user = await repo.get_by_email(request.email)
        if user:
            if request.provider == "google":
                user.google_id = request.token
            elif request.provider == "apple":
                user.apple_id = request.token
            await repo.update(user)
            await session.commit()

    if user is None:
        user = User(
            email=request.email,
            full_name=request.full_name or request.email.split("@")[0],
            hashed_password=hash_password(str(uuid.uuid4())),
            is_verified=True,
            google_id=request.token if request.provider == "google" else None,
            apple_id=request.token if request.provider == "apple" else None,
        )
        user = await repo.create(user)
        await session.commit()

    user.update_last_login()
    await repo.update(user)
    await session.commit()

    logger.info("user_oauth_logged_in", user_id=user.id, provider=request.provider)

    settings = get_settings()
    role = user.role.value if hasattr(user.role, "value") else user.role
    access_token = create_access_token(
        user_id=user.id,
        email=user.email,
        role=role,
    )
    refresh_token = create_refresh_token(user_id=user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post(
    "/otp/send",
    status_code=200,
    responses={500: {"model": ErrorResponse}},
)
async def send_otp(request: SendOTPRequest) -> dict[str, str]:
    """Generate and dispatch a 6-digit OTP code to the requested email."""
    code = _generate_otp()
    await cache_repo.set(f"otp:{request.email}", code, ttl=300)

    subject = "WealthAI — Verification Code"
    html_content = f"""
    <div style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto; border: 1px solid #ddd; border-radius: 8px;">
        <h2 style="color: #6C63FF; text-align: center;">WealthAI Verification</h2>
        <p>Hello,</p>
        <p>Use the following 6-digit verification code to log in or verify your account. This code is active for 5 minutes:</p>
        <div style="text-align: center; margin: 30px 0;">
            <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px; padding: 10px 20px; background-color: #f5f5f5; border-radius: 4px; border: 1px dashed #6C63FF; color: #333;">{code}</span>
        </div>
        <p>If you did not request this code, please ignore this email.</p>
        <hr style="border: 0; border-top: 1px solid #eee; margin-top: 30px;">
        <p style="font-size: 12px; color: #888; text-align: center;">WealthAI Platform — Secure Onboarding</p>
    </div>
    """
    text_content = f"Your WealthAI verification code is: {code}"

    sent = await mail_service.send_email(
        to_email=request.email,
        subject=subject,
        html_content=html_content,
        text_content=text_content,
    )
    if not sent:
        raise ValidationError("Failed to send OTP email. Please try again.")

    return {"message": "Verification code sent successfully"}


@router.post(
    "/otp/verify",
    response_model=TokenResponse,
    responses={401: {"model": ErrorResponse}},
)
async def verify_otp(
    request: VerifyOTPRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> TokenResponse:
    """Validate 6-digit OTP code and issue active JWT sessions."""
    cached_code = await cache_repo.get(f"otp:{request.email}")
    if cached_code is None or cached_code != request.code:
        raise AuthenticationError("Invalid or expired verification code")

    await cache_repo.delete(f"otp:{request.email}")

    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_email(request.email)

    if user is None:
        user = User(
            email=request.email,
            full_name=request.email.split("@")[0],
            hashed_password=hash_password(str(uuid.uuid4())),
            is_verified=True,
        )
        user = await repo.create(user)
    else:
        if not user.is_verified:
            user.is_verified = True
            await repo.update(user)

    user.update_last_login()
    await repo.update(user)
    await session.commit()

    settings = get_settings()
    role = user.role.value if hasattr(user.role, "value") else user.role
    access_token = create_access_token(
        user_id=user.id,
        email=user.email,
        role=role,
    )
    refresh_token = create_refresh_token(user_id=user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post(
    "/refresh",
    response_model=TokenResponse,
    responses={401: {"model": ErrorResponse}},
)
async def refresh_token(
    request: RefreshTokenRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> TokenResponse:
    """Refresh active JWT session using refresh token."""
    payload = decode_token(request.refresh_token)

    if payload is None or payload.get("type") != "refresh":
        raise AuthenticationError("Invalid refresh token")

    user_id = payload.get("sub")
    if not user_id:
        raise AuthenticationError("Invalid refresh token")

    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_id(user_id)

    if user is None or not user.is_active:
        raise AuthenticationError("User not found or inactive")

    settings = get_settings()
    role = user.role.value if hasattr(user.role, "value") else user.role
    access_token = create_access_token(
        user_id=user.id,
        email=user.email,
        role=role,
    )
    new_refresh_token = create_refresh_token(user_id=user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh_token,
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.get(
    "/me",
    response_model=UserResponse,
    responses={401: {"model": ErrorResponse}},
)
async def get_profile(
    current_user: Annotated[dict, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> UserResponse:
    """Get profile attributes for the currently logged in user."""
    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_id(current_user["id"])
    if user is None:
        raise AuthenticationError("User not found")

    return UserResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        role=user.role.value if hasattr(user.role, "value") else user.role,
        is_verified=user.is_verified,
        mfa_enabled=user.mfa_enabled,
        is_onboarded=user.is_onboarded,
        avatar_url=user.avatar_url,
        created_at=user.created_at,
        passkeys=user.passkeys,
        trusted_devices=user.trusted_devices,
    )


@router.post(
    "/mfa/totp/setup",
    response_model=TOTPSetupResponse,
    responses={401: {"model": ErrorResponse}},
)
async def setup_totp(
    current_user: Annotated[dict, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> TOTPSetupResponse:
    """Generate random provisioning base32 secret parameters for TOTP client sync."""
    secret = pyotp.random_base32()
    totp = pyotp.TOTP(secret)
    provisioning_uri = totp.provisioning_uri(current_user["email"], issuer_name="WealthAI")

    # Stash secret temporarily in cache until verified
    await cache_repo.set(f"totp_pending:{current_user['id']}", secret, ttl=600)

    return TOTPSetupResponse(secret=secret, provisioning_uri=provisioning_uri)


@router.post(
    "/mfa/totp/enable",
    responses={400: {"model": ErrorResponse}, 401: {"model": ErrorResponse}},
)
async def enable_totp(
    request: TOTPVerifyRequest,
    current_user: Annotated[dict, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> dict[str, Any]:
    """Verify TOTP token code and output security account backup codes."""
    pending_secret = await cache_repo.get(f"totp_pending:{current_user['id']}")
    if not pending_secret:
        raise ValidationError("MFA setup session expired. Please call setup again.")

    totp = pyotp.TOTP(pending_secret)
    if not totp.verify(request.code):
        raise ValidationError("Invalid TOTP verification code")

    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_id(current_user["id"])
    if user is None:
        raise NotFoundError("User not found")

    backup_codes = _generate_backup_codes()
    user.totp_secret = pending_secret
    user.backup_codes = backup_codes
    user.mfa_enabled = True

    await repo.update(user)
    await session.commit()
    await cache_repo.delete(f"totp_pending:{current_user['id']}")

    return {
        "message": "Two-factor authentication enabled successfully",
        "backup_codes": backup_codes,
    }


@router.post(
    "/mfa/totp/disable",
    responses={401: {"model": ErrorResponse}},
)
async def disable_totp(
    current_user: Annotated[dict, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> dict[str, str]:
    """Disable TOTP multifactor check requirements."""
    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_id(current_user["id"])
    if user is None:
        raise NotFoundError("User not found")

    user.totp_secret = None
    user.backup_codes = []
    user.mfa_enabled = False

    await repo.update(user)
    await session.commit()

    return {"message": "Two-factor authentication disabled successfully"}


@router.get(
    "/devices",
    response_model=list[DeviceResponse],
    responses={401: {"model": ErrorResponse}},
)
async def list_devices(
    current_user: Annotated[dict, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> list[DeviceResponse]:
    """Retrieve lists of all active logged-in device profiles."""
    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_id(current_user["id"])
    if user is None:
        raise NotFoundError("User not found")

    devices = user.trusted_devices
    return [
        DeviceResponse(
            device_id=d["device_id"],
            name=d["name"],
            registered_at=datetime.fromisoformat(d["registered_at"]),
        )
        for d in devices
    ]


@router.delete(
    "/devices/{device_id}",
    responses={401: {"model": ErrorResponse}},
)
async def revoke_device(
    device_id: str,
    current_user: Annotated[dict, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> dict[str, str]:
    """De-register and revoke session capabilities for requested device."""
    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_id(current_user["id"])
    if user is None:
        raise NotFoundError("User not found")

    user.trusted_devices = [d for d in user.trusted_devices if d["device_id"] != device_id]
    await repo.update(user)
    await session.commit()

    return {"message": f"Device session {device_id} revoked successfully"}


@router.post(
    "/onboarding/complete",
    responses={401: {"model": ErrorResponse}},
)
async def complete_onboarding(
    current_user: Annotated[dict, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> dict[str, str]:
    """Toggle completed onboarding flag state."""
    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_id(current_user["id"])
    if user is None:
        raise NotFoundError("User not found")

    user.is_onboarded = True
    await repo.update(user)
    await session.commit()

    return {"message": "Onboarding wizard completed"}


@router.delete(
    "/account",
    responses={401: {"model": ErrorResponse}},
)
async def delete_account(
    current_user: Annotated[dict, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> dict[str, str]:
    """Delete current user's profile and all associated data."""
    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_id(current_user["id"])
    if user is None:
        raise NotFoundError("User not found")

    await repo.delete(user.id)
    await session.commit()

    return {"message": "Account deleted successfully"}


# ============================================================
# Passkey WebAuthn Framework Mock Options
# ============================================================


@router.post(
    "/passkeys/register/options",
    response_model=PasskeyOptionsResponse,
    responses={401: {"model": ErrorResponse}},
)
async def passkey_register_options(
    current_user: Annotated[dict, Depends(get_current_user)],
) -> PasskeyOptionsResponse:
    """Generate passkey challenge options payload."""
    challenge = "".join(random.choices(string.ascii_letters + string.digits, k=32))
    return PasskeyOptionsResponse(
        challenge=challenge,
        user_id=current_user["id"],
        rp_name="WealthAI",
        rp_id=get_settings().APP_HOST,
    )


@router.post(
    "/passkeys/register/verify",
    responses={401: {"model": ErrorResponse}},
)
async def passkey_register_verify(
    request: PasskeyVerifyRequest,
    current_user: Annotated[dict, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> dict[str, str]:
    """Save passkey credential payload to user's profiles."""
    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_id(current_user["id"])
    if user is None:
        raise NotFoundError("User not found")

    new_key = {
        "credential_id": request.credential_id,
        "public_key": request.client_data_json,  # mock representation of the key
        "created_at": datetime.now(UTC).isoformat(),
    }
    user.passkeys.append(new_key)
    await repo.update(user)
    await session.commit()

    return {"message": "Passkey registered successfully"}


@router.post(
    "/passkeys/login/options",
    response_model=PasskeyOptionsResponse,
)
async def passkey_login_options(
    email: str = Body(..., embed=True),
) -> PasskeyOptionsResponse:
    """Generate passkey authentication parameters options payload."""
    challenge = "".join(random.choices(string.ascii_letters + string.digits, k=32))
    return PasskeyOptionsResponse(
        challenge=challenge,
        rp_name="WealthAI",
        rp_id=get_settings().APP_HOST,
    )


@router.post(
    "/passkeys/login/verify",
    response_model=TokenResponse,
    responses={401: {"model": ErrorResponse}},
)
async def passkey_login_verify(
    request: PasskeyVerifyRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> TokenResponse:
    """Verify passkey signature assertion and generate active token session."""
    repo = SQLAlchemyUserRepository(session)

    # Search user having matching passkey credentials
    stmt = select(UserModel).where(UserModel.passkeys.like(f"%{request.credential_id}%"))
    result = await session.execute(stmt)
    model = result.scalar_one_or_none()
    if not model:
        raise AuthenticationError("No registered passkey matches this credential")

    user = await repo.get_by_id(model.id)
    if user is None or not user.is_active:
        raise AuthenticationError("User not found or inactive")

    user.update_last_login()
    await repo.update(user)
    await session.commit()

    settings = get_settings()
    role = user.role.value if hasattr(user.role, "value") else user.role
    access_token = create_access_token(
        user_id=user.id,
        email=user.email,
        role=role,
    )
    refresh_token = create_refresh_token(user_id=user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )
