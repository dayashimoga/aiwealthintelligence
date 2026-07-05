"""Tests for the production-grade Setu Account Aggregator cryptographic helper services."""

from __future__ import annotations

import base64
import pytest
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives import serialization
from app.infrastructure.services.setu_aa_service import AASecurityService


@pytest.mark.unit
class TestAASecurityService:
    """Verifies that ECDH Diffie-Hellman key derivation and AES-GCM decryption work properly."""

    def test_key_generation_and_serialization(self) -> None:
        """Generating key pair returns private key object and valid uncompressed points bytes."""
        private_key, public_bytes = AASecurityService.generate_key_pair()
        
        assert isinstance(private_key, ec.EllipticCurvePrivateKey)
        assert isinstance(public_bytes, bytes)
        assert len(public_bytes) == 65  # Uncompressed NIST P-256 public keys are exactly 65 bytes (0x04 + 32-byte X + 32-byte Y)
        assert public_bytes[0] == 4  # Uncompressed format indicator

    def test_key_exchange_and_aes_decryption(self) -> None:
        """Simulates full key exchange, derives symmetric key, and decrypts ciphertext successfully."""
        # 1. Setup recipient keys (WealthAI)
        recip_private, recip_public_bytes = AASecurityService.generate_key_pair()
        
        # 2. Setup sender keys (Mock FIP / Setu)
        sender_private, sender_public_bytes = AASecurityService.generate_key_pair()
        
        # 3. Simulate key exchange on sender side
        recip_public_key = ec.EllipticCurvePublicKey.from_encoded_point(
            ec.SECP256R1(),
            recip_public_bytes,
        )
        sender_shared_secret = sender_private.exchange(ec.ECDH(), recip_public_key)
        
        salt = b"test-salt-bytes-16"
        info = b"test-consent-handle-12345"
        
        from cryptography.hazmat.primitives.kdf.hkdf import HKDF
        from cryptography.hazmat.primitives import hashes
        hkdf = HKDF(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            info=info,
        )
        sender_aes_key = hkdf.derive(sender_shared_secret)
        
        # 4. Encrypt mock data on sender side
        plain_text = "<equity><isin>INE002A01018</isin><units>10.0</units><rate>2400.0</rate></equity>"
        import os
        nonce = os.urandom(12)
        aesgcm = AESGCM(sender_aes_key)
        ciphertext = aesgcm.encrypt(nonce, plain_text.encode("utf-8"), None)
        
        # Encode inputs to base64
        encrypted_data_base64 = base64.b64encode(ciphertext).decode("utf-8")
        nonce_base64 = base64.b64encode(nonce).decode("utf-8")
        
        # 5. Derivation and Decryption on recipient side (using AASecurityService)
        recipient_aes_key = AASecurityService.derive_aes_key(
            recip_private,
            sender_public_bytes,
            salt,
            info,
        )
        
        # Derivations must match exactly
        assert recipient_aes_key == sender_aes_key
        
        decrypted_result = AASecurityService.decrypt(
            recipient_aes_key,
            encrypted_data_base64,
            nonce_base64,
        )
        
        assert decrypted_result == plain_text
