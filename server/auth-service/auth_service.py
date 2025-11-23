#!/usr/bin/env python3
"""
Servicio de autenticación para Envoy ext_authz
Valida JWT tokens de Keycloak y extrae tenant_id
"""
import os
import logging
from flask import Flask, request, jsonify
from jose import jwt, JWTError
import requests

# Configuración
KEYCLOAK_URL = os.getenv('KEYCLOAK_URL', 'http://keycloak:8080')
KEYCLOAK_REALM = os.getenv('KEYCLOAK_REALM', 'observability')
DEFAULT_TENANT = os.getenv('DEFAULT_TENANT', 'tenant-pe')

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Cache para public keys de Keycloak
_jwks_cache = None

def get_keycloak_public_key():
    """Obtiene la public key de Keycloak para validar JWT"""
    global _jwks_cache

    if _jwks_cache:
        return _jwks_cache

    try:
        certs_url = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/certs"
        response = requests.get(certs_url, timeout=5)
        response.raise_for_status()
        _jwks_cache = response.json()
        logger.info(f"Loaded Keycloak public keys from {certs_url}")
        return _jwks_cache
    except Exception as e:
        logger.error(f"Failed to get Keycloak public key: {e}")
        return None

def validate_token(token):
    """Valida JWT token y extrae claims"""
    try:
        jwks = get_keycloak_public_key()
        if not jwks:
            return None, "Failed to get Keycloak public key"

        # Decodificar sin verificar para obtener el kid
        unverified_header = jwt.get_unverified_header(token)

        # Buscar la key correcta
        rsa_key = None
        for key in jwks.get('keys', []):
            if key['kid'] == unverified_header['kid']:
                rsa_key = {
                    'kty': key['kty'],
                    'kid': key['kid'],
                    'use': key['use'],
                    'n': key['n'],
                    'e': key['e']
                }
                break

        if not rsa_key:
            return None, "Unable to find appropriate key"

        # Verificar y decodificar el token
        payload = jwt.decode(
            token,
            rsa_key,
            algorithms=['RS256'],
            audience='account',
            options={"verify_aud": False}  # Temporal, ajustar según audience real
        )

        logger.info(f"Token validated successfully for subject: {payload.get('sub')}")
        return payload, None

    except JWTError as e:
        logger.warning(f"JWT validation failed: {e}")
        return None, str(e)
    except Exception as e:
        logger.error(f"Unexpected error validating token: {e}")
        return None, str(e)

@app.route('/authz', methods=['POST'])
def authz():
    """
    Endpoint para Envoy ext_authz
    Valida JWT y extrae tenant_id, o usa header X-Tenant-ID como fallback
    """
    try:
        # Prioridad 1: Obtener tenant desde header X-Tenant-ID (simple, sin auth)
        tenant_from_header = request.headers.get('X-Tenant-ID', '').strip()

        if tenant_from_header:
            logger.info(f"Using tenant from X-Tenant-ID header: {tenant_from_header}")
            return jsonify({
                'result': {
                    'allowed': True,
                    'headers': {
                        'x-scope-orgid': tenant_from_header
                    }
                }
            }), 200

        # Prioridad 2: Obtener el token del header Authorization (JWT auth)
        auth_header = request.headers.get('Authorization', '')

        if not auth_header.startswith('Bearer '):
            logger.warning("No Bearer token or X-Tenant-ID found, using default tenant")
            # Sin autenticación, usar tenant por defecto
            return jsonify({
                'result': {
                    'allowed': True,
                    'headers': {
                        'x-scope-orgid': DEFAULT_TENANT
                    }
                }
            }), 200

        token = auth_header.replace('Bearer ', '')

        # Validar token
        payload, error = validate_token(token)

        if error:
            logger.warning(f"Token validation failed: {error}, using default tenant")
            # Token inválido, usar tenant por defecto (no rechazar request)
            return jsonify({
                'result': {
                    'allowed': True,
                    'headers': {
                        'x-scope-orgid': DEFAULT_TENANT
                    }
                }
            }), 200

        # Extraer tenant_id de los claims
        tenant_id = payload.get('tenant_id')

        if not tenant_id:
            # Intentar obtener de resource_access o roles
            resource_access = payload.get('resource_access', {})
            for client, data in resource_access.items():
                if 'tenant_id' in data:
                    tenant_id = data['tenant_id']
                    break

        if not tenant_id:
            tenant_id = DEFAULT_TENANT
            logger.info(f"No tenant_id in token, using default: {tenant_id}")

        logger.info(f"Request authorized with tenant_id: {tenant_id}")

        # Agregar headers adicionales para auditoría
        headers = {
            'x-scope-orgid': tenant_id,
            'x-user-id': payload.get('preferred_username', 'unknown'),
            'x-user-email': payload.get('email', 'unknown')
        }

        return jsonify({
            'result': {
                'allowed': True,
                'headers': headers
            }
        }), 200

    except Exception as e:
        logger.error(f"Unexpected error in authz: {e}")
        # En caso de error, permitir con tenant por defecto
        return jsonify({
            'result': {
                'allowed': True,
                'headers': {
                    'x-scope-orgid': DEFAULT_TENANT
                }
            }
        }), 200

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'}), 200

if __name__ == '__main__':
    logger.info(f"Starting auth service...")
    logger.info(f"Keycloak URL: {KEYCLOAK_URL}")
    logger.info(f"Realm: {KEYCLOAK_REALM}")
    logger.info(f"Default tenant: {DEFAULT_TENANT}")
    app.run(host='0.0.0.0', port=8000)
